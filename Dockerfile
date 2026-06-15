# Docker version used: Docker version 29.3.1, build c2be9cc
# The goal of this dockerfile is to create the base image for development for the ATMOS simulator.
# https://atmos.discower.io/
# This image is using a simulated px4 and not a real pixhawk running px4. 
# The packages needed for development: ROS 2 Jazzy Jalisco, Gazebo Harmonic, PX4-Autopilot, Micro XRCE-DDS

# Base image of Ubuntu Noble 24.04, ROS 2 Jazzy Jalisco and Gazebo Harmonic
FROM osrf/ros:jazzy-desktop-full@sha256:0fa6bd064d106b6be7e98f5838fd5b773fbc2de37c91b7a614ef94e72369e656

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
# FIXED: Sourced the Jazzy setup and ran colcon build in the same bash session
RUN /bin/bash -c "source /opt/ros/jazzy/setup.bash && colcon build"

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

# 8. Final Environment Setup
# Append the source commands to bashrc so they are active when you open the container
RUN echo "source /opt/ros/jazzy/setup.bash" >> ~/.bashrc && \
    echo "source /px4_ws/install/setup.bash" >> ~/.bashrc

CMD ["/bin/bash"]