# sdk_ros2

`sdk_ros2` 是独立的 Yobotics ROS 2 控制包。包内 `vendor/yobotics_sdk`
包含构建所需的最小 SDK 源码和 LCM 类型，不依赖外部
`libyobotics_sdk.a`。

## 依赖与构建

```bash
sudo apt install liblcm-dev libeigen3-dev

cd ~/yobotics_quad48/yobotics_sdk_ros2
source /opt/ros/jazzy/setup.bash
colcon build --packages-select sdk_ros2 \
  --cmake-args -DPython3_EXECUTABLE=/usr/bin/python3
source install/setup.bash
```

指定 `/usr/bin/python3` 可以避免 Conda 环境干扰 ROS 接口生成。使用其他
ROS 2 发行版时，请将 `jazzy` 替换为对应名称。

## 启动

```bash
cd ~/yobotics_quad48/yobotics_sdk_ros2
source /opt/ros/jazzy/setup.bash
source install/setup.bash
export YOBOTICS_LCM_URL='udpm://239.255.76.67:7667?ttl=255'
ros2 launch sdk_ros2 yobotics_sdk.launch.py
```

## `/control_command`

消息类型为 `sdk_ros2/msg/ControlCommand`。

| 字段 | 含义 |
| --- | --- |
| `mode` | 控制模式 |
| `cmd_vel.linear.x` | 前后速度，正数前进 |
| `cmd_vel.linear.y` | 横向速度 |
| `cmd_vel.angular.z` | 转向角速度 |

支持 `passive`、`damp`、`recovery_stand`、`stand_down`、
`rl_walk` 和 `development` 模式。速度仅在 `rl_walk` 和
`development` 模式下生效。

站立：

```bash
ros2 topic pub --once /control_command sdk_ros2/msg/ControlCommand \
  "{mode: recovery_stand, cmd_vel: {}}"
```

行走：

```bash
ros2 topic pub --rate 10 /control_command sdk_ros2/msg/ControlCommand \
  "{mode: rl_walk, cmd_vel: {linear: {x: 0.1, y: 0.0, z: 0.0}, angular: {z: 0.0}}}"
```

阻尼停止：

```bash
ros2 topic pub --once /control_command sdk_ros2/msg/ControlCommand \
  "{mode: damp, cmd_vel: {}}"
```

超过 0.5 秒没有收到新速度时，节点会自动发送零速度。

## 排错

- `Unknown topic '/control_command'`：确认节点已经启动，并在当前终端加载
  `/opt/ros/jazzy/setup.bash` 和工作空间的 `install/setup.bash`。
- `Waiting for at least 1 matching subscription(s)...`：发布端没有发现控制
  节点，检查节点启动终端中的日志。
- `ModuleNotFoundError: No module named 'em'`：构建时添加
  `--cmake-args -DPython3_EXECUTABLE=/usr/bin/python3`。

实体机器人测试前请使用安全支架或确保周围区域安全，并从较小速度开始。
