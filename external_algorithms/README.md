# external_algorithms

本目录提供 `DEVELOPMENT` 模式下的外部算法接入框架，用于通过 LCM 从主控制器接收状态、运行外部策略，并回传关节命令。当前实际组成如下：

- `algorithm_base.py`：算法基类，负责配置加载、策略加载、warmup、执行循环和开发模式启停
- `lcm_interface.py`：LCM 收发封装
- `walk_algorithm/`：当前唯一已落地的示例算法目录

扩展新算法时请以现有 `walk_algorithm/` 为起点。

## 接入机制

外部算法的典型运行流程如下：

1. 订阅 `development_state_t`
2. 根据状态构造观测
3. 调用 ONNX 策略推理
4. 缓存目标关节命令
5. 以高频发送 `development_command_t`

执行频率由配置区分为两层：

- `execution.frequency`：策略推理频率
- `execution.lcm_send_frequency`：LCM 命令发送频率

当前基类的设计是“低频推理 + 高频发送缓存命令”。`walk_algorithm/config.yaml` 默认是 `50Hz` 推理、`500Hz` 发送。

## AlgorithmBase 能力

`AlgorithmBase` 已经封装了大部分公共逻辑：

- 自动加载 YAML 配置
- 自动加载 ONNX 策略
- 可选从 ONNX metadata 读取模型参数
- 启动前可执行 warmup
- 自动监听开发模式状态并在需要时启停
- 维护观测历史
- 假定模型为双输入：
  - 当前观测
  - 历史观测展平向量

子类必须实现：

- `compute_observation(state)`
- `process_action(state, action)`

子类可选重写：

- `on_development_mode_start()`
- `on_development_mode_end()`

推荐的扩展方式不是重写整套执行循环，而是只补齐观测构造和动作处理逻辑，把公共通信和调度继续交给基类。

## LCM 消息与关节顺序

当前开发模式依赖两个核心消息类型。

### `development_state_t`

状态字段包括：

- `robot_id`
- `joint_q`
- `joint_qd`
- `joint_tau`
- `quat`
- `rpy`
- `omega`
- `acc`
- `v_des`
- `omega_des`
- `mode`

### `development_command_t`

命令消息发送以下 12 维数组：

- `joint_des_q`
- `joint_des_qd`
- `joint_des_tau`
- `joint_des_kp`
- `joint_des_kd`

关节顺序按消息注释约定为：

- `LF -> RF -> LR -> RR`
- 每条腿内部顺序为 `hip -> thigh -> calf`

如果你的模型输出顺序与该顺序不同，需要在子类的 `compute_observation` 或 `process_action` 中自行做映射，不要假设基类会自动转换。

## 新算法模板

推荐直接复制现有 `walk_algorithm/` 目录作为新算法起点，再针对你的模型修改以下内容：

- `policy.path`
- `model_params`
- `lcm.*`
- `compute_observation`
- `process_action`

一个最小流程通常是：

1. 新建算法目录
2. 拷贝 `walk_algorithm/run_algorithm.py`
3. 拷贝 `walk_algorithm/config.yaml`
4. 替换你的模型文件
5. 修改观测和动作映射逻辑
6. 校对 `robot_id`、状态通道、命令通道

运行入口仍然建议保留为：

```bash
python3 your_algorithm/run_algorithm.py --config your_algorithm/config.yaml
```

## 当前示例：walk_algorithm

当前示例具备这些特征：

- 12 维动作
- 45 维观测
- ONNX 策略推理
- `50Hz` 推理
- `500Hz` LCM 发送

对应运行命令：

```bash
python3 external_algorithms/walk_algorithm/run_algorithm.py --config external_algorithms/walk_algorithm/config.yaml
```

运行前请确保：

- 主控制器已经进入 `DEVELOPMENT` 模式
- `lcm.robot_id` 与主控制器 `development.robot_id` 一致
- `lcm.state_channel` 与 `lcm.command_channel` 与主控制器配置一致

## 依赖

当前实际需要的 Python 依赖包括：

- `numpy`
- `pyyaml`
- `onnxruntime`
- `onnx`
- `python-lcm`

如果使用仓库提供的环境脚本，可先执行顶层的：

```bash
./scripts/setup_conda_env.sh
```

## 已知边界

- 当前基础框架默认面向 12 自由度四足控制
- 代码中虽然保留了 PyTorch 可用性探测，但由于实物部署受限，当前只走 ONNX 推理路径，并不将 `.pt` 视为正式支持能力
- `AlgorithmBase` 当前对模型输入形状有实现假定：模型应提供“当前观测 + 历史观测”两个输入
- 历史观测长度、单帧观测维度与模型输入必须一致；新增模型时需要主动核对，而不是只改 `num_obs`
