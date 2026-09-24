# Yobotics SDK ROS 2 工作空间

该工作空间提供 `sdk_ros2` 包，通过 `/control_command` 话题控制 Yobotics
四足机器人。

## 目录结构

```text
yobotics_sdk_ros2/
├── src/
│   └── sdk_ros2/
│       ├── launch/
│       ├── msg/
│       ├── src/
│       └── vendor/yobotics_sdk/
├── build/     # 构建后生成
├── install/   # 构建后生成
└── log/       # 构建后生成
```

## 环境依赖

- ROS 2 Jazzy
- LCM 开发库
- Eigen3 开发库

```bash
sudo apt install liblcm-dev libeigen3-dev
```

## 构建

```bash
cd ~/yobotics_quad48/yobotics_sdk_ros2
source /opt/ros/jazzy/setup.bash

colcon build --packages-select sdk_ros2 \
  --cmake-args -DPython3_EXECUTABLE=/usr/bin/python3

source install/setup.bash
```

显式指定系统 Python 可以避免激活 Conda 环境后，ROS 接口生成器找不到系统
Python 模块。使用其他 ROS 2 发行版时，请将 `jazzy` 替换为对应发行版名称。

## 运行

打开终端 1，启动控制节点并保持该终端运行：

```bash
cd ~/yobotics_quad48/yobotics_sdk_ros2
source /opt/ros/jazzy/setup.bash
source install/setup.bash

export YOBOTICS_LCM_URL='udpm://239.255.76.67:7667?ttl=255'
ros2 launch sdk_ros2 yobotics_sdk.launch.py
```

打开终端 2，同样加载环境：

```bash
cd ~/yobotics_quad48/yobotics_sdk_ros2
source /opt/ros/jazzy/setup.bash
source install/setup.bash

ros2 topic info /control_command
```

节点正常运行时，`/control_command` 应至少有一个订阅者。

## `/control_command` 接口

消息类型：

```text
sdk_ros2/msg/ControlCommand
```

字段含义：

| 字段 | 含义 |
| --- | --- |
| `mode` | 控制模式 |
| `cmd_vel.linear.x` | 前后速度，正数前进 |
| `cmd_vel.linear.y` | 横向速度 |
| `cmd_vel.angular.z` | 转向角速度 |

支持的模式为 `passive`、`damp`、`recovery_stand`、`stand_down`、
`rl_walk` 和 `development`。速度只在 `rl_walk` 与 `development`
模式下生效。

### 站立

```bash
ros2 topic pub --once \
  /control_command \
  sdk_ros2/msg/ControlCommand \
  "{mode: recovery_stand, cmd_vel: {}}"
```

### 行走

下面的命令以 10 Hz 持续发送 0.1 m/s 的前进速度：

```bash
ros2 topic pub --rate 10 \
  /control_command \
  sdk_ros2/msg/ControlCommand \
  "{mode: rl_walk, cmd_vel: {linear: {x: 0.1, y: 0.0, z: 0.0}, angular: {z: 0.0}}}"
```

速度命令超过 0.5 秒没有更新时，节点会自动发送零速度。按 `Ctrl+C` 停止
持续发布后，机器人将停止移动，但仍保持 `rl_walk` 模式。

### 阻尼停止

```bash
ros2 topic pub --once \
  /control_command \
  sdk_ros2/msg/ControlCommand \
  "{mode: damp, cmd_vel: {}}"
```

## 常见问题

### `Unknown topic '/control_command'`

当前 ROS 图中还没有节点创建该话题。确认控制节点正在另一个终端运行，并确认
两个终端都已执行：

```bash
source /opt/ros/jazzy/setup.bash
source ~/yobotics_quad48/yobotics_sdk_ros2/install/setup.bash
```

### `Waiting for at least 1 matching subscription(s)...`

发布端没有发现控制节点。检查节点启动终端是否报错，并执行：

```bash
ros2 node list
ros2 topic info /control_command
```

### `ModuleNotFoundError: No module named 'em'`

Conda Python 覆盖了 ROS 使用的系统 Python。重新构建时保留：

```bash
--cmake-args -DPython3_EXECUTABLE=/usr/bin/python3
```

## 安全提示

首次运行模式或速度命令前，请将机器人放在安全支架上或确保周围区域空旷。
先用较小速度验证方向和通信，出现异常时立即发送 `damp`。
