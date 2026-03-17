#!/bin/bash
set -e

unset ROS_DISTRO
source /noetic_ws/devel_isolated/setup.bash

unset ROS_DISTRO
source /ros2_jazzy/install/setup.bash

unset ROS_DISTRO
source /ros1_bridge_ws/install/setup.bash

exec "$@"