#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
ROS_MAIN_WS="${ROS_MAIN_WS:-$HOME/ros2_ws}"
RUNTIME_ROOT="${ROS2_CONTROL_RUNTIME_ROOT:-$REPO_DIR/runtime/BT_Navigator}"

GENERATED_BT_DIR="$RUNTIME_ROOT/behavior_trees/generated"
LEGACY_GENERATED_BT_DIR="$RUNTIME_ROOT/behavior_trees/__generated"
REFERENCE_BT_DIR="$RUNTIME_ROOT/behavior_trees"
PARAMS_DIR="$RUNTIME_ROOT/params"
MAPS_DIR="$RUNTIME_ROOT/maps"
CONFIG_DIR="$RUNTIME_ROOT/config"
LOG_DIR="$RUNTIME_ROOT/logs"
STATE_DIR="$RUNTIME_ROOT/state"
PID_DIR="$STATE_DIR/pids"

LOCATIONS_FILE="$CONFIG_DIR/locations.yaml"
PARAMS_TEMPLATE="$PARAMS_DIR/nav2_params.yaml"
ACTIVE_NAV2_PARAMS="$PARAMS_DIR/nav2_params.active.yaml"
DEFAULT_BT_XML="$GENERATED_BT_DIR/default_nav2_bt.xml"

log() { echo "[$(date +'%Y-%m-%d %H:%M:%S')] [INFO] $*"; }
err() { echo "[$(date +'%Y-%m-%d %H:%M:%S')] [ERROR] $*" >&2; }

ensure_runtime_dirs() {
  mkdir -p "$GENERATED_BT_DIR" "$PARAMS_DIR" "$MAPS_DIR" "$CONFIG_DIR" "$LOG_DIR" "$PID_DIR"
}

source_ros_env() {
  # ROS setup scripts can reference unset variables; our scripts run with `set -u`.
  # Disable nounset while sourcing to avoid `unbound variable` failures.
  set +u
  # shellcheck disable=SC1091
  source /opt/ros/humble/setup.bash
  if [ -f "$ROS_MAIN_WS/install/setup.bash" ]; then
    # shellcheck disable=SC1091
    source "$ROS_MAIN_WS/install/setup.bash"
  fi
  set -u
  export TURTLEBOT3_MODEL="${TURTLEBOT3_MODEL:-burger}"
  export ROS_LOG_DIR="${ROS_LOG_DIR:-$LOG_DIR/ros}"
  mkdir -p "$ROS_LOG_DIR"
}

bootstrap_runtime() {
  ensure_runtime_dirs
  if [ -d "$LEGACY_GENERATED_BT_DIR" ]; then
    find "$LEGACY_GENERATED_BT_DIR" -maxdepth 1 -type f -name '*.xml' -exec cp -n {} "$GENERATED_BT_DIR"/ \;
  fi
  if [ -f "$REFERENCE_BT_DIR/navigate_to_pose_w_replanning_and_recovery.xml" ] && [ ! -f "$DEFAULT_BT_XML" ]; then
    cp "$REFERENCE_BT_DIR/navigate_to_pose_w_replanning_and_recovery.xml" "$DEFAULT_BT_XML"
  fi
}

pid_file() {
  echo "$PID_DIR/$1.pid"
}

read_pid() {
  local file
  file="$(pid_file "$1")"
  if [ -f "$file" ]; then
    tr -d '\n' < "$file"
  fi
}

is_pid_running() {
  local pid="${1:-}"
  if [ -z "$pid" ]; then
    return 1
  fi
  kill -0 "$pid" >/dev/null 2>&1
}

is_service_running() {
  local pid
  pid="$(read_pid "$1" || true)"
  is_pid_running "$pid"
}

write_pid() {
  echo "$2" > "$(pid_file "$1")"
}

clear_pid() {
  rm -f "$(pid_file "$1")"
}

stop_service() {
  local name="$1"
  local pid
  pid="$(read_pid "$name" || true)"
  if ! is_pid_running "$pid"; then
    clear_pid "$name"
    return 0
  fi
  kill "$pid" >/dev/null 2>&1 || true
  for _ in 1 2 3 4 5 6 7 8 9 10; do
    if ! is_pid_running "$pid"; then
      clear_pid "$name"
      return 0
    fi
    sleep 1
  done
  kill -KILL "$pid" >/dev/null 2>&1 || true
  clear_pid "$name"
}

start_service() {
  local name="$1"
  local logfile="$2"
  shift 2
  if is_service_running "$name"; then
    log "$name is already running."
    return 0
  fi
  "$@" >"$logfile" 2>&1 &
  local pid="$!"
  write_pid "$name" "$pid"
  sleep 2
  if ! is_pid_running "$pid"; then
    err "Service $name exited early. See $logfile"
    return 1
  fi
  log "Started $name (pid=$pid, log=$logfile)"
}

create_navigation_params() {
  local bt_xml="$1"
  python3 - "$PARAMS_TEMPLATE" "$ACTIVE_NAV2_PARAMS" "$bt_xml" <<'PY'
from pathlib import Path
import sys

template_path = Path(sys.argv[1])
out_path = Path(sys.argv[2])
bt_path = sys.argv[3]

lines = template_path.read_text(encoding="utf-8").splitlines()
updated = []
replaced = False
for line in lines:
    if line.lstrip().startswith("default_nav_to_pose_bt_xml:"):
        indent = line[: len(line) - len(line.lstrip())]
        updated.append(f"{indent}default_nav_to_pose_bt_xml: {bt_path}")
        replaced = True
    else:
        updated.append(line)
if not replaced:
    raise SystemExit("default_nav_to_pose_bt_xml not found in nav2 params template")
out_path.write_text("\n".join(updated) + "\n", encoding="utf-8")
PY
}

resolve_goal_pose() {
  local goal_ref="$1"
  if [[ "$goal_ref" == *,*,* ]]; then
    echo "$goal_ref"
    return 0
  fi
  python3 - "$LOCATIONS_FILE" "$goal_ref" <<'PY'
import sys
from pathlib import Path
import yaml

loc_path = Path(sys.argv[1])
goal_name = sys.argv[2]
data = yaml.safe_load(loc_path.read_text(encoding="utf-8")) or {}
locations = data.get("locations", {})
coords = locations.get(goal_name)
if not isinstance(coords, list) or len(coords) != 3:
    raise SystemExit(f"Unknown goal location: {goal_name}")
print(f"{coords[0]},{coords[1]},{coords[2]}")
PY
}

publish_initial_pose() {
  local pose_csv="$1"
  IFS=',' read -r IX IY IYAW <<< "$pose_csv"
  if [ -z "$IX" ] || [ -z "$IY" ] || [ -z "$IYAW" ]; then
    err "Invalid initial pose. Expected x,y,yaw"
    return 1
  fi
  read -r IQZ IQW <<< "$(python3 -c "import math; yaw=float('$IYAW'); print(math.sin(yaw/2.0), math.cos(yaw/2.0))")"
  ros2 topic pub -1 /initialpose geometry_msgs/msg/PoseWithCovarianceStamped \
    "{header: {frame_id: map}, pose: {pose: {position: {x: $IX, y: $IY, z: 0.0}, orientation: {z: $IQZ, w: $IQW}}, covariance: [0.25, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.25, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0685]}}"
}

send_nav_goal() {
  local pose_csv="$1"
  IFS=',' read -r GX GY GYAW <<< "$pose_csv"
  if [ -z "$GX" ] || [ -z "$GY" ] || [ -z "$GYAW" ]; then
    err "Invalid goal pose. Expected x,y,yaw"
    return 1
  fi
  read -r GQZ GQW <<< "$(python3 -c "import math; yaw=float('$GYAW'); print(math.sin(yaw/2.0), math.cos(yaw/2.0))")"
  ros2 action send_goal /navigate_to_pose nav2_msgs/action/NavigateToPose \
    "{pose: {header: {frame_id: map}, pose: {position: {x: $GX, y: $GY, z: 0.0}, orientation: {z: $GQZ, w: $GQW}}}}"
}
