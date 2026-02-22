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
echo "[ROS2_Container] Workspace mounted at /workspaces/btgen"

if [ -f /opt/ros/humble/setup.bash ]; then
  # Preload ROS env for terminals launched inside desktop (avoid duplicate lines)
  if ! grep -q "^source /opt/ros/humble/setup\.bash$" /etc/bash.bashrc; then
    echo "source /opt/ros/humble/setup.bash" >> /etc/bash.bashrc
  fi
fi

# Run noVNC (foreground)
exec websockify --web=/usr/share/novnc/ "${NOVNC_PORT}" "localhost:${VNC_PORT}"

