#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "$SCRIPT_DIR/common.sh"

bootstrap_runtime

stop_service navigation
stop_service localization
stop_service rsp
stop_service gzclient
stop_service gzserver

rm -f "$ACTIVE_NAV2_PARAMS"
log "Simulation processes stopped."
