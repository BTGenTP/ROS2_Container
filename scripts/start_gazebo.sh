#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "$SCRIPT_DIR/common.sh"

HEADLESS=0
while [ "$#" -gt 0 ]; do
  case "$1" in
    --headless) HEADLESS=1; shift ;;
    *)
      err "Unknown argument: $1"
      exit 1
      ;;
  esac
done

bootstrap_runtime
source_ros_env

TB3_PREFIX="$(ros2 pkg prefix turtlebot3_gazebo)"
WORLD_FILE="${WORLD_FILE:-$TB3_PREFIX/share/turtlebot3_gazebo/worlds/turtlebot3_world.world}"

if [ ! -f "$WORLD_FILE" ]; then
  err "Gazebo world not found: $WORLD_FILE"
  exit 1
fi

start_service gzserver "$LOG_DIR/gzserver.log" ros2 launch gazebo_ros gzserver.launch.py "world:=$WORLD_FILE"

if [ "$HEADLESS" -eq 0 ]; then
  start_service gzclient "$LOG_DIR/gzclient.log" ros2 launch gazebo_ros gzclient.launch.py
else
  log "Headless mode requested: gzclient not started."
fi
