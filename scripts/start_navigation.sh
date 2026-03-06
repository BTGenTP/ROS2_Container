#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "$SCRIPT_DIR/common.sh"

BT_XML="$DEFAULT_BT_XML"
while [ "$#" -gt 0 ]; do
  case "$1" in
    --bt-xml)
      BT_XML="${2:-}"
      shift 2
      ;;
    *)
      err "Unknown argument: $1"
      exit 1
      ;;
  esac
done

bootstrap_runtime
source_ros_env

if [ ! -f "$BT_XML" ]; then
  err "Behavior tree file not found: $BT_XML"
  exit 1
fi
if [ ! -f "$PARAMS_TEMPLATE" ]; then
  err "Nav2 params template not found: $PARAMS_TEMPLATE"
  exit 1
fi

create_navigation_params "$BT_XML"
start_service navigation "$LOG_DIR/navigation.log" \
  ros2 launch nav2_bringup navigation_launch.py use_sim_time:=True "params_file:=$ACTIVE_NAV2_PARAMS"
