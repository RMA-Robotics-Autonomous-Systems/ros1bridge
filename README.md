# ros1bridge

Docker image for building and running `ros1_bridge` with:

- ROS 1 Noetic built from source
- ROS 2 Humble built from source
- `ros1_bridge` built against both installations

The image is based on Ubuntu 22.04 and is intended to provide a ready-to-use bridge environment where the ROS 1, ROS 2, and bridge setup files are sourced automatically at container startup.

## What this repository contains

- [Dockerfile](Dockerfile): builds the full environment
- [entrypoint.sh](entrypoint.sh): sources ROS 1, ROS 2, and `ros1_bridge`
- [ros2_minimal.repos](ros2_minimal.repos): ROS 2 source manifest used for the Humble build

## What the Docker image does

The Docker build performs these steps:

1. Starts from `ubuntu:22.04`
2. Installs ROS 2 Humble development dependencies
3. Imports a minimal ROS 2 Humble source tree from [ros2_minimal.repos](ros2_minimal.repos)
4. Builds ROS 2 in `/ros2_humble`
5. Installs the dependencies required to build ROS 1 Noetic from source on Ubuntu 22.04
6. Builds ROS 1 Noetic in `/noetic_ws`
7. Applies compatibility fixes required by the chosen ROS 1 build procedure
8. Clones and builds `ros1_bridge` in `/ros1_bridge_ws`
9. Installs an entrypoint that sources:
    - `/noetic_ws/devel_isolated/setup.bash`
    - `/ros2_humble/install/setup.bash`
    - `/ros1_bridge_ws/install/setup.bash`

## Resulting layout inside the container

- `/ros2_humble`: ROS 2 Humble source workspace and install tree
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

- The image builds ROS 2 from a minimal curated source list, not from the full desktop distribution.
- The ROS 1 build includes manual fixes and patches required for this Ubuntu 22.04-based workflow.
- `apt-get clean` is run at the end of the build, but the final image is still expected to be large.

## References

The Dockerfile follows these upstream approaches:

- ROS 2 Humble Ubuntu development setup
- ROS 1 Noetic source build workflow for Ubuntu 22.04 compatibility
- Official `ros1_bridge` build sequence: source ROS 1, source ROS 2, then build the bridge
