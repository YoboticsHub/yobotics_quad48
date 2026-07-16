# Quad48 二次开发包脚本说明

本目录是独立二次开发包中的 `scripts/` 目录说明。这里的脚本面向“已经打包好的
`yobotics_quad48` 开发目录”，主要用于运行控制器、启动仿真、配置 LCM 网络、监控
LCM 消息、准备 Python 环境，以及查看运行日志。


## 使用前准备

建议在开发包根目录下执行命令，例如：

```bash
cd yobotics_quad48
```

开发包常见目录如下：

```text
yobotics_quad48/
├── bin/                  # 控制器可执行文件，例如 ybt_ctrl
├── lib/                  # 运行所需动态库
├── log/                  # 运行日志、CSV 日志输出目录
├── lcm-types/            # LCM 类型定义和生成结果
├── mujoco_sim/           # MuJoCo 仿真相关代码
├── resources/            # 机器人模型、资源文件
├── scripts/              # 本说明文档描述的脚本
├── config.yaml           # 控制器配置
└── config_sim.yaml       # 仿真配置
```

推荐先确认脚本权限。如果脚本不可执行，可以运行：

```bash
chmod +x scripts/*.sh
```

## 推荐工作流

### 1. 准备 Python 环境

如果是第一次在当前机器上使用仿真、LCM 监控或日志查看工具，建议先准备 Python 环境：

```bash
bash scripts/setup_conda_env.sh
```

如果只需要修复或安装 Python LCM 绑定，可以运行：

```bash
bash scripts/install_python_lcm.sh
```

### 2. 配置 LCM 网络

如果 LCM 消息收不到、监控工具没有数据，或多机通信异常，先配置网络：

```bash
sudo bash scripts/setup_lcm_network.sh
```

该脚本通常需要 `sudo`，因为它会修改网卡、多播路由等网络配置。

### 3. 生成 LCM 类型

如果修改过 `lcm-types/` 中的 `.lcm` 文件，或者 Python/C++ 类型文件缺失，可以重新生成：

```bash
bash scripts/generate_lcm_types.sh
```

### 4. 启动仿真和控制器

常用方式是先启动 MuJoCo 仿真，再启动控制器：

```bash
bash scripts/start_mujoco.sh --config config_sim.yaml
bash scripts/run_robot_controller.sh
```

如果只想后台或无界面运行仿真，可以使用：

```bash
bash scripts/start_mujoco.sh --headless
```

### 5. 监控和分析数据

监控 LCM：

```bash
bash scripts/monitor_lcm.sh
bash scripts/monitor_lcm.sh --no-gui
```

查看 CSV 日志：

```bash
python3 scripts/data_viewer.py
python3 scripts/motor_trace_viewer.py log/motor_trace.csv
```

## 运行类脚本

### `run_robot_controller.sh`

用于启动开发包内的控制器程序。脚本会设置运行所需的动态库路径，避免控制器找不到
`lib/` 目录下的 `.so` 文件。

常用命令：

```bash
bash scripts/run_robot_controller.sh
```

适用场景：

- 在实物环境中启动控制器。
- 验证打包后的 `bin/ybt_ctrl` 是否可以独立运行。
- 调试 `config.yaml` 中的控制器参数。

注意事项：

- 建议从开发包根目录运行。
- 如果提示动态库缺失，先确认 `lib/` 目录完整。
- 如果控制器启动后没有机器人状态，通常需要同时检查仿真进程和 LCM 网络。

### `start_mujoco.sh`

用于启动 MuJoCo 仿真环境。默认读取开发包内的仿真配置，也可以通过参数指定配置文件。

常用命令：

```bash
bash scripts/start_mujoco.sh
bash scripts/start_mujoco.sh --config config_sim.yaml
bash scripts/start_mujoco.sh --headless
```

适用场景：

- 本机仿真调试控制器。
- 验证模型、配置和资源文件是否完整。

注意事项：

- 如果启动失败，先检查 `resources/`、`mujoco_sim/` 和 `config_sim.yaml` 是否存在。
- 如果图形界面无法打开，确认当前环境是否支持显示。
- 如果控制器与仿真没有通信，优先检查 LCM URL、网卡和多播配置。

## LCM 相关脚本

### `generate_lcm_types.sh`

用于根据 `lcm-types/` 下的 `.lcm` 文件生成 C++ 和 Python 类型文件。

常用命令：

```bash
bash scripts/generate_lcm_types.sh
```

适用场景：

- 新增或修改 LCM 消息定义后，重新生成类型文件。
- Python 监控工具提示找不到某些 LCM 类型。
- C++ 或 Python 通信结构体与 `.lcm` 文件不一致。

注意事项：

- 生成前需要系统中安装 `lcm-gen`。
- 修改 `.lcm` 文件后，通信两端应使用同一版本的类型定义。

### `monitor_lcm.sh`

LCM 监控启动脚本。它会做一些运行前检查，然后调用 `monitor_lcm.py`。

常用命令：

```bash
bash scripts/monitor_lcm.sh
bash scripts/monitor_lcm.sh --no-gui
bash scripts/monitor_lcm.sh --lcm-url "udpm://239.255.76.67:7667?ttl=1"
```

适用场景：

- 查看控制器、仿真或外部算法发布的 LCM 消息。
- 排查 LCM 无数据、消息频率异常、字段值异常等问题。
- 在无 GUI 环境下用文本模式确认通信是否正常。

注意事项：

- GUI 模式通常依赖 Python 图形库和显示环境。
- 如果没有数据，先尝试 `--no-gui`，再检查网络和 LCM URL。
- 如果提示 Python LCM 缺失，运行 `install_python_lcm.sh`。

### `monitor_lcm.py`

Python 版 LCM 监控程序，可以直接运行，也可以由 `monitor_lcm.sh` 调用。

常用命令：

```bash
python3 scripts/monitor_lcm.py
python3 scripts/monitor_lcm.py --no-gui
python3 scripts/monitor_lcm.py --lcm-url "udpm://239.255.76.67:7667?ttl=1"
```

适用场景：

- 需要直接调试 Python 监控程序。
- 已经确认依赖齐全，不需要 shell 脚本做前置检查。
- 在开发过程中修改或扩展监控逻辑。

### `launch_lcm_spy.sh`

用于启动系统中的 `lcm-spy` 工具。

常用命令：

```bash
bash scripts/launch_lcm_spy.sh
```

适用场景：

- 使用 LCM 官方工具快速查看当前网络上的频道。
- 对比自带监控工具和 `lcm-spy` 的接收结果。

注意事项：

- 需要系统中已经安装 `lcm-spy`。
- 如果命令不存在，请先安装 LCM 工具链。

### `setup_lcm_network.sh`

用于配置 LCM 多播网络，通常会设置网卡、多播路由或相关网络参数。

常用命令：

```bash
sudo bash scripts/setup_lcm_network.sh
```

适用场景：

- LCM 监控收不到数据。
- 控制器和仿真在不同进程或不同机器上通信异常。
- 多网卡机器上 LCM 走错网卡。

注意事项：

- 该脚本通常需要管理员权限。
- 执行前建议确认当前机器的目标网卡。
- 修改网络配置可能影响当前终端的网络连接，远程机器上使用时要格外小心。

### `show_network_bandwidth.sh`

用于实时查看指定网卡的接收、发送和总网络带宽占用情况。

常用命令：

```bash
bash scripts/show_network_bandwidth.sh
bash scripts/show_network_bandwidth.sh eth0 1
```

参数说明：

- 第 1 个参数：网卡名称，例如 `eth0`、`enp3s0`、`wlan0`。不传时脚本会尝试使用默认路由网卡。
- 第 2 个参数：刷新间隔，单位为秒，默认是 `1`。

适用场景：

- 排查 LCM 消息量过大导致的网络占用问题。
- 检查控制器、仿真、WebRTC 或外部算法运行时的网络流量。
- 多机调试时确认目标网卡是否真的有数据收发。

注意事项：

- 脚本会读取 `/sys/class/net/<网卡>/statistics/` 下的收发字节数。
- 如果系统安装了 `ethtool`，脚本会尝试读取网卡最大速率并显示占用率。
- 如果提示网卡不存在，先用 `ip link` 查看当前机器的网卡名称。

## Python 环境脚本

### `setup_conda_env.sh`

用于创建或配置开发包所需的 Conda/Python 环境。

常用命令：

```bash
bash scripts/setup_conda_env.sh
```

适用场景：

- 第一次使用仿真、监控或可视化工具。
- Python 依赖缺失，例如 matplotlib、numpy、lcm 等。
- 希望使用统一环境运行开发包内的 Python 工具。

注意事项：

- 需要本机已经安装 Conda 或 Miniconda。
- 如果系统没有 Conda，可手动安装依赖，或根据脚本内容迁移到已有 Python 环境。

### `install_python_lcm.sh`

用于安装或修复 Python LCM 绑定。

常用命令：

```bash
bash scripts/install_python_lcm.sh
```

适用场景：

- `monitor_lcm.py` 提示 `import lcm` 失败。
- Python 环境已存在，但缺少 LCM Python 包。
- 更新系统 LCM 后需要重新安装 Python 绑定。

### `remove_conda_env.sh`

用于删除脚本创建的 Conda 环境。

常用命令：

```bash
bash scripts/remove_conda_env.sh
```

适用场景：

- 需要清理开发环境。
- 环境依赖混乱，准备重新创建。
- 切换到其他 Python 环境管理方式。

注意事项：

- 删除前确认环境中没有需要保留的个人文件。
- 删除后如果还要使用 Python 工具，需要重新运行 `setup_conda_env.sh` 或手动准备依赖。

## 数据查看脚本

### `data_viewer.py`

用于查看控制器输出的普通 CSV 日志，例如强化学习运行日志。

常用命令：

```bash
python3 scripts/data_viewer.py
python3 scripts/data_viewer.py log/log_RL_data.csv
```

适用场景：

- 查看控制器运行过程中记录的 CSV 曲线。
- 对比不同运行阶段的数据变化。
- 快速定位状态量、控制量或观测量异常。

注意事项：

- 如果不指定文件，脚本会尝试从默认日志路径查找 CSV。
- 如果 GUI 无法打开，检查 Python 图形库和显示环境。
- 如果 CSV 字段不符合预期，确认日志文件是否由当前版本控制器生成。

### `motor_trace_viewer.py`

用于查看电机跟踪日志，通常面向 `motor_trace.csv` 这类文件，展示关节期望位置、实际位置、
期望力矩、实际力矩等曲线。

常用命令：

```bash
python3 scripts/motor_trace_viewer.py
python3 scripts/motor_trace_viewer.py log/motor_trace.csv
```

适用场景：

- 分析单个关节的跟踪效果。
- 对比期望值和实际值之间的偏差。
- 排查抖动、延迟、力矩异常或某条腿动作不一致的问题。

注意事项：

- 需要先在配置中打开电机跟踪日志输出。
- 日志文件较大时，打开和绘图可能需要一些时间。
- 如果字段缺失，确认控制器版本和日志格式是否匹配。


## 常见问题

### 控制器提示找不到动态库

先确认是否在开发包根目录执行命令，并确认 `lib/` 目录存在。建议使用：

```bash
bash scripts/run_robot_controller.sh
```

不要直接运行 `bin/ybt_ctrl`，否则可能没有正确设置动态库路径。

### LCM 监控没有任何消息

建议按顺序检查：

```bash
sudo bash scripts/setup_lcm_network.sh
bash scripts/monitor_lcm.sh --no-gui
```

同时确认控制器或仿真进程已经启动，并且它们使用的是同一个 LCM URL。

### Python 脚本提示缺少 lcm、numpy 或 matplotlib

先准备 Python 环境：

```bash
bash scripts/setup_conda_env.sh
```

如果只缺少 LCM 绑定：

```bash
bash scripts/install_python_lcm.sh
```

### 图形界面打不开

可能原因包括：

- 当前机器没有显示环境。
- SSH 没有开启 X11 转发。
- Python 图形库未安装完整。
- 正在无头服务器或机器人主机上运行。

可以优先使用文本模式：

```bash
bash scripts/monitor_lcm.sh --no-gui
bash scripts/start_mujoco.sh --headless
```

### 修改 `.lcm` 文件后 Python 工具报字段错误

重新生成 LCM 类型：

```bash
bash scripts/generate_lcm_types.sh
```

并确认通信两端使用同一份 `.lcm` 定义。
