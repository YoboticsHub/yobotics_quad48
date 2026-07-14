# 外部算法基元

本目录用于存放外部算法基元，每个算法一个文件夹，包含配置文件和Python执行脚本。

## 架构说明

本框架采用面向对象设计，提供了以下核心组件：

1. **`lcm_interface.py`**: LCM通信接口模块，封装了所有LCM相关的通信功能
2. **`algorithm_base.py`**: 算法基类，所有自定义算法都应该继承这个基类
3. **`example_algorithm/`**: 示例算法，展示如何使用基类
4. **`dance_algorithm/`**: 跳舞算法实现（基于deploy_mujoco_1Step.py）

## 目录结构

```
external_algorithms/
├── README.md                    # 本文件
├── example_algorithm/           # 示例算法
│   ├── config.yaml              # 算法配置文件
│   ├── run_algorithm.py         # 算法执行脚本
│   └── policy.onnx              # 策略文件（示例）
└── your_algorithm/              # 你的算法文件夹
    ├── config.yaml
    ├── run_algorithm.py
    └── policy.onnx (或 policy.pt)
```

## 快速开始

### 1. 创建新算法文件夹

```bash
cd external_algorithms
mkdir your_algorithm_name
cd your_algorithm_name
```

### 2. 复制配置文件模板

```bash
cp ../example_algorithm/config.yaml .
cp ../example_algorithm/run_algorithm.py .
```

### 3. 实现你的算法类

编辑 `run_algorithm.py`，继承 `AlgorithmBase` 并实现必要的方法：

```python
from algorithm_base import AlgorithmBase

class YourAlgorithm(AlgorithmBase):
    def compute_observation(self, state):
        """实现观测计算"""
        # 你的观测计算逻辑
        pass
    
    def process_action(self, state, action):
        """实现动作处理"""
        # 你的动作处理逻辑
        pass
```

### 4. 修改配置文件

编辑 `config.yaml`，配置你的策略路径、LCM通道、执行频率等参数。

### 5. 运行算法

```bash
python3 run_algorithm.py --config config.yaml
```

## 配置文件说明

### 策略配置

- `policy.type`: 策略类型，`"onnx"` 或 `"pt"` (PyTorch)
- `policy.path`: 策略文件路径（相对或绝对路径）
- `policy.read_metadata`: 是否从ONNX模型的metadata读取配置

### LCM配置

- `lcm.url`: LCM URL（空字符串表示使用默认）
- `lcm.state_channel`: 订阅的状态通道（开发模式状态）
- `lcm.command_channel`: 发布的命令通道（开发模式命令）
- `lcm.robot_id`: 机器人ID（必须与状态机配置一致）

### 执行配置

- `execution.frequency`: 执行频率（Hz），例如50表示50Hz
- `execution.auto_start`: 是否自动开始（收到状态消息后自动开始开发模式）
- `execution.auto_end`: 是否自动结束（算法执行完成后自动结束开发模式）
- `execution.max_execution_time`: 最大执行时间（秒），0表示无限制

### 强化学习模式配置

- `rl_mode.is_rl_mode`: 是否为强化学习模式
  - `True`: 状态机对踝关节进行扭矩计算，kp/kd清零
  - `False`: 直接使用外部传过来的kp/kd/期望角度/期望速度/期望扭矩

### 模型参数

如果 `read_metadata=false`，需要手动配置：
- `model_params.num_actions`: 动作维度（默认21）
- `model_params.num_obs`: 观测维度（默认114）
- `model_params.default_joint_pos`: 默认关节位置（21维）
- `model_params.joint_stiffness`: 关节刚度Kp（21维）
- `model_params.joint_damping`: 关节阻尼Kd（21维）
- `model_params.action_scale`: 动作缩放因子（21维）

## 算法基类使用

所有算法都应该继承 `AlgorithmBase` 类，该类提供了以下功能：

1. **自动加载策略**: 支持ONNX和PyTorch模型，自动从metadata读取配置
2. **LCM通信管理**: 自动处理LCM订阅和发布
3. **执行循环**: 自动管理执行频率和超时
4. **开发模式控制**: 自动处理开发模式的开始和结束

### 必须实现的方法

- `compute_observation(state)`: 根据状态计算观测向量
- `process_action(state, action)`: 处理动作并发送控制命令

### 可选重写的方法

- `on_development_mode_start()`: 开发模式开始时的回调
- `on_development_mode_end()`: 开发模式结束时的回调

### 示例代码

```python
from algorithm_base import AlgorithmBase

class YourAlgorithm(AlgorithmBase):
    def compute_observation(self, state):
        """计算观测"""
        obs = np.zeros(self.model_params['num_obs'], dtype=np.float32)
        # 你的观测计算逻辑
        return obs
    
    def process_action(self, state, action):
        """处理动作"""
        # 计算目标关节位置
        target_pos = action * self.model_params['action_scale'] + self.model_params['default_joint_pos']
        
        # 组织命令并发送
        joint_positions = {
            'L_Leg_q': target_pos[0:6].tolist(),
            # ...
        }
        self.lcm_interface.send_command(
            enable_development_mode=True,
            is_rl_mode=self.config['rl_mode']['is_rl_mode'],
            joint_positions=joint_positions,
            # ...
        )
```

## 关节顺序

标准关节顺序（21维）：
- 左腿（6维）: hip_pitch, hip_roll, hip_yaw, knee, ankle_pitch, ankle_roll
- 右腿（6维）: hip_pitch, hip_roll, hip_yaw, knee, ankle_pitch, ankle_roll
- 腰部（1维）: waist
- 左臂（4维）: shoulder_pitch, shoulder_roll, shoulder_yaw, elbow
- 右臂（4维）: shoulder_pitch, shoulder_roll, shoulder_yaw, elbow

如果你的模型使用不同的关节顺序，需要在 `_compute_observation` 和 `_send_command` 中进行映射。

## 依赖要求

- Python 3.6+
- numpy
- pyyaml
- lcm (Python bindings)
- onnxruntime (如果使用ONNX模型)
- torch (如果使用PyTorch模型)
- onnx (如果从metadata读取配置)

## 注意事项

1. **机器人ID匹配**: 确保配置文件中的 `robot_id` 与状态机配置一致
2. **LCM通道**: 确保状态通道和命令通道与状态机配置一致
3. **关节顺序**: 确保模型输出的关节顺序与机器人关节顺序匹配
4. **执行频率**: 建议设置为50Hz（20ms周期），与状态机控制频率一致
5. **安全**: 算法执行前确保机器人处于安全状态，建议先进行仿真测试

## 示例算法

### example_algorithm

基础的示例算法，展示如何使用算法基类实现简单的控制算法。

### dance_algorithm

跳舞算法实现，基于 `whole_body_Deploy/deploy_mujoco_1Step.py`，支持：
- 从数据集加载动作序列
- 使用ONNX模型进行动作生成
- 支持循环播放
- 完整的观测计算（包括anchor orientation等）

使用方法：
```bash
cd dance_algorithm
python3 run_algorithm.py --config config.yaml
```

## LCM接口使用

如果需要直接使用LCM接口（不继承基类），可以这样使用：

```python
from lcm_interface import LCMInterface

lcm = LCMInterface(config)
lcm.register_state_callback(your_callback_function)
lcm.send_command(enable=True, is_rl_mode=True, joint_positions={...})
```

