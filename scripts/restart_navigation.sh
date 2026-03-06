#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "$SCRIPT_DIR/common.sh"

BT_XML="$DEFAULT_BT_XML"
INITIAL_POSE=""

while [ "$#" -gt 0 ]; do
  case "$1" in
    --bt-xml)
      BT_XML="${2:-}"
      shift 2
      ;;
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

"$SCRIPT_DIR/stop_navigation.sh"
"$SCRIPT_DIR/start_navigation.sh" --bt-xml "$BT_XML"

if [ -n "$INITIAL_POSE" ]; then
  source_ros_env
  publish_initial_pose "$INITIAL_POSE"
fi
