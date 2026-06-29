import asyncio
import os
import re
import subprocess
from pathlib import Path

from fastapi import FastAPI, HTTPException, Query
from fastapi.responses import HTMLResponse, RedirectResponse
from fastapi.templating import Jinja2Templates
from starlette.requests import Request

app = FastAPI(docs_url=None, redoc_url=None)
templates = Jinja2Templates(directory=str(Path(__file__).parent / "templates"))

TOKEN = os.environ["GAME_CONTROL_TOKEN"]
STATE_DIR = Path("/var/lib/game-control")
ASTRONEER_INI = Path("/var/lib/game-servers/astroneer/Astro/Saved/Config/WindowsServer/AstroServerSettings.ini")
ASTRONEER_SAVES_DIR = Path("/var/lib/game-servers/astroneer/Astro/Saved/SaveGames")

SERVERS = {
    "astroneer": {
        "label": "Astroneer",
        "container": "astroneer-server",
        "rcon": False,
        "bedrock": False,
        "ports": "7777/udp, 27777/udp",
    },
    "minecraft-survival": {
        "label": "Minecraft Survival",
        "container": "minecraft-survival",
        "rcon": True,
        "bedrock": False,
        "ports": "25565/tcp",
    },
    "minecraft-minigames": {
        "label": "Minecraft Minigames",
        "container": "minecraft-minigames",
        "rcon": True,
        "bedrock": False,
        "ports": "25566/tcp",
    },
    "minecraft-bedrock": {
        "label": "Minecraft Bedrock",
        "container": "minecraft-bedrock",
        "rcon": False,
        "bedrock": True,
        "ports": "19132/udp, 19133/udp",
    },
}


def get_active_save() -> str:
    try:
        for line in ASTRONEER_INI.read_text().splitlines():
            if line.startswith("ActiveSaveFileDescriptiveName="):
                return line.split("=", 1)[1].strip()
    except OSError:
        pass
    return ""


def list_saves() -> list[str]:
    names: set[str] = set()
    try:
        for f in ASTRONEER_SAVES_DIR.iterdir():
            if f.suffix == ".savegame" and "$" in f.stem:
                names.add(f.stem.split("$")[0])
    except OSError:
        pass
    return sorted(names)


def verify_token(token: str = Query(...)):
    if token != TOKEN:
        raise HTTPException(status_code=403, detail="Forbidden")
    return token


def container_status(container: str) -> str:
    result = subprocess.run(
        ["docker", "inspect", "--format", "{{.State.Status}}", container],
        capture_output=True, text=True, timeout=5,
    )
    if result.returncode != 0:
        return "stopped"
    status = result.stdout.strip()
    # Normalize docker states (exited, created, paused) to "stopped" for display
    return "running" if status == "running" else "stopped"


def player_count(server: dict) -> int | None:
    if container_status(server["container"]) != "running":
        return None
    if server["rcon"]:
        result = subprocess.run(
            ["docker", "exec", server["container"], "rcon-cli", "list"],
            capture_output=True, text=True, timeout=5,
        )
        m = re.search(r"There are (\d+)", result.stdout)
        return int(m.group(1)) if m else None
    if server["bedrock"]:
        result = subprocess.run(
            ["docker", "exec", server["container"], "send-command", "list"],
            capture_output=True, text=True, timeout=5,
        )
        m = re.search(r"(\d+)/\d+", result.stdout)
        return int(m.group(1)) if m else None
    return None  # Astroneer — watchdog handles via log scan


def build_server_states(token: str) -> dict:
    states = {}
    for name, srv in SERVERS.items():
        status = container_status(srv["container"])
        players = player_count(srv) if status == "running" else None
        state = {**srv, "status": status, "players": players, "active_save": None, "available_saves": []}
        if name == "astroneer":
            state["active_save"] = get_active_save()
            state["available_saves"] = list_saves()
        states[name] = state
    return states


@app.get("/", response_class=HTMLResponse)
def dashboard(request: Request, token: str = Query(...)):
    verify_token(token)
    states = build_server_states(token)
    return templates.TemplateResponse(
        "index.html", {"request": request, "servers": states, "token": token}
    )


@app.post("/api/servers/{name}/start")
def start_server(name: str, token: str = Query(...)):
    verify_token(token)
    if name not in SERVERS:
        raise HTTPException(status_code=404, detail="Unknown server")
    srv = SERVERS[name]
    if container_status(srv["container"]) == "running":
        return RedirectResponse(f"/?token={token}", status_code=303)
    # Use the NixOS-managed systemd service so it handles image pull + container
    # creation on first start (docker start fails if container was never created).
    subprocess.run(["systemctl", "start", f"docker-{srv['container']}"], timeout=120, check=True)
    ts_file = STATE_DIR / f"{name}.last_active"
    ts_file.write_text(str(int(__import__("time").time())))
    return RedirectResponse(f"/?token={token}", status_code=303)


@app.post("/api/servers/{name}/stop")
def stop_server(name: str, token: str = Query(...)):
    verify_token(token)
    if name not in SERVERS:
        raise HTTPException(status_code=404, detail="Unknown server")
    srv = SERVERS[name]
    if container_status(srv["container"]) != "running":
        return RedirectResponse(f"/?token={token}", status_code=303)
    _safe_stop(srv, name)
    return RedirectResponse(f"/?token={token}", status_code=303)


@app.get("/api/servers/astroneer/switch-save")
def switch_save(token: str = Query(...), save: str = Query(...)):
    verify_token(token)
    if save not in list_saves():
        raise HTTPException(status_code=400, detail="Unknown save")
    if container_status("astroneer-server") == "running":
        raise HTTPException(status_code=409, detail="Stop the server before switching saves")
    text = ASTRONEER_INI.read_text()
    text = re.sub(
        r"^ActiveSaveFileDescriptiveName=.*$",
        f"ActiveSaveFileDescriptiveName={save}",
        text,
        flags=re.MULTILINE,
    )
    ASTRONEER_INI.write_text(text)
    return RedirectResponse(f"/?token={token}", status_code=303)


def _safe_stop(srv: dict, name: str):
    if srv["rcon"]:
        for cmd in ["save-all", "stop"]:
            subprocess.run(
                ["docker", "exec", srv["container"], "rcon-cli", cmd],
                timeout=15,
            )
        import time; time.sleep(8)
    subprocess.run(["systemctl", "stop", f"docker-{srv['container']}"], timeout=60)
    ts_file = STATE_DIR / f"{name}.last_active"
    ts_file.unlink(missing_ok=True)
