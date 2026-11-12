import os
import re
import shutil
import subprocess
import tempfile
from pathlib import Path

from fastapi import FastAPI, File, Form, HTTPException, UploadFile
from fastapi.middleware.cors import CORSMiddleware


app = FastAPI(title="PinoyProto 3D OrcaSlicer API")
app.add_middleware(
    CORSMiddleware,
    allow_origins=os.getenv("ALLOWED_ORIGINS", "*").split(","),
    allow_methods=["POST"],
    allow_headers=["*"],
)

ORCA_SLICER_BIN = os.getenv("ORCA_SLICER_BIN", "orca-slicer")
MAX_UPLOAD_BYTES = 100 * 1024 * 1024
ALLOWED_EXTENSIONS = {".stl", ".3mf"}


def parse_slice_output(output_dir: Path) -> dict:
    gcode_files = list(output_dir.rglob("*.gcode"))
    text = "\n".join(
        file.read_text(encoding="utf-8", errors="ignore")
        for file in gcode_files
    )
    time_match = re.search(
        r";\s*(?:total\s+)?(?:estimated\s+)?printing\s+time\s*[:=]\s*(.+)",
        text,
        re.IGNORECASE,
    )
    filament_match = re.search(
        r";\s*(?:total\s+)?filament\s+(?:used|length)\s*[:=]\s*([0-9.]+)\s*(mm|m)?",
        text,
        re.IGNORECASE,
    )
    weight_match = re.search(
        r";\s*filament\s+used\s*\[g\]\s*[:=]\s*([0-9.]+)",
        text,
        re.IGNORECASE,
    )
    return {
        "files": [str(file.relative_to(output_dir)) for file in gcode_files],
        "print_time": time_match.group(1).strip() if time_match else None,
        "filament_length": (
            float(filament_match.group(1))
            if filament_match
            else None
        ),
        "filament_length_unit": filament_match.group(2) if filament_match else None,
        "filament_weight": float(weight_match.group(1)) if weight_match else None,
    }


@app.get("/health")
def health() -> dict:
    return {"ok": True, "slicer": ORCA_SLICER_BIN}


@app.post("/api/slice")
async def slice_model(
    model: UploadFile = File(...),
    layer_height: float = Form(...),
    wall_loops: int = Form(...),
    sparse_infill: int = Form(...),
) -> dict:
    extension = Path(model.filename or "").suffix.lower()
    if extension not in ALLOWED_EXTENSIONS:
        raise HTTPException(status_code=400, detail="Only STL and 3MF files are supported.")
    if not 0.05 <= layer_height <= 1:
        raise HTTPException(status_code=400, detail="Layer height must be between 0.05 and 1 mm.")
    if not 1 <= wall_loops <= 20:
        raise HTTPException(status_code=400, detail="Wall loops must be between 1 and 20.")
    if not 0 <= sparse_infill <= 100:
        raise HTTPException(status_code=400, detail="Sparse infill must be between 0 and 100 percent.")

    with tempfile.TemporaryDirectory(prefix="pinoyproto-slice-") as directory:
        work_dir = Path(directory)
        input_path = work_dir / f"model{extension}"
        output_dir = work_dir / "output"
        output_dir.mkdir()
        size = 0
        with input_path.open("wb") as target:
            while chunk := await model.read(1024 * 1024):
                size += len(chunk)
                if size > MAX_UPLOAD_BYTES:
                    raise HTTPException(status_code=413, detail="Model file is too large.")
                target.write(chunk)

        command = [
            ORCA_SLICER_BIN,
            "--slice",
            "0",
            "--outputdir",
            str(output_dir),
            f"--layer-height={layer_height}",
            f"--wall-loops={wall_loops}",
            f"--sparse-infill-density={sparse_infill}%",
            str(input_path),
        ]
        try:
            completed = subprocess.run(
                command,
                capture_output=True,
                text=True,
                timeout=300,
                check=False,
            )
        except FileNotFoundError as error:
            raise HTTPException(
                status_code=503,
                detail="OrcaSlicer CLI is not installed or ORCA_SLICER_BIN is incorrect.",
            ) from error
        except subprocess.TimeoutExpired as error:
            raise HTTPException(status_code=504, detail="OrcaSlicer timed out.") from error

        if completed.returncode != 0:
            detail = completed.stderr.strip() or completed.stdout.strip() or "OrcaSlicer failed."
            raise HTTPException(status_code=502, detail=detail[-2000:])

        return {
            "ok": True,
            "settings": {
                "layer_height": layer_height,
                "wall_loops": wall_loops,
                "sparse_infill": sparse_infill,
            },
            "slice": parse_slice_output(output_dir),
        }
