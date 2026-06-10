# 四足机器人强化学习控制框架（仿真包）

> 四足机器人（quad48/Yobotics Quad）RL 控制仿真部署包，支持 MuJoCo 仿真模式实时运行。（运行环境：Ubuntu20.04以上x86架构系统）

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
2. 真机控制：使用 [config.yaml](./config.yaml) 和 `./run_human_debug.sh ../bin/ybt_ctrl`

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
./yobotics_sdk_e15_sdk_260408/build/E15_sport_client
```

按 `Ctrl+C` 停止所有进程。

## 运行入口与目录

- `bin/`：分发包入口目录，`bin/ybt_ctrl` 是启动包装脚本，`bin/ybt_ctrl.bin` 是实际控制器二进制
- `lib/`：运行时依赖库，包括 ONNX Runtime 等共享库
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
- `gamepad.device_type` — 遥控器类型（`gamepad`/`at9s`/`lcm`）
- `safety_checker` — 多层安全检查配置

## 开发入口

如果要做二次开发，通常从下面几个位置开始：

- [external_algorithms/README.md](./external_algorithms/README.md)：开发模式外部算法接入说明
- `lcm-types/`：查看控制协议和消息字段
- [scripts/monitor_lcm.py](./scripts/launch_lcm_spy.sh)：抓消息、看频率、排查通道配置
- [yobotics_sdk_e15_sdk_260408/SDK使用说明.md](./yobotics_sdk_e15_sdk_260408/SDK使用说明.md)：客户侧集成 SDK 的说明
