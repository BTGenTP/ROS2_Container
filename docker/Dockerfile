FROM osrf/ros:humble-desktop

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update \
  && apt-get install -y --no-install-recommends \
    # GUI + noVNC
    xfce4 xfce4-terminal dbus-x11 \
    xvfb x11vnc novnc websockify \
    # Utils
    ca-certificates curl git nano \
    mesa-utils \
    python3 python3-pip \
    # Nav2 + Turtlebot3 + Gazebo (proxy)
    ros-humble-navigation2 \
    ros-humble-nav2-bringup \
    ros-humble-nav2-bt-navigator \
    ros-humble-nav2-rviz-plugins \
    ros-humble-turtlebot3 \
    ros-humble-turtlebot3-msgs \
    ros-humble-turtlebot3-gazebo \
  && rm -rf /var/lib/apt/lists/*

# Default: software rendering (works everywhere)
ENV LIBGL_ALWAYS_SOFTWARE=1
ENV QT_X11_NO_MITSHM=1
ENV DISPLAY=:1

WORKDIR /workspaces/nav4rails

RUN python3 -m pip install --no-cache-dir openai python-dotenv

COPY sim_env/docker/entrypoint.sh /entrypoint.sh
RUN sed -i 's/\r$//' /entrypoint.sh && chmod +x /entrypoint.sh

EXPOSE 6080
EXPOSE 5900

ENTRYPOINT ["/entrypoint.sh"]

