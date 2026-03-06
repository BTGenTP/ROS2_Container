#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "$SCRIPT_DIR/common.sh"

GOAL_REF=""
while [ "$#" -gt 0 ]; do
  case "$1" in
    --goal-pose)
      GOAL_REF="${2:-}"
      shift 2
      ;;
    --goal-name)
      GOAL_REF="${2:-}"
      shift 2
      ;;
    *)
      err "Unknown argument: $1"
      exit 1
      ;;
  esac
done

if [ -z "$GOAL_REF" ]; then
  err "Provide --goal-pose x,y,yaw or --goal-name <name>"
  exit 1
fi

bootstrap_runtime
source_ros_env

GOAL_POSE="$(resolve_goal_pose "$GOAL_REF")"
send_nav_goal "$GOAL_POSE"
