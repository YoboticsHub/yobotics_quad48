# Quad48 Secondary Development Package Scripts

This directory documents the `scripts/` folder in the standalone secondary-development package. The scripts target an already packaged `yobotics_quad48` development directory and are mainly used to run the controller, start simulation, configure LCM networking, monitor LCM messages, prepare the Python environment, and inspect runtime logs.

Chinese source: [README.zh.md](./README.zh.md).

## Before Use

Run commands from the development-package root when possible:

```bash
cd yobotics_quad48
```

Common package layout:

```text
yobotics_quad48/
├── bin/                  # x86_64 controller executable, for example ybt_ctrl
├── bin_rk3588/           # RK3588/aarch64 controller executable
├── lib/                  # x86_64 runtime shared libraries
├── lib_rk3588/           # RK3588/aarch64 runtime shared libraries
├── log/                  # runtime logs and CSV log output
├── lcm-types/            # LCM type definitions and generated files
├── mujoco_sim/           # MuJoCo simulation code
├── resources/            # robot models and assets
├── scripts/              # scripts documented here
├── config.yaml           # controller configuration
└── config_sim.yaml       # simulation configuration
```

Confirm permissions first:

```bash
chmod +x scripts/*.sh
```

## Recommended Workflow

### 1. Prepare Python Environment

```bash
bash scripts/setup_conda_env.sh
```

Install or repair only Python LCM bindings:

```bash
bash scripts/install_python_lcm.sh
```

### 2. Configure LCM Networking

If LCM messages are missing, monitoring tools show no data, or multi-machine communication fails:

```bash
sudo bash scripts/setup_lcm_network.sh
```

This usually requires `sudo` because it modifies network-interface and multicast-route settings.

### 3. Generate LCM Types

After modifying `.lcm` files under `lcm-types/`, or if generated Python/C++ files are missing:

```bash
bash scripts/generate_lcm_types.sh
```

### 4. Start Simulation and Controller

```bash
bash scripts/start_mujoco.sh --config config_sim.yaml
bash scripts/run_robot_controller.sh
```

Headless simulation:

```bash
bash scripts/start_mujoco.sh --headless
```

Display physical robot feedback in MuJoCo Viewer:

```bash
bash scripts/start_hardware_viewer.sh
```

### 5. Monitor and Analyze Data

```bash
bash scripts/monitor_lcm.sh
bash scripts/monitor_lcm.sh --no-gui
python3 scripts/data_viewer.py
python3 scripts/motor_trace_viewer.py log/motor_trace.csv
```

## Runtime Scripts

### `run_robot_controller.sh`

Starts the packaged controller. It selects x86_64 or RK3588/aarch64 `bin*/` and `lib*/` directories from `uname -m`.

```bash
bash scripts/run_robot_controller.sh
bash scripts/run_robot_controller.sh --config config.yaml
```

Use it to start the controller on hardware, verify `bin/ybt_ctrl` or `bin_rk3588/ybt_ctrl`, and debug controller parameters in `config.yaml`.

Notes:

- Run from the package root when possible.
- With no arguments, it uses `config.yaml` and selects controller by architecture.
- If shared libraries are missing, check the matching `lib/` or `lib_rk3588/` directory.
- If no state appears after startup, check simulation and the LCM network.

### `start_mujoco.sh`

Starts MuJoCo simulation. It reads the packaged simulation configuration by default or accepts a custom config path. The script selects x86_64 `bin/` and `lib/`, or RK3588/aarch64 `bin_rk3588/` and `lib_rk3588/`.

```bash
bash scripts/start_mujoco.sh
bash scripts/start_mujoco.sh --config config_sim.yaml
bash scripts/start_mujoco.sh --headless
```

Use it for local simulation debugging and verifying models, configuration, and assets.

### `start_hardware_viewer.sh`

Starts the hardware real-time MuJoCo Viewer. It sets `PYTHONPATH` and runs `hardware_mujoco_viewer.py`, which receives physical robot LCM feedback and displays joint angles, body attitude, and height.

Default parameters:

- XML model: `resources/robots/quad48/scene_terrain.xml`
- LCM URL: `udpm://239.255.76.67:7667?ttl=255`
- Viewer refresh rate: `60 Hz`

```bash
bash scripts/start_hardware_viewer.sh
bash scripts/start_hardware_viewer.sh --xml resources/robots/quad48/scene_flat.xml
bash scripts/start_hardware_viewer.sh --lcm-url "udpm://239.255.76.67:7667?ttl=255"
bash scripts/start_hardware_viewer.sh --viewer-hz 30
bash scripts/start_hardware_viewer.sh --help
```

### `hardware_mujoco_viewer.py`

Python hardware-state MuJoCo Viewer. It can run directly or through `start_hardware_viewer.sh`. It refreshes the MuJoCo pose from received hardware feedback and does not advance physics simulation.

```bash
python3 scripts/hardware_mujoco_viewer.py
python3 scripts/hardware_mujoco_viewer.py --xml resources/robots/quad48/scene_flat.xml
python3 scripts/hardware_mujoco_viewer.py --lcm-url "udpm://239.255.76.67:7667?ttl=255"
python3 scripts/hardware_mujoco_viewer.py --joint-channel leg_control_data --robot-state-channel QUAD_ROBOT_STATE
python3 scripts/hardware_mujoco_viewer.py --height 0.45 --x 0.0 --y 0.0 --viewer-hz 60 --stale-timeout 2.0
```

Main parameters:

- `--xml`: MuJoCo XML path, absolute or relative to the package root.
- `--lcm-url`: LCM URL for hardware feedback.
- `--joint-channel`: joint-feedback channel, default `leg_control_data`, message type `quad_joint_state_t`.
- `--robot-state-channel`: body-state channel, default `QUAD_ROBOT_STATE`, message type `sport_client_state_t`.
- `--height`: default floating-base height when no valid body height is received.
- `--x`, `--y`: fixed world-coordinate position in Viewer.
- `--viewer-hz`: Viewer refresh rate only.
- `--stale-timeout`: seconds without new messages before printing a stale warning.

## Other Common Scripts

- `monitor_lcm.sh`: launch LCM monitor; use `--no-gui` in text-only environments.
- `launch_lcm_spy.sh`: launch the official LCM spy tool.
- `setup_lcm_network.sh`: configure multicast routes and network-interface settings.
- `generate_lcm_types.sh`: regenerate bindings from `.lcm` files.
- `data_viewer.py`: plot normal CSV or RL data logs.
- `motor_trace_viewer.py`: plot motor target, actual position, velocity, and torque traces.
- `check_cmake_make_gcc.sh`: check CMake, Make, GCC, and G++.

## Safety Notes

- Use `config_sim.yaml` for simulation and `config.yaml` for hardware.
- Keep controller, SDK, WebRTC, simulation, and external algorithms on the same LCM URL and channel set.
- For hardware, confirm robot model, SPI devices, IMU port, emergency stop, and safety area before commands.
- Stop external algorithms and switch the robot to a safe mode before terminating the controller.
