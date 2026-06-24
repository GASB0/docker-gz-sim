# Dockerized ATMOS Simulator

A simple, containerized environment to test and run the [ATMOS PX4 SITL Setup](https://atmos.discower.io/pages/PX4/) without needing to install heavy dependencies directly on your host machine.

This repository bundles ROS 2, Gazebo, PX4, and the necessary DDS bridge into a single, reproducible Docker environment. It also automatically launches QGroundControl alongside the simulation.

---

## 📦 What's Inside

This Docker image is built on top of `Ubuntu Noble 24.04` and includes:
* **ROS 2:** Jazzy Jalisco
* **Simulator:** Gazebo Harmonic
* **Flight Stack:** PX4-Autopilot (v1.17.0)
* **Middleware:** Micro-XRCE-DDS-Agent (Compiled from source to bypass Docker `systemd`/Snap limitations)
* **Ground Station:** QGroundControl (AppImage configured to run without FUSE dependencies)

---

## 🛠️ Prerequisites

To run this simulation, your host machine must have:
1. **Docker Engine** (or Docker Desktop)
2. **Docker Compose**
3. **Git**
4. An active X11 server or display environment to render the Gazebo and QGroundControl GUIs (native on most Linux distributions; WSL 2 users should have WSLg enabled).

> **Note for Windows/WSL 2 Users:** Compiling modern C++ (Fast-DDS/PX4) requires significant memory. It is highly recommended to increase your WSL memory limit in your `.wslconfig` file (e.g., `memory=16GB`) before building, otherwise the `docker build` step may hang.

**For Windows users**
1. Install WSL2 and Ubuntu
They need to open PowerShell as Administrator and run:
```bash
wsl --install
```
(If they are on Windows 11, this automatically installs WSLg, which handles all the GUI rendering out-of-the-box).

2. Enable WSL Integration in Docker Desktop
They must open Docker Desktop, go to Settings > Resources > WSL Integration, and ensure the toggle for their Ubuntu distribution is turned ON.

---

## 🚀 Quick Start

**0. Make sure you have docker installed and running**
Check if docker is running with
```bash
sudo systemctl status docker
```

if not, use the following to enable and start it
```bash
sudo systemctl enable docker
sudo systemctl start docker
```

**1. Clone the repository**
```bash
git clone [https://github.com/YourUsername/docker-gz-sim.git](https://github.com/YourUsername/docker-gz-sim.git)
```
```bash
cd docker-gz-sim
```
```bash
xhost +local:
```
**2. Launch the Simulation**
Spin up both the PX4/Gazebo simulator and the Micro-XRCE-DDS Agent.
```bash
docker compose up -d
```

**If you want to build the image locally**
This is not necessary if you want to test run the simulation.
```bash
cd docker-gz-sim
```
**Build the Docker Image**
This will take some time upon the first run as it compiles PX4 and the DDS agent from source.
```bash
docker build .
```

📡 Accessing ROS 2 Topics

Because the docker-compose.yml is configured to use network_mode: host, your Docker container shares the network with your host machine.

If you have ROS 2 installed locally, you can view the live telemetry data from the simulated drone without even entering the container:
```bash
# On your local machine:
source /opt/ros/jazzy/setup.bash
ros2 topic list
ros2 topic echo /fmu/out/vehicle_attitude
```

🛑 Shutting Down

To cleanly stop the simulation, stop the DDS bridge, and tear down the containers:
```bash
docker compose down
```


To interact with ROS 2 and view the topics, you must enter the container:

**1. Enter the container's bash environment**

```bash
docker exec -it atmos_sim bash
```

**2. Run the ROS 2 check (inside the container):**

```bash
ros2 topic list
```
