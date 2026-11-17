import json
import logging
import os
import subprocess
import time
import urllib.error
import urllib.request

from fastapi import BackgroundTasks, Depends, FastAPI, Header, HTTPException
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
        "https://www.pinoyproto3d.stream,https://adriandesamero0825.github.io,http://localhost:5500,http://127.0.0.1:5500",
    ).split(",")
    if origin.strip()
]

app = FastAPI(title="PinoyProto Bambu Studio Control", docs_url=None, redoc_url=None)
logger = logging.getLogger("bambu-control")
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


def run_control_command(action: str) -> str:
    try:
        result = subprocess.run(
            ["sudo", "-n", CONTROL_COMMAND, action],
            check=True,
            capture_output=True,
            text=True,
            timeout=15,
        )
    except (subprocess.CalledProcessError, subprocess.TimeoutExpired, OSError) as error:
        logger.exception("Docker control action %s failed", action)
        raise HTTPException(status_code=502, detail="Could not read or control the Bambu Studio Docker app.") from error
    return result.stdout.strip()


def get_studio_running() -> bool:
    state = run_control_command("status").lower()
    if state not in {"true", "false"}:
        raise HTTPException(status_code=502, detail="Docker returned an unknown Bambu Studio status.")
    return state == "true"


def stop_studio_after_response() -> None:
    # Let the response travel back through cloudflared before stopping the desktop.
    time.sleep(3)
    try:
        run_control_command("stop")
    except HTTPException:
        logger.exception("Docker did not accept the Bambu Studio stop request")


@app.get("/health")
def health() -> dict:
    return {"ok": True}


@app.get("/api/bambu/status")
def status(_user: dict = Depends(require_admin)) -> dict:
    try:
        details = json.loads(run_control_command("watch"))
    except ValueError as error:
        raise HTTPException(status_code=502, detail="Could not read Bambu Studio connection status.") from error
    if not isinstance(details, dict) or not isinstance(details.get("running"), bool):
        raise HTTPException(status_code=502, detail="Docker returned an invalid Bambu Studio status.")
    details["status"] = "running" if details["running"] else "stopped"
    return details


@app.post("/api/bambu/start")
def start(_user: dict = Depends(require_admin)) -> dict:
    run_control_command("start")
    return {"ok": True, "running": True, "status": "started"}


@app.post("/api/bambu/stop")
def stop(background_tasks: BackgroundTasks, _user: dict = Depends(require_admin)) -> dict:
    if not get_studio_running():
        return {"ok": True, "status": "already_stopped"}
    background_tasks.add_task(stop_studio_after_response)
    return {"ok": True, "status": "shutdown_requested"}
