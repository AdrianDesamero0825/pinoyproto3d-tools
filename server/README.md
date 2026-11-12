# OrcaSlicer server

This API runs OrcaSlicer headlessly for the Price Estimator.

## Requirements

- Python 3.11+
- OrcaSlicer installed on the server
- The `orca-slicer` executable available on `PATH`, or `ORCA_SLICER_BIN` set to its full path

## Run

```powershell
cd server
py -3 -m venv .venv
.\.venv\Scripts\python.exe -m pip install -r requirements.txt
$env:ORCA_SLICER_BIN = "C:\path\to\orca-slicer.exe"
.\.venv\Scripts\python.exe -m uvicorn main:app --host 0.0.0.0 --port 8787
```

The API exposes `GET /health` and `POST /api/slice`. The page currently calls
`http://localhost:8787/api/slice`; change that URL when deploying the API to a
remote server.

The endpoint accepts STL/3MF files and the three estimator overrides:

- `layer_height`
- `wall_loops`
- `sparse_infill`

It invokes OrcaSlicer with `--slice 0`, `--outputdir`, and the corresponding
CLI setting overrides, then extracts available time and filament metadata from
the generated G-code.
