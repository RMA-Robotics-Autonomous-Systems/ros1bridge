# Multi-stage Dockerfile
# Stage 1: ROS 2 Jazzy - Ubuntu Development Setup
# See: https://docs.ros.org/en/jazzy/Installation/Alternatives/Ubuntu-Development-Setup.html
FROM ubuntu:24.04 AS ros2-jazzy

ENV DEBIAN_FRONTEND=noninteractive

# Generate locale - required by ROS 2 and by Noble's minimal Docker base
RUN apt-get update && apt-get install -y locales \
    && locale-gen en_US en_US.UTF-8 \
    && update-locale LC_ALL=en_US.UTF-8 LANG=en_US.UTF-8

ENV LANG=en_US.UTF-8
ENV LC_ALL=en_US.UTF-8

# Add ROS 2 apt repository
RUN apt-get update && apt-get install -y software-properties-common
RUN add-apt-repository universe

RUN apt-get update && apt-get install -y curl \
    && export ROS_APT_SOURCE_VERSION=$(curl -s https://api.github.com/repos/ros-infrastructure/ros-apt-source/releases/latest | grep -F "tag_name" | awk -F\" '{print $4}') \
    && curl -L -o /tmp/ros2-apt-source.deb "https://github.com/ros-infrastructure/ros-apt-source/releases/download/${ROS_APT_SOURCE_VERSION}/ros2-apt-source_${ROS_APT_SOURCE_VERSION}.$(. /etc/os-release && echo ${UBUNTU_CODENAME:-${VERSION_CODENAME}})_all.deb" \
    && dpkg -i /tmp/ros2-apt-source.deb

# Install development tools (Jazzy / Ubuntu 24.04 Noble set)
RUN apt-get update && apt-get install -y \
    python3-flake8-blind-except \
    python3-flake8-class-newline \
    python3-flake8-deprecated \
    python3-mypy \
    python3-pip \
    python3-pytest \
    python3-pytest-cov \
    python3-pytest-mock \
    python3-pytest-repeat \
    python3-pytest-rerunfailures \
    python3-pytest-runner \
    python3-pytest-timeout \
    ros-dev-tools


# get ROS2 code
RUN mkdir -p /ros2_jazzy/src
WORKDIR /ros2_jazzy
RUN vcs import --input https://raw.githubusercontent.com/ros2/ros2/jazzy/ros2.repos src

# upgrade all
RUN apt-get update && apt-get upgrade -y

# install dependencies
RUN rosdep init \
    && rosdep update \
    && rosdep install --from-paths src --ignore-src -y --rosdistro jazzy \
    --skip-keys="fastcdr rti-connext-dds-6.0.1 urdfdom_headers rmw_cyclonedds_cpp cyclonedds \
    iceoryx_binding_c rmw_connextdds lifecycle rosidl_generator_rs ros-jazzy-rosidl-generator-rs"

# Build ROS2 from source
RUN colcon build --symlink-install


#--------------------------------------------------------
#  INSTALL ROS1 NOETIC
#     - https://gist.github.com/Meltwin/fe2c15a5d7e6a8795911907f627255e0
#--------------------------------------------------------

# point 1.1
# python3-setuptools provides distutils which was removed from Python 3.12 stdlib
RUN apt-get update && apt-get -y install \
    python3-rosdep python3-rosinstall-generator python3-vcstools python3-vcstool \
    build-essential python3-setuptools

# point 1.X
RUN sed -i 's|https://raw.githubusercontent.com/ros/rosdistro/master/rosdep/base.yaml|https://gist.githubusercontent.com/Meltwin/0317ae7481c94da7fd66c3eea8d40740/raw/04f6404249b0430523671410891815e63eadb2fe/base.yaml|g' /etc/ros/rosdep/sources.list.d/20-default.list

# point 1.Y - hddtemp is not in Ubuntu 24.04 (Noble) repos
# Install the focal amd64 deb directly; libsensors5 satisfies its only runtime dep
RUN apt-get install -y libsensors5 \
    && curl -L -o /tmp/hddtemp.deb \
    "https://launchpad.net/ubuntu/+archive/primary/+files/hddtemp_0.3-beta15-53_amd64.deb" \
    && dpkg -i /tmp/hddtemp.deb || apt-get install -f -y

# point 1.2
RUN rosdep update

# INSTALLATION
# point 2.1
RUN mkdir -p /noetic_ws/src
WORKDIR /noetic_ws

RUN rosinstall_generator ros_core --rosdistro noetic --deps --tar > noetic-minimal.rosinstall
RUN vcs import --input noetic-minimal.rosinstall src

RUN rosdep install --from-paths ./src --ignore-packages-from-source --rosdistro noetic -y

## FIXING FROM THE GUIDE
#
#   We need to replace "src/rosconsole/src/rosconsole/impl/rosconsole_log4cxx.cpp"
#   With "https://raw.githubusercontent.com/ros/rosconsole/9f930c007dd40aa7ede771b8859b529e024d7bfb/src/rosconsole/impl/rosconsole_log4cxx.cpp"
#

RUN rm src/rosconsole/src/rosconsole/impl/rosconsole_log4cxx.cpp
RUN curl -o src/rosconsole/src/rosconsole/impl/rosconsole_log4cxx.cpp https://raw.githubusercontent.com/ros/rosconsole/9f930c007dd40aa7ede771b8859b529e024d7bfb/src/rosconsole/impl/rosconsole_log4cxx.cpp

## FIXING MUTEX ISSUE
#
#   We need to add the following script to the root of the workspace: "https://gist.githubusercontent.com/Meltwin/1ee35296d2bb86fee19d639580e3c91f/raw/13b8d626733981cdf58244708e5cba1ee5d87e1c/change_cpp.py"
#   Then run: it to fix mutex issues in some packages
#   We need colorama installed for that

RUN curl -o change_cpp.py https://gist.githubusercontent.com/Meltwin/1ee35296d2bb86fee19d639580e3c91f/raw/13b8d626733981cdf58244708e5cba1ee5d87e1c/change_cpp.py
RUN pip3 install colorama
# Fix the script to work in Docker (no terminal available)
RUN sed -i 's/DISPLAY_WIDTH = min(WANTED_WIDTH, os.get_terminal_size().columns - 2)/DISPLAY_WIDTH = WANTED_WIDTH/g' change_cpp.py

RUN python3 change_cpp.py

RUN src/catkin/bin/catkin_make_isolated -DCMAKE_BUILD_TYPE=Release



#--------------------------------------------------------
#  Build the ros1_bridge package
#--------------------------------------------------------

# RUN python3 -m pip install -U colcon-common-extensions vcstool

RUN mkdir -p /ros1_bridge_ws/src
WORKDIR /ros1_bridge_ws/src
RUN git clone https://github.com/ros2/ros1_bridge

ENV ROS1_INSTALL_PATH=/noetic_ws/devel_isolated
ENV ROS2_INSTALL_PATH=/ros2_jazzy/install

# Build ros1_bridge following the official instructions:
# 1. First source ROS1
# 2. Then source ROS2
# 3. Build with both environments active
WORKDIR /ros1_bridge_ws
RUN bash -c "source ${ROS1_INSTALL_PATH}/setup.bash && \
    source ${ROS2_INSTALL_PATH}/setup.bash && \
    colcon build --symlink-install --packages-select ros1_bridge --cmake-force-configure --cmake-args -DCMAKE_BUILD_TYPE=Release"



#--------------------------------------------------------
#  Clean up
#     Remove all unnecessary files to reduce image size
#--------------------------------------------------------
WORKDIR /
RUN apt-get clean && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

#--------------------------------------------------------
#  Entry Point
#--------------------------------------------------------
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh
ENTRYPOINT [ "/entrypoint.sh" ]
CMD ["$@"]

