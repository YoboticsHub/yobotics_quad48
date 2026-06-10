# Yobotics Quad Controller - Simulation Package

版本信息见 [VERSION.txt](/home/user/文档/code%20bag/20260602四足开源资料/yobotics_quad48/VERSION.txt)。当前仓库面向 `quad48 / Yobotics Quad` 控制包交付与二次开发，包含主控制器二进制与依赖库、MuJoCo 仿真、LCM 消息类型、WebRTC 服务、外部算法框架，以及 `E15` SDK 示例。

## 能力概览

当前控制模式如下：

- `DAMP`
- `RECOVERY_STAND`
- `RL_WALK`
- `RL_RUN`
- `DEVELOPMENT`

主要有两种运行方式：

1. MuJoCo 仿真：使用 [config_sim.yaml](/home/user/文档/code%20bag/20260602四足开源资料/yobotics_quad48/config_sim.yaml) 和 [scripts/start_mujoco.sh](/home/user/文档/code%20bag/20260602四足开源资料/yobotics_quad48/scripts/start_mujoco.sh)
2. 真机控制：使用 [config.yaml](/home/user/文档/code%20bag/20260602四足开源资料/yobotics_quad48/config.yaml) 和 `bin/ybt_ctrl`，或通过 [scripts/run_controller.sh](/home/user/文档/code%20bag/20260602四足开源资料/yobotics_quad48/scripts/run_controller.sh) 启动

外部算法只在 `DEVELOPMENT` 模式下通过 LCM 接入，相关说明见 [external_algorithms/README.md](/home/user/文档/code%20bag/20260602四足开源资料/yobotics_quad48/external_algorithms/README.md)。

## 快速开始

推荐先走仿真链路确认环境和模型可用性。

```bash
./scripts/setup_conda_env.sh
conda activate robot_controller
./scripts/start_mujoco.sh
```

[scripts/start_mujoco.sh](/home/user/文档/code%20bag/20260602四足开源资料/yobotics_quad48/scripts/start_mujoco.sh) 默认读取 `config_sim.yaml`，并自动同时拉起 MuJoCo 仿真器与控制器。需要无界面模式时可使用：

```bash
./scripts/start_mujoco.sh --headless
```

若只想单独运行控制器：

```bash
./bin/ybt_ctrl
```

或：

```bash
./scripts/run_controller.sh
```

`yobotics_sdk_e15_sdk_260408/build/E15_sport_client` 不是仿真必需入口，它更适合作为 `LCM` 调试或客户侧示例程序。

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

## 配置说明

`config.yaml` 默认面向真机，`config_sim.yaml` 默认面向 MuJoCo 仿真。两者结构基本一致，但默认通信方式和安全检查策略不同。

高频需要关注的配置项：

- `motor_communication.type`
  - `lcm` 常用于仿真
  - `spi_legacy` 是当前真机默认值
- `simulation.enable_mujoco`
  - `true` 时走 MuJoCo 仿真链路
  - `false` 时走真机控制链路
- `rl_walk.*` / `rl_run.*`
  - 指定模型路径、观测维度、控制周期和日志文件位置
- `development.*`
  - 配置开发模式的 `robot_id`、状态通道和命令通道
- `gamepad.device_type`
  - 支持 `at9s`、`gamepad`、`lcm`、`hybrid`
  - 设为 `lcm` 时，可由 WebRTC 或上位机经 LCM 下发控制命令
- `safety_checker.*`
  - 控制姿态、关节、腿部速度以及硬件丢失相关安全检查

修改模型、LCM 通道、遥控输入方式或仿真/真机切换时，优先核对这几个区域。

## WebRTC 与 LCM 辅助能力

当 `gamepad.device_type: lcm` 时，控制器会监听 `QUAD_ROBOT_CONTROL`，并向 `QUAD_ROBOT_STATE` 回传状态。WebRTC 服务位于 [WebRTC_server](/home/user/文档/code%20bag/20260602四足开源资料/yobotics_quad48/WebRTC_server)，其中：

- `publisher.py` 负责摄像头视频推流，并将 JSON 控制命令转换为 `sport_client_cmd_t`
- `control_publisher.py` 负责托管 `publisher.py` 与 `signaling_server.py`，更像服务管理脚本，不是核心控制器

当前 JSON 控制字段以 `publisher.py` 实际实现为准：

```json
{
  "mode": 1101,
  "v": [0.5, 0.0, 0.0],
  "rpy": [0.0, 0.0, 0.0],
  "h": [0.0]
}
```

其中：

- `mode`：控制模式或 API 编号
- `v`：速度命令，最多取前三个值
- `rpy`：姿态命令
- `h`：机身高度命令，代码中读取 `h[0]`

辅助调试工具：

- [scripts/monitor_lcm.py](/home/user/文档/code%20bag/20260602四足开源资料/yobotics_quad48/scripts/monitor_lcm.py)：监控 LCM 通道频率并可视化变量
- [scripts/monitor_lcm.sh](/home/user/文档/code%20bag/20260602四足开源资料/yobotics_quad48/scripts/monitor_lcm.sh)：快速启动监控

## 开发入口

如果要做二次开发，通常从下面几个位置开始：

- [external_algorithms/README.md](/home/user/文档/code%20bag/20260602四足开源资料/yobotics_quad48/external_algorithms/README.md)：开发模式外部算法接入说明
- `lcm-types/`：查看控制协议和消息字段
- [scripts/monitor_lcm.py](/home/user/文档/code%20bag/20260602四足开源资料/yobotics_quad48/scripts/monitor_lcm.py)：抓消息、看频率、排查通道配置
- [yobotics_sdk_e15_sdk_260408/README.md](/home/user/文档/code%20bag/20260602四足开源资料/yobotics_quad48/yobotics_sdk_e15_sdk_260408/README.md)：客户侧集成 SDK 的说明

