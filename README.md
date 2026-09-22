<p align="center">
  🌎 English | <a href="./README.zh.md">🇨🇳 中文</a> | <a href="./README.ru.md">🇷🇺 Русский</a>
</p>

# Quadruped Robot Reinforcement Learning Control Framework

[📖 Online documentation](https://yoboticshub.github.io/yobotics_quad48/en/index.html)

> RL control, simulation, and deployment package for the quad48 / Yobotics Quad quadruped robot. It supports real-time MuJoCo simulation. Runtime environment: Ubuntu 20.04 or later, with x86_64 and RK3588/aarch64 controller distribution packages.

See [VERSION.txt](./VERSION.txt) for version information. This repository is intended for delivery and secondary development of the `quad48 / Yobotics Quad` control package. It includes controller binaries and runtime libraries, MuJoCo simulation, LCM message types, a WebRTC service, an external-algorithm framework, and `E15` SDK examples.

Chinese documentation is preserved in [README.zh.md](./README.zh.md). The English manual source is in [docs_en/](./docs_en/) and can be built with [mkdocs.en.yml](./mkdocs.en.yml).

## Capability Overview

Current control modes:

- `DAMP`
- `RECOVERY_STAND`
- `RL_WALK`
- `RL_RUN`
- `DEVELOPMENT`

Main runtime paths:

1. MuJoCo simulation: use [config_sim.yaml](./config_sim.yaml) and [scripts/start_mujoco.sh](./scripts/start_mujoco.sh).
2. Physical robot control: use [config.yaml](./config.yaml) and [scripts/run_robot_controller.sh](./scripts/run_robot_controller.sh).

External algorithms connect through LCM only in `DEVELOPMENT` mode. See [external_algorithms/README.md](./external_algorithms/README.md).

## Quick Start

Start with simulation to verify the environment and model files.

### 1. Configure the Environment

```bash
# One-step Conda environment setup: Python + MuJoCo + LCM + ONNX Runtime
./scripts/setup_conda_env.sh
```

Manual setup, if needed:

```bash
# Create a Conda environment
conda create -n quad_controller python=3.8

# System dependencies
sudo apt-get install -y liblcm-dev libeigen3-dev

# Python dependencies
pip install numpy==1.24.4 mujoco==3.2.3 pyyaml onnxruntime pillow

# LCM Python bindings
./scripts/install_python_lcm.sh

# LCM network setup, if needed
sudo ./scripts/setup_lcm_network.sh
```

### 2. Start Simulation

```bash
# Activate the environment
conda activate quad_controller

# Start simulator and controller together
./scripts/start_mujoco.sh

# Start the SDK control client
./yobotics_sdk/build/E15_sport_client
```

Press `Ctrl+C` to stop all processes.

## Physical Robot Operation

Before running on hardware, complete a MuJoCo verification pass to confirm that the Python environment, model files, and base configuration are usable. The robot host is usually Ubuntu on RK3588/aarch64. At minimum, confirm that these are complete in the deployment package:

- `bin_rk3588/`: RK3588/aarch64 controller entry points
- `lib_rk3588/`: RK3588/aarch64 runtime libraries
- `config.yaml`: default hardware configuration
- `actor_model/`: ONNX policy models used by `RL_WALK` and `RL_RUN`
- `resources/`: robot URDF, XML, meshes, and related assets

For local verification on x86_64, scripts automatically switch to `bin/` and `lib/`.

### 1. Configuration Check

Hardware mode uses [config.yaml](./config.yaml). Before running, check:

- `simulation.enable_mujoco: false`: disables MuJoCo and enters the hardware control path.
- `motor_communication.type: spi_legacy`: uses the current hardware SPI communication path.
- `gamepad.device_type: hybrid`: allows local remote-control input and LCM/WebRTC control input.
- `safety_checker.enable_safety_check: True`: keep safety checks enabled. Disabling safety protection on a real robot is not recommended.

#### Model Configuration Quick Reference

The startup script selects the x86_64 or RK3588/aarch64 controller directory from `uname -m`, but robot-specific hardware configuration must still be confirmed manually in `config.yaml`.

| Model / Platform | `motor_communication.spi_type` | `motor_communication.spi_device0` | `motor_communication.spi_device1` | `imu.type` | `imu.port_base` | `imu.port_number` | `development.robot_id` | Development-mode LCM channels |
|-----------|--------------------------------|-----------------------------------|-----------------------------------|------------|-----------------|-------------------|------------------------|-------------------|
| `y15 / x86_64` | `"Y15"` | `"/dev/spidev2.0"` | `"/dev/spidev2.1"` | `"lord"` | `"/dev/ttyUSB"` | `0` | `"Y15"` | `Y15_development_state` / `Y15_development_command` |
| `E15 / ARM(RK3588/aarch64)` | `"E15"` | `"/dev/spidev3.0"` | `"/dev/spidev4.0"` | `"hipnuc"` | `"/dev/ttyS0"` | keep commented out or unset | `"E15"` | `E15_development_state` / `E15_development_command` |

When Y15 uses `lord`, uncomment `port_number` and set it according to the actual device number. When E15 uses `hipnuc`, set `port_base` to the full serial-device path.

If multiple model-specific configuration files are copied out, specify one explicitly at startup:

```bash
bash scripts/run_robot_controller.sh --config config.yaml
bash scripts/run_robot_controller.sh --config config_y15.yaml
bash scripts/run_robot_controller.sh --config config_e15.yaml
```

For remote-control, serial, SPI, or LCM channel changes, update `config.yaml` first and keep WebRTC configuration consistent with the main controller.

### 2. Start the Controller

Run from the repository root:

```bash
bash scripts/run_robot_controller.sh --config config.yaml
```

The script selects controller and library paths from `uname -m`:

- x86_64: `bin/ybt_ctrl` and `lib/`
- RK3588/aarch64: `bin_rk3588/ybt_ctrl` and `lib_rk3588/`

The script currently configures the LCM multicast network on `eth1`. If the robot uses another network interface, update [scripts/run_robot_controller.sh](./scripts/run_robot_controller.sh), or configure LCM multicast according to the site network.

### 3. Optional: Start WebRTC Remote Control and Video

To enable WebRTC video and remote control, first make sure the control/state channels in [WebRTC_server/config.json](./WebRTC_server/config.json) match these `config.yaml` fields:

- `gamepad.lcm_control_channel`
- `gamepad.lcm_state_channel`

Then run from the robot deployment-package root:

```bash
python3 WebRTC_server/control_publisher.py
```

See [WebRTC_server/README.md](./WebRTC_server/README.md) for WebRTC configuration, dependencies, and troubleshooting.

### 4. Runtime Checks and Stop

- Controller logs are written to `log/robot_log.txt` by default and key status is also printed in the terminal.
- Use `bash scripts/monitor_lcm.sh` or `bash scripts/launch_lcm_spy.sh` to inspect LCM channels and message frequency.
- If no robot state appears after controller startup, first check motor/SPI/IMU connections, the LCM interface, and communication settings in `config.yaml`.
- Press `Ctrl+C` to stop the foreground controller. Use `Ctrl+C` the same way for a foreground WebRTC service.

## Entry Points and Directories

- `bin/`: x86_64 distribution entry directory. `bin/ybt_ctrl` is the launcher script and `bin/ybt_ctrl.bin` is the actual controller binary.
- `lib/`: x86_64 runtime libraries, including ONNX Runtime and other shared libraries.
- `bin_rk3588/`: RK3588/aarch64 distribution entry directory, with the same structure as `bin/`.
- `lib_rk3588/`: RK3588/aarch64 runtime libraries.
- `config.yaml`: default hardware configuration.
- `config_sim.yaml`: default MuJoCo simulation configuration.
- `actor_model/`: ONNX policy models used by `RL_WALK` and `RL_RUN`.
- `mujoco_sim/`: MuJoCo simulation Python module.
- `resources/`: robot XML, URDF, and mesh assets.
- `scripts/`: environment setup, controller startup, LCM monitoring, network setup, and related scripts.
- `external_algorithms/`: external-algorithm integration framework for development mode.
- `WebRTC_server/`: WebRTC video and remote-control service.
- `yobotics_sdk/`: E15 SDK, example programs, and build/deployment helpers.
- `lcm-types/`: LCM protocol definitions and generated Python/C++/Java code.

### Modes

| Mode | Description |
|------|------|
| `DAMP` | Joint-lock / damping mode that holds the current position. |
| `RECOVERY_STAND` | Automatically recovers to a standing posture. |
| `RL_WALK` | RL walking control, supporting joystick/WebRTC remote control. |
| `RL_RUN` | RL running control. |
| `DEVELOPMENT` | External algorithm development mode through the LCM interface. |

### Configuration Files

Important `config.yaml` fields:

- `simulation.enable_mujoco`: simulation/hardware mode switch.
- `simulation.mujoco.xml_path`: MuJoCo scene-file path.
- `motor_communication.type`: communication mode, `lcm` for simulation and `spi_legacy` for hardware.
- `motor_communication.spi_type`: hardware model, `Y15` or `E15`.
- `motor_communication.spi_device0` / `motor_communication.spi_device1`: SPI device paths that must match the model and Linux device nodes.
- `imu.type`: IMU driver type. E15 uses `hipnuc`; Y15 uses `lord`.
- `imu.port_base`: IMU serial-device path or device-name prefix.
- `imu.port_number`: used only by Y15/lord. Uncomment and combine with `port_base` to form the actual device path.
- `development.robot_id`: development-mode robot identifier for matching LCM messages.
- `development.state_channel` / `development.command_channel`: development-mode state and command LCM channels.
- `gamepad.device_type`: remote-control type, such as `gamepad`, `at9s`, or `lcm`.
- `safety_checker`: multi-layer safety-check configuration.

## Development Entry Points

- [external_algorithms/README.md](./external_algorithms/README.md): external-algorithm integration in development mode.
- `lcm-types/`: control protocol and message fields.
- [scripts/launch_lcm_spy.sh](./scripts/launch_lcm_spy.sh): inspect messages, frequencies, and channel configuration.
- [yobotics_sdk/SDK_User_Guide.md](./yobotics_sdk/SDK_User_Guide.md): SDK integration guide for client-side applications.
