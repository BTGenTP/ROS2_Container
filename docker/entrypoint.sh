#!/usr/bin/env bash
set -euo pipefail

VNC_RESOLUTION="${VNC_RESOLUTION:-1280x720}"
VNC_COL_DEPTH="${VNC_COL_DEPTH:-24}"
VNC_PORT="${VNC_PORT:-5900}"
NOVNC_PORT="${NOVNC_PORT:-6080}"

export DISPLAY="${DISPLAY:-:1}"

echo "[ROS2_Container] Starting Xvfb on ${DISPLAY} (${VNC_RESOLUTION}x${VNC_COL_DEPTH})"
Xvfb "${DISPLAY}" -screen 0 "${VNC_RESOLUTION}x${VNC_COL_DEPTH}" -ac +extension GLX +render -noreset &

echo "[ROS2_Container] Starting XFCE session"
dbus-launch --exit-with-session xfce4-session >/tmp/xfce.log 2>&1 &

echo "[ROS2_Container] Starting x11vnc on port ${VNC_PORT}"
x11vnc -display "${DISPLAY}" -nopw -forever -shared -rfbport "${VNC_PORT}" -xkb >/tmp/x11vnc.log 2>&1 &

echo "[ROS2_Container] noVNC available on :${NOVNC_PORT}"
echo "[ROS2_Container] Runtime root at /opt/ros2_container/runtime/BT_Navigator"

if [ -f /opt/ros/humble/setup.bash ]; then
  # Preload ROS env for terminals launched inside desktop (avoid duplicate lines)
  if ! grep -q "^source /opt/ros/humble/setup\.bash$" /etc/bash.bashrc; then
    echo "source /opt/ros/humble/setup.bash" >> /etc/bash.bashrc
  fi
fi

CONTROL_APP="/opt/ros2_container/api/app.py"
CONTROL_PORT="${ROS2_CONTROL_PORT:-8001}"
if [ -f "$CONTROL_APP" ]; then
  echo "[ROS2_Container] Starting control API on :${CONTROL_PORT}"
  python3 -m uvicorn app:app --app-dir "$(dirname "$CONTROL_APP")" \
    --host 0.0.0.0 --port "${CONTROL_PORT}" >/tmp/ros2_control_api.log 2>&1 &
fi

# Run noVNC (foreground)
exec websockify --web=/usr/share/novnc/ "${NOVNC_PORT}" "localhost:${VNC_PORT}"

