import json
import os
import subprocess
import urllib.error
import urllib.request

from fastapi import Depends, FastAPI, Header, HTTPException
from fastapi.middleware.cors import CORSMiddleware


SUPABASE_URL = os.environ.get("SUPABASE_URL", "").rstrip("/")
SUPABASE_PUBLISHABLE_KEY = os.environ.get("SUPABASE_PUBLISHABLE_KEY", "")
ADMIN_EMAILS = {
    email.strip().lower()
    for email in os.environ.get("BAMBU_ADMIN_EMAILS", "").split(",")
    if email.strip()
}
CONTROL_COMMAND = "/usr/local/sbin/pinoyproto-bambu-control"
ALLOWED_ORIGINS = [
    origin.strip()
    for origin in os.environ.get(
        "CONTROL_ALLOWED_ORIGINS",
        "https://adriandesamero0825.github.io,http://localhost:5500,http://127.0.0.1:5500",
    ).split(",")
    if origin.strip()
]

app = FastAPI(title="PinoyProto Bambu Studio Control", docs_url=None, redoc_url=None)
app.add_middleware(
    CORSMiddleware,
    allow_origins=ALLOWED_ORIGINS,
    allow_credentials=True,
    allow_methods=["GET", "POST"],
    allow_headers=["Authorization"],
)


def require_configuration() -> None:
    if not SUPABASE_URL or not SUPABASE_PUBLISHABLE_KEY or not ADMIN_EMAILS:
        raise HTTPException(status_code=503, detail="Bambu control service is not configured by its administrator.")


def require_admin(authorization: str | None = Header(default=None)) -> dict:
    require_configuration()
    if not authorization or not authorization.startswith("Bearer "):
        raise HTTPException(status_code=401, detail="Sign in with the website admin account.")

    request = urllib.request.Request(
        f"{SUPABASE_URL}/auth/v1/user",
        headers={
            "apikey": SUPABASE_PUBLISHABLE_KEY,
            "Authorization": authorization,
            "Accept": "application/json",
        },
    )
    try:
        with urllib.request.urlopen(request, timeout=8) as response:
            user = json.loads(response.read())
    except (urllib.error.HTTPError, urllib.error.URLError, TimeoutError, ValueError) as error:
        raise HTTPException(status_code=401, detail="Your admin session could not be verified.") from error

    email = str(user.get("email", "")).strip().lower()
    if not email or email not in ADMIN_EMAILS:
        raise HTTPException(status_code=403, detail="This Supabase account is not allowed to control Bambu Studio.")
    return {"email": email}


def run_fixed_action(action: str) -> str:
    try:
        completed = subprocess.run(
            ["sudo", "-n", CONTROL_COMMAND, action],
            capture_output=True,
            text=True,
            timeout=30,
            check=False,
        )
    except (FileNotFoundError, subprocess.TimeoutExpired) as error:
        raise HTTPException(status_code=503, detail="The restricted Bambu control helper is unavailable.") from error
    if completed.returncode != 0:
        raise HTTPException(status_code=502, detail="The Bambu container command failed.")
    return completed.stdout.strip()


@app.get("/health")
def health() -> dict:
    return {"ok": True}


@app.get("/api/bambu/status")
def status(_user: dict = Depends(require_admin)) -> dict:
    running = run_fixed_action("status")
    if running not in {"true", "false"}:
        raise HTTPException(status_code=502, detail="The helper returned an invalid container status.")
    return {"running": running == "true"}


@app.post("/api/bambu/start")
def start(_user: dict = Depends(require_admin)) -> dict:
    run_fixed_action("start")
    return {"ok": True, "running": True}


@app.post("/api/bambu/stop")
def stop(_user: dict = Depends(require_admin)) -> dict:
    run_fixed_action("stop")
    return {"ok": True, "running": False}
