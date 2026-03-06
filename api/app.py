from __future__ import annotations

import os
import re
import subprocess
from datetime import datetime
from pathlib import Path
from typing import Any, Dict, Optional

from fastapi import FastAPI, HTTPException
from pydantic import BaseModel

REPO_DIR = Path(__file__).resolve().parent.parent
RUNTIME_ROOT = Path(os.getenv("ROS2_CONTROL_RUNTIME_ROOT", REPO_DIR / "runtime" / "BT_Navigator")).resolve()
GENERATED_BT_DIR = RUNTIME_ROOT / "behavior_trees" / "generated"
LEGACY_GENERATED_BT_DIR = RUNTIME_ROOT / "behavior_trees" / "__generated"
SCRIPTS_DIR = REPO_DIR / "scripts"

app = FastAPI(title="ROS2 Nav2 Control Plane")


def _script_path(name: str) -> Path:
    path = SCRIPTS_DIR / name
    if not path.exists():
        raise HTTPException(status_code=500, detail=f"Missing script: {path}")
    return path


def _script_env() -> Dict[str, str]:
    env = os.environ.copy()
    env.setdefault("ROS2_CONTROL_RUNTIME_ROOT", str(RUNTIME_ROOT))
    return env


def _run_script(name: str, args: list[str] | None = None, timeout: int = 180) -> Dict[str, Any]:
    cmd = ["/bin/bash", str(_script_path(name))]
    if args:
        cmd.extend(args)
    proc = subprocess.run(
        cmd,
        capture_output=True,
        text=True,
        timeout=timeout,
        env=_script_env(),
    )
    payload = {
        "command": cmd,
        "exit_code": proc.returncode,
        "stdout": proc.stdout.strip(),
        "stderr": proc.stderr.strip(),
    }
    if proc.returncode != 0:
        raise HTTPException(status_code=500, detail=payload)
    return payload


def _pid_status(name: str) -> Dict[str, Any]:
    pid_file = RUNTIME_ROOT / "state" / "pids" / f"{name}.pid"
    if not pid_file.exists():
        return {"running": False, "pid": None}
    try:
        pid = int(pid_file.read_text(encoding="utf-8").strip())
    except ValueError:
        return {"running": False, "pid": None}
    try:
        os.kill(pid, 0)
    except OSError:
        return {"running": False, "pid": pid}
    return {"running": True, "pid": pid}


def _ensure_runtime_tree() -> None:
    GENERATED_BT_DIR.mkdir(parents=True, exist_ok=True)
    (RUNTIME_ROOT / "logs").mkdir(parents=True, exist_ok=True)
    (RUNTIME_ROOT / "state" / "pids").mkdir(parents=True, exist_ok=True)
    if LEGACY_GENERATED_BT_DIR.exists():
        for xml_file in LEGACY_GENERATED_BT_DIR.glob("*.xml"):
            target = GENERATED_BT_DIR / xml_file.name
            if not target.exists():
                target.write_text(xml_file.read_text(encoding="utf-8"), encoding="utf-8")


def _safe_filename(filename: Optional[str]) -> str:
    base = re.sub(r"[^a-zA-Z0-9._-]+", "_", (filename or "").strip()).strip("._")
    if not base:
        base = f"bt_{datetime.utcnow().strftime('%Y%m%dT%H%M%SZ')}.xml"
    if not base.endswith(".xml"):
        base += ".xml"
    return base


def _resolve_bt_path(filename: str) -> Path:
    path = Path(filename)
    if path.is_absolute():
        return path
    return (GENERATED_BT_DIR / path.name).resolve()


class UploadBtRequest(BaseModel):
    xml: str
    filename: Optional[str] = None


class StartSimulationRequest(BaseModel):
    initial_pose: str = "0.0,0.0,0.0"
    headless: bool = False


class RestartNavigationRequest(BaseModel):
    bt_filename: str
    initial_pose: Optional[str] = None


class GoalRequest(BaseModel):
    goal_pose: Optional[str] = None
    goal_name: Optional[str] = None


class ExecuteBtRequest(BaseModel):
    xml: Optional[str] = None
    filename: Optional[str] = None
    goal_pose: Optional[str] = None
    goal_name: Optional[str] = None
    initial_pose: Optional[str] = "0.0,0.0,0.0"
    allow_invalid: bool = False
    start_stack_if_needed: bool = True
    restart_navigation: bool = True


@app.get("/api/health")
def health() -> Dict[str, Any]:
    _ensure_runtime_tree()
    return {
        "ok": True,
        "runtime_root": str(RUNTIME_ROOT),
        "generated_bt_dir": str(GENERATED_BT_DIR),
        "scripts_dir": str(SCRIPTS_DIR),
    }


@app.get("/api/status")
def status() -> Dict[str, Any]:
    _ensure_runtime_tree()
    generated = sorted(p.name for p in GENERATED_BT_DIR.glob("*.xml"))
    return {
        "runtime_root": str(RUNTIME_ROOT),
        "services": {
            "gzserver": _pid_status("gzserver"),
            "gzclient": _pid_status("gzclient"),
            "rsp": _pid_status("rsp"),
            "localization": _pid_status("localization"),
            "navigation": _pid_status("navigation"),
        },
        "generated_bt_files": generated[-20:],
    }


@app.post("/api/bt/upload")
def upload_bt(req: UploadBtRequest) -> Dict[str, Any]:
    _ensure_runtime_tree()
    filename = _safe_filename(req.filename)
    target = GENERATED_BT_DIR / filename
    target.write_text(req.xml.rstrip() + "\n", encoding="utf-8")
    return {
        "ok": True,
        "filename": filename,
        "path": str(target),
    }


@app.post("/api/sim/start")
def start_simulation(req: StartSimulationRequest) -> Dict[str, Any]:
    gazebo_args = ["--headless"] if req.headless else []
    gazebo = _run_script("start_gazebo.sh", gazebo_args, timeout=120)
    localization = _run_script(
        "start_localization.sh",
        ["--initial-pose", req.initial_pose],
        timeout=120,
    )
    return {"ok": True, "gazebo": gazebo, "localization": localization}


@app.post("/api/sim/reset")
def reset_simulation() -> Dict[str, Any]:
    result = _run_script("reset_simulation.sh", timeout=120)
    return {"ok": True, "result": result}


@app.post("/api/navigation/restart")
def restart_navigation(req: RestartNavigationRequest) -> Dict[str, Any]:
    bt_path = _resolve_bt_path(req.bt_filename)
    args = ["--bt-xml", str(bt_path)]
    if req.initial_pose:
        args.extend(["--initial-pose", req.initial_pose])
    result = _run_script("restart_navigation.sh", args, timeout=120)
    return {"ok": True, "result": result, "bt_path": str(bt_path)}


@app.post("/api/navigation/goal")
def send_goal(req: GoalRequest) -> Dict[str, Any]:
    if bool(req.goal_pose) == bool(req.goal_name):
        raise HTTPException(status_code=422, detail="Provide exactly one of goal_pose or goal_name")
    args = ["--goal-pose", req.goal_pose] if req.goal_pose else ["--goal-name", req.goal_name or ""]
    result = _run_script("send_nav_goal.sh", args, timeout=60)
    return {"ok": True, "result": result}


@app.post("/api/bt/execute")
def execute_bt(req: ExecuteBtRequest) -> Dict[str, Any]:
    _ensure_runtime_tree()
    filename = req.filename
    if req.xml:
        upload = upload_bt(UploadBtRequest(xml=req.xml, filename=req.filename))
        filename = upload["filename"]
    if not filename:
        raise HTTPException(status_code=422, detail="Provide xml or filename")

    if not req.allow_invalid and req.xml and "<root" not in req.xml:
        raise HTTPException(status_code=422, detail="XML payload does not look like a BehaviorTree root document")

    stack_result = None
    if req.start_stack_if_needed:
        stack_result = start_simulation(
            StartSimulationRequest(
                initial_pose=req.initial_pose or "0.0,0.0,0.0",
                headless=False,
            )
        )

    bt_path = _resolve_bt_path(filename)
    if req.restart_navigation:
        nav_result = restart_navigation(
            RestartNavigationRequest(
                bt_filename=str(bt_path),
                initial_pose=req.initial_pose,
            )
        )
    else:
        nav_result = _run_script("start_navigation.sh", ["--bt-xml", str(bt_path)], timeout=120)

    goal_result = None
    if req.goal_pose or req.goal_name:
        goal_result = send_goal(GoalRequest(goal_pose=req.goal_pose, goal_name=req.goal_name))

    return {
        "ok": True,
        "filename": bt_path.name,
        "bt_path": str(bt_path),
        "stack": stack_result,
        "navigation": nav_result,
        "goal": goal_result,
    }
