#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "$SCRIPT_DIR/common.sh"

INITIAL_POSE="0.0,0.0,0.0"
while [ "$#" -gt 0 ]; do
  case "$1" in
    --initial-pose)
      INITIAL_POSE="${2:-}"
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

MAP_FILE="${MAP_FILE:-$MAPS_DIR/exploration_map.yaml}"
TB3_PREFIX="$(ros2 pkg prefix turtlebot3_gazebo)"
MODEL_SDF="${MODEL_SDF:-$TB3_PREFIX/share/turtlebot3_gazebo/models/turtlebot3_${TURTLEBOT3_MODEL}/model.sdf}"
ENTITY_NAME="${ENTITY_NAME:-turtlebot3}"

if [ ! -f "$MAP_FILE" ]; then
  err "Map file not found: $MAP_FILE"
  exit 1
fi
if [ ! -f "$MODEL_SDF" ]; then
  err "Robot model not found: $MODEL_SDF"
  exit 1
fi

start_service rsp "$LOG_DIR/robot_state_publisher.log" \
  ros2 launch turtlebot3_gazebo robot_state_publisher.launch.py use_sim_time:=True

set +e
SPAWN_OUTPUT="$(
  ros2 run gazebo_ros spawn_entity.py \
    -entity "$ENTITY_NAME" \
    -file "$MODEL_SDF" \
    -x -2.0 -y -0.5 -z 0.01 2>&1
)"
SPAWN_RC="$?"
set -e
echo "$SPAWN_OUTPUT"
if [ "$SPAWN_RC" -ne 0 ]; then
  case "$SPAWN_OUTPUT" in
    *"already exists"*)
      log "Gazebo entity already exists. Continuing."
      ;;
    *)
      err "Failed to spawn TurtleBot3."
      exit 1
      ;;
  esac
fi

start_service localization "$LOG_DIR/localization.log" \
  ros2 launch nav2_bringup localization_launch.py use_sim_time:=True "map:=$MAP_FILE"

sleep 5
publish_initial_pose "$INITIAL_POSE"
