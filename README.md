# ros1bridge

Docker image for building and running `ros1_bridge` with:

- ROS 1 Noetic built from source
- ROS 2 Jazzy built from source
- `ros1_bridge` built against both installations

The image is based on Ubuntu 24.04 (Noble) and is intended to provide a ready-to-use bridge environment where the ROS 1, ROS 2, and bridge setup files are sourced automatically at container startup.

> **Note:** ROS 1 Noetic's officially supported platform is Ubuntu 20.04 (Focal). Building it on
> Ubuntu 24.04 (Noble) is an unsupported community port. It requires source-level patches and
> workarounds (Python 3.12 `distutils` removal, Noble-era library differences, etc.) and may
> need additional fixes as dependencies evolve.

## What this repository contains

- [Dockerfile](Dockerfile): builds the full environment
- [entrypoint.sh](entrypoint.sh): sources ROS 1, ROS 2, and `ros1_bridge`
- [ros2_minimal.repos](ros2_minimal.repos): optional local manifest (not used by default)

## What the Docker image does

The Docker build performs these steps:

1. Starts from `ubuntu:24.04`
2. Installs ROS 2 Jazzy development dependencies
3. Imports the official ROS 2 Jazzy source tree from `https://raw.githubusercontent.com/ros2/ros2/jazzy/ros2.repos`
4. Builds ROS 2 in `/ros2_jazzy`
5. Installs the dependencies required to build ROS 1 Noetic from source on Ubuntu 24.04
6. Builds ROS 1 Noetic in `/noetic_ws`
7. Applies compatibility fixes required by the chosen ROS 1 build procedure
8. Clones and builds `ros1_bridge` in `/ros1_bridge_ws`
9. Installs an entrypoint that sources:
    - `/noetic_ws/devel_isolated/setup.bash`
    - `/ros2_jazzy/install/setup.bash`
    - `/ros1_bridge_ws/install/setup.bash`

## Resulting layout inside the container

- `/ros2_jazzy`: ROS 2 Jazzy source workspace and install tree
- `/noetic_ws`: ROS 1 Noetic source workspace and isolated build/devel outputs
- `/ros1_bridge_ws`: `ros1_bridge` workspace

## Build the image

Build from the repository root:

```bash
docker build -t ros1bridge .
```

This build is large and can take a long time because both ROS distributions are compiled from source.

## Run the container

Start an interactive shell:

```bash
docker run --rm -it ros1bridge bash
```

Because the entrypoint sources all setup files automatically, the shell starts with ROS 1, ROS 2, and `ros1_bridge` already available.

## Run with Docker Compose (Zenoh + dynamic bridge)

Start a bridge service using the provided Compose file:

```bash
docker compose up --build
```

If you changed compose configuration, recreate the service:

```bash
docker compose down && docker compose up --build
```

The compose service:

- sets `RMW_IMPLEMENTATION=rmw_zenoh_cpp`
- expects an external `roscore` at `ROS_MASTER_URI` (defaults to `http://127.0.0.1:11311`)
- supports `ROS_DOMAIN_ID` through environment variables
- runs `ros2 run ros1_bridge dynamic_bridge --bridge-all-1to2-topics --bridge-all-2to1-topics`
- uses the container entrypoint to source ROS 1/ROS 2 overlays and load Zenoh RMW runtime libraries

Stop it with:

```bash
docker compose down
```

## Typical usage

Inside the container, you can run the dynamic bridge with:

```bash
ros2 run ros1_bridge dynamic_bridge
```

Or inspect the bridge package:

```bash
ros2 pkg executables ros1_bridge
```

## Notes

- The image builds ROS 2 from the official Jazzy source manifest (`ros2.repos`).
- The ROS 1 build includes manual fixes and patches required for this Ubuntu 24.04 (Noble)-based workflow.
    - Python 3.12 removed `distutils` from the standard library; `python3-setuptools` provides the replacement.
    - `hddtemp` is not in Noble's package repos and is installed from the Ubuntu Focal archive.
- `apt-get clean` is run at the end of the build, but the final image is still expected to be large.

## References

The Dockerfile follows these upstream approaches:

- ROS 2 Jazzy Ubuntu development setup
- ROS 1 Noetic source build workflow adapted for Ubuntu 24.04 Noble
- Official `ros1_bridge` build sequence: source ROS 1, source ROS 2, then build the bridge
