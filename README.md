# 四足机器人强化学习控制框架

> 四足机器人（quad48/Yobotics Quad）RL 控制仿真部署包，支持 MuJoCo 仿真模式实时运行。（运行环境：Ubuntu20.04以上，支持 x86_64 与 RK3588/aarch64 控制器分发包）

版本信息见 [VERSION.txt](./VERSION.txt)。当前仓库面向 `quad48 / Yobotics Quad` 控制包交付与二次开发，包含主控制器二进制与依赖库、MuJoCo 仿真、LCM 消息类型、WebRTC 服务、外部算法框架，以及 `E15` SDK 示例。

## 能力概览

当前控制模式如下：

- `DAMP`
- `RECOVERY_STAND`
- `RL_WALK`
- `RL_RUN`
- `DEVELOPMENT`

主要有两种运行方式：

1. MuJoCo 仿真：使用 [config_sim.yaml](./config_sim.yaml) 和 [scripts/start_mujoco.sh](./scripts/start_mujoco.sh)
2. 真机控制：使用 [config.yaml](./config.yaml) 和 [scripts/run_robot_controller.sh](./scripts/run_robot_controller.sh)

外部算法只在 `DEVELOPMENT` 模式下通过 LCM 接入，相关说明见 [external_algorithms/README.md](./external_algorithms/README.md)。

## 快速开始

推荐先走仿真链路确认环境和模型可用性。
### 1. 环境配置

```bash
# 一键配置 conda 环境（Python + MuJoCo + LCM + ONNX Runtime）
./scripts/setup_conda_env.sh
```

若一键配置遇环境依赖问题需手动安装：

```bash
# 创建conda环境
conda create -n quad_controller python=3.8

# 系统依赖
sudo apt-get install -y liblcm-dev libeigen3-dev

# Python 依赖
pip install numpy==1.24.4 mujoco==3.2.3 pyyaml onnxruntime pillow

# LCM Python 绑定
./scripts/install_python_lcm.sh

# LCM 网络配置（如需要）
sudo ./scripts/setup_lcm_network.sh
```

### 2. 启动仿真

```bash
# 激活环境
conda activate quad_controller

# 一键启动（仿真器 + 控制器）
./scripts/start_mujoco.sh

# 启动控制脚本
./yobotics_sdk/build/E15_sport_client
```

按 `Ctrl+C` 停止所有进程。

## 实机运行

实机运行前建议先完成一次 MuJoCo 仿真验证，确认 Python 环境、模型文件和基础配置可用。机器人主机通常为 Ubuntu + RK3588/aarch64 环境，部署包内至少需要确认以下目录和文件完整：

- `bin_rk3588/`：RK3588/aarch64 控制器入口
- `lib_rk3588/`：RK3588/aarch64 运行时动态库
- `config.yaml`：实机默认配置文件
- `actor_model/`：`RL_WALK` 与 `RL_RUN` 使用的 ONNX 策略模型
- `resources/`：URDF、XML、网格等机器人资源

如果在 x86_64 主机上做本地验证，脚本会自动切换到 `bin/` 和 `lib/`。

### 1. 配置确认

实机默认使用 [config.yaml](./config.yaml)。运行前重点确认以下配置：

- `simulation.enable_mujoco: false`：关闭 MuJoCo 仿真，进入硬件控制链路
- `motor_communication.type: spi_legacy`：使用当前实机 SPI 通信方式
- `gamepad.device_type: hybrid`：支持本地遥控器与 LCM/WebRTC 控制输入
- `safety_checker.enable_safety_check: True`：保持安全检查开启；不建议在真实机器人上关闭安全保护

#### 型号配置速查

启动脚本会按 `uname -m` 自动选择 x86_64 或 RK3588/aarch64 对应的控制器目录，但机器人型号相关硬件配置仍需要在 `config.yaml` 中手动确认：

| 型号/平台 | `motor_communication.spi_type` | `motor_communication.spi_device0` | `motor_communication.spi_device1` | `imu.type` | `imu.port_base` | `imu.port_number` | `development.robot_id` | 开发模式 LCM 通道 |
|-----------|--------------------------------|-----------------------------------|-----------------------------------|------------|-----------------|-------------------|------------------------|-------------------|
| `y15 / x86_64` | `"Y15"` | `"/dev/spidev2.0"` | `"/dev/spidev2.1"` | `"lord"` | `"/dev/ttyUSB"` | `0` | `"Y15"` | `Y15_development_state` / `Y15_development_command` |
| `E15 / ARM(RK3588/aarch64)` | `"E15"` | `"/dev/spidev3.0"` | `"/dev/spidev4.0"` | `"hipnuc"` | `"/dev/ttyS0"` | 保持注释或不配置 | `"E15"` | `E15_development_state` / `E15_development_command` |

Y15 使用 `lord` 时需要取消 `port_number` 前的注释，并按现场设备号修改；E15 使用 `hipnuc` 时 `port_base` 直接填写完整串口路径。

如果复制出多个型号配置文件，可以在启动时显式指定：

```bash
bash scripts/run_robot_controller.sh --config config.yaml
bash scripts/run_robot_controller.sh --config config_y15.yaml
bash scripts/run_robot_controller.sh --config config_e15.yaml
```

如需调整遥控器、串口、SPI 或 LCM 通道，请优先修改 `config.yaml`，并保持 WebRTC 侧配置与主控配置一致。

### 2. 启动控制器

在项目根目录运行：

```bash
bash scripts/run_robot_controller.sh --config config.yaml
```

该脚本会按 `uname -m` 自动选择控制器和动态库路径：

- x86_64：使用 `bin/ybt_ctrl` 和 `lib/`
- RK3588/aarch64：使用 `bin_rk3588/ybt_ctrl` 和 `lib_rk3588/`

脚本当前会使用 `eth1` 配置 LCM 多播网络。如果机器人实际网卡名不是 `eth1`，请先调整 [scripts/run_robot_controller.sh](./scripts/run_robot_controller.sh) 中的网卡配置，或按现场网络环境完成对应 LCM 多播配置。

### 3. 可选：启动 WebRTC 远程控制/视频服务

如需启用 WebRTC 视频和远程控制，先确认 [WebRTC_server/config.json](./WebRTC_server/config.json) 中的控制/状态通道与 `config.yaml` 内以下配置一致：

- `gamepad.lcm_control_channel`
- `gamepad.lcm_state_channel`

然后在机器人部署包根目录运行：

```bash
python3 WebRTC_server/control_publisher.py
```

更多 WebRTC 配置、依赖和排查方式见 [WebRTC_server/README.md](./WebRTC_server/README.md)。

### 4. 运行检查与停止

- 控制器日志默认写入 `log/robot_log.txt`，也会在终端输出关键状态
- 如需检查 LCM 通道和消息频率，可使用 `bash scripts/monitor_lcm.sh` 或 `bash scripts/launch_lcm_spy.sh`
- 如果控制器启动后没有机器人状态，优先检查电机/SPI/IMU 连接、LCM 网卡和 `config.yaml` 中的通信配置
- 前台运行时按 `Ctrl+C` 停止控制器；WebRTC 服务前台运行时同样按 `Ctrl+C` 停止

## 运行入口与目录

- `bin/`：x86_64 分发包入口目录，`bin/ybt_ctrl` 是启动包装脚本，`bin/ybt_ctrl.bin` 是实际控制器二进制
- `lib/`：x86_64 运行时依赖库，包括 ONNX Runtime 等共享库
- `bin_rk3588/`：RK3588/aarch64 分发包入口目录，结构与 `bin/` 一致
- `lib_rk3588/`：RK3588/aarch64 运行时依赖库
- `config.yaml`：真机默认配置
- `config_sim.yaml`：MuJoCo 仿真默认配置
- `actor_model/`：`RL_WALK` 与 `RL_RUN` 使用的 ONNX 策略模型
- `mujoco_sim/`：MuJoCo 仿真 Python 模块
- `resources/`：机器人 XML、URDF 与网格资源
- `scripts/`：环境配置、控制器启动、LCM 监控、网络配置等脚本
- `external_algorithms/`：开发模式外部算法接入框架
- `WebRTC_server/`：WebRTC 视频与远程控制服务
- `yobotics_sdk_e15_sdk_260408/`：E15 SDK、示例程序与交叉编译辅助文件
- `lcm-types/`：LCM 协议定义及 Python/C++/Java 生成代码

### 各模式说明

| 模式 | 描述 |
|------|------|
| `DAMP` | 关节锁定模式，保持当前位置 |
| `RECOVERY_STAND` | 自动恢复到站立姿态 |
| `RL_WALK` | RL 行走控制（支持摇杆/WebRTC 远程控制） |
| `RL_RUN` | RL 跑步控制 |
| `DEVELOPMENT` | 外部算法开发模式（通过 LCM 接口） |

### 配置文件

所有配置集中在 `config.yaml`，关键配置项：

- `simulation.enable_mujoco` — 仿真/硬件模式切换
- `simulation.mujoco.xml_path` — MuJoCo 场景文件路径
- `motor_communication.type` — 通信方式（仿真用 `lcm`，硬件用 `spi_legacy`）
- `motor_communication.spi_type` — 实机型号（`Y15` 或 `E15`）
- `motor_communication.spi_device0` / `motor_communication.spi_device1` — SPI 设备路径，需与型号和系统设备节点一致
- `imu.type` — IMU 驱动类型（E15 使用 `hipnuc`，Y15 使用 `lord`）
- `imu.port_base` — IMU 串口路径或设备名前缀
- `imu.port_number` — 仅 Y15/lord 使用，需取消注释后与 `port_base` 拼接成实际设备路径
- `development.robot_id` — 开发模式机器人标识，用于生成或区分 LCM 消息标识
- `development.state_channel` / `development.command_channel` — 开发模式状态与指令 LCM 通道
- `gamepad.device_type` — 遥控器类型（`gamepad`/`at9s`/`lcm`）
- `safety_checker` — 多层安全检查配置

## 开发入口

如果要做二次开发，通常从下面几个位置开始：

- [external_algorithms/README.md](./external_algorithms/README.md)：开发模式外部算法接入说明
- `lcm-types/`：查看控制协议和消息字段
- [scripts/monitor_lcm.py](./scripts/launch_lcm_spy.sh)：抓消息、看频率、排查通道配置
- [yobotics_sdk/SDK使用说明.md](./yobotics_sdk/SDK使用说明.md)：客户侧集成 SDK 的说明
