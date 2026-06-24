# Docker version used: Docker version 29.3.1, build c2be9cc
# The goal of this dockerfile is to create the base image for development for the ATMOS simulator.
# https://atmos.discower.io/
# This image is using a simulated px4 and not a real pixhawk running px4. 
# The packages needed for development: ROS 2 Humble Hawksbill, Gazebo Harmonic, PX4-Autopilot, Micro XRCE-DDS

# Base image of Ubuntu Jammy 22.04, ROS 2 Humble Hawksbill and Gazebo Harmonic
FROM osrf/ros:humble-desktop-full

# Prevent interactive prompts during package installations
ENV DEBIAN_FRONTEND=noninteractive

# Install core tools (added wget for QGroundControl)
RUN apt-get update && apt-get install -y \
    git \
    sudo \
    wget \
    && rm -rf /var/lib/apt/lists/*

# 1. Clone PX4 (Optimized with --depth 1)
WORKDIR /PX4-Autopilot
RUN git clone --depth 1 -b v1.17.0 https://github.com/PX4/PX4-Autopilot.git . --recursive

# 2. Install PX4 required packages
RUN bash ./Tools/setup/ubuntu.sh

# 3. Build PX4 messages for ROS 2
WORKDIR /px4_ws/src
RUN git clone --depth 1 -b v1.17.0 https://github.com/PX4/px4_msgs.git

WORKDIR /px4_ws
# FIXED: Sourced the Humble setup and ran colcon build in the same bash session
RUN /bin/bash -c "source /opt/ros/humble/setup.bash && colcon build"

# 4. Configure PX4 topics for ROS 2
COPY dds_topics.yaml /PX4-Autopilot/src/modules/uxrce_dds_client/dds_topics.yaml

# 5. Compile PX4 SITL
WORKDIR /PX4-Autopilot
# Note: I left all 3 here, but consider removing the first two if only the last is needed!
RUN make px4_sitl && make px4_sitl_spacecraft

# 6. Setting up QGroundControl
WORKDIR /qgc
# FIXED: Chained all apt installs, removed sudo, and added wget to download the AppImage
RUN apt-get update && apt-get install -y \
    gstreamer1.0-plugins-bad \
    gstreamer1.0-libav \
    gstreamer1.0-gl \
    libfuse2 \
    libxcb-xinerama0 \
    libxkbcommon-x11-0 \
    libxcb-cursor-dev \
    && apt-get remove -y modemmanager \
    && rm -rf /var/lib/apt/lists/*

RUN usermod -a -G dialout root

# Download and configure QGroundControl
RUN wget https://d176tv9ibo4jno.cloudfront.net/latest/QGroundControl-x86_64.AppImage \
    && chmod +x ./QGroundControl-x86_64.AppImage

# 7. Install and build the Micro XRCE-DDS Agent
WORKDIR /Micro-XRCE-DDS-Agent
RUN git clone --depth 1 -b v3.0.1 https://github.com/eProsima/Micro-XRCE-DDS-Agent.git .
# Build, compile and install:
WORKDIR /Micro-XRCE-DDS-Agent/build
RUN cmake .. && \
    make -j4 && \
    make install && \
    ldconfig /usr/local/lib/

###
RUN apt-get update && apt-get install -y --no-install-recommends \
    git curl ca-certificates \
    build-essential cmake ament-cmake pkg-config gfortran \
    python3-pip python3-dev \
    python3-colcon-common-extensions \
    python3-rosdep \
    && rm -rf /var/lib/apt/lists/*
    # python3-venv \
    # libblas-dev liblapack-dev \

# -----------------------------
# Rust (needed for acados tera renderer)
# -----------------------------
RUN curl https://sh.rustup.rs -sSf | sh -s -- -y
ENV PATH="/root/.cargo/bin:${PATH}"
RUN rustup update stable

# -----------------------------
# acados build & install
# -----------------------------
WORKDIR /acados
RUN git clone https://github.com/acados/acados.git . \
 && git submodule update --recursive --init

WORKDIR /acados/build
RUN cmake -DACADOS_WITH_QPOASES=ON -DCMAKE_INSTALL_PREFIX=/acados ..
RUN make -j"$(nproc)" && make install

# Python deps + acados_template
WORKDIR /acados
# Pin combos here if needed; default usually fine on Humble
RUN pip3 install --no-cache-dir "numpy==1.21.0" scipy jinja2 casadi \
 && pip3 install -e interfaces/acados_template

# Build tera renderer and place it on PATH
RUN git clone https://github.com/acados/tera_renderer.git
WORKDIR /acados/tera_renderer
RUN cargo build --release --verbose
WORKDIR /acados
RUN mkdir -p /acados/bin && mv tera_renderer/target/release/t_renderer /acados/bin/

# acados env
ENV ACADOS_SOURCE_DIR="/acados"
ENV ACADOS_INSTALL_DIR="/acados"
# Avoid build-time warning from undefined variable expansion
ENV LD_LIBRARY_PATH="/acados/lib"
ENV PATH="/acados/bin:${PATH}"

# -----------------------------
# ROS 2 workspace & sources
# -----------------------------
WORKDIR /ros2_ws/src
# Keep packages as siblings under src/
RUN git clone --branch dev-docker_test_ek https://github.com/DISCOWER/px4-mpc.git px4_mpc \
 && git clone https://github.com/Jaeyoung-Lim/px4-offboard.git
# --branch dev-docker_run

# Build
WORKDIR /ros2_ws
# Resolve system deps declared by packages
RUN rosdep init 2>/dev/null || true \
 && rosdep update \
 && rosdep install --from-paths src --ignore-src -r -y
RUN bash -c "source /opt/ros/humble/setup.bash && colcon build --packages-up-to px4_mpc"

# 8. Final Environment Setup
# Append the source commands to bashrc so they are active when you open the container
RUN echo "source /opt/ros/humble/setup.bash" >> ~/.bashrc && \
    echo "source /px4_ws/install/setup.bash" >> ~/.bashrc && \
    echo "source /ros2_ws/install/setup.bash" >> ~/.bashrc


ENTRYPOINT ["/bin/bash"]
