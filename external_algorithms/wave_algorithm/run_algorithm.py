#!/usr/bin/env python3
"""
躯干上下波动算法实现
通过调整四足机器人每条腿的 thigh/calf 关节位置，实现躯干的上下波动。
"""

import sys
import os
import numpy as np
import time

# 添加父目录到路径
_parent_dir = os.path.join(os.path.dirname(__file__), '..')
if _parent_dir not in sys.path:
    sys.path.insert(0, _parent_dir)

from algorithm_base import AlgorithmBase


class RunAlgorithm(AlgorithmBase):
    """Wave motion algorithm class"""

    def __init__(self, config_path):
        # 先加载配置，基类会在 __init__ 中调用 _load_policy 和 _warmup_policy
        super().__init__(config_path)

        self.execution_complete = False
        self.start_time = time.time()
        self.step_count = 0

    def _load_policy(self):
        """Override base policy loading for direct control algorithm."""
        print(f"[{self.__class__.__name__}] policy.type='none'，直接使用自定义波形控制，无需加载 ONNX 模型")
        self.policy = None
        self.policy_type = 'none'

    def compute_observation(self, state):
        """
        计算当前观测。
        本算法不依赖 ONNX 模型，因此仅构造一个稳定的状态向量供调试使用。
        """
        obs = np.zeros(self.model_params['num_obs'], dtype=np.float32)

        # joint_q / joint_qd
        try:
            obs[0:12] = np.array(state.joint_q, dtype=np.float32)
            obs[12:24] = np.array(state.joint_qd, dtype=np.float32)
            # print("state.joint_q:", state.joint_q[:6])
        except Exception:
            pass

        # 期望速度和角速度
        try:
            obs[24:27] = np.array([state.v_des[0], state.v_des[1], state.v_des[2]], dtype=np.float32)
            obs[27:30] = np.array([state.omega_des[0], state.omega_des[1], state.omega_des[2]], dtype=np.float32)
        except Exception:
            pass

        # 姿态信息
        try:
            obs[30:34] = np.array([state.quat[0], state.quat[1], state.quat[2], state.quat[3]], dtype=np.float32)
        except Exception:
            pass

        # 剩余填充为 0
        return obs

    def _run_inference(self, obs):
        """直接计算动作，而不依赖外部模型。"""
        self.step_count += 1
        elapsed = time.time() - self.start_time
        motion_cfg = self.config.get('motion', {})
        frequency = float(motion_cfg.get('frequency', 1.0))
        amplitude = float(motion_cfg.get('amplitude', 0.35))
        phase = 2.0 * np.pi * frequency * elapsed

        # 生成上下波形：sin波控制 thigh/calf 偏移
        thigh_offset = amplitude * np.sin(phase)
        calf_offset =  - amplitude * np.sin(phase)

        action = np.zeros(self.model_params['num_actions'], dtype=np.float32)
        # 目标命令只作用于 thigh/calf 关节，hip 关节保持默认位置
        for leg_id in range(4):
            hip_idx = leg_id * 3 + 0
            thigh_idx = leg_id * 3 + 1
            calf_idx = leg_id * 3 + 2
            action[hip_idx] = 0.0
            action[thigh_idx] = thigh_offset
            action[calf_idx] = calf_offset

        return action

    def process_action(self, state, action):
        """
        将计算得到的 action 转换为关节位置命令并发送。
        """
        if self.execution_complete:
            return

        if action is None or len(action) != 12:
            print(f"[{self.__class__.__name__}] WARNING: invalid action length {None if action is None else len(action)}")
            return

        default_pos = self.model_params.get('default_joint_pos', np.zeros(12, dtype=np.float32))
        if isinstance(default_pos, list):
            default_pos = np.array(default_pos, dtype=np.float32)

        joint_positions = default_pos + action
        
        print("des: joint_positions:", joint_positions[:6])
        joint_velocities = np.zeros(12, dtype=np.float32)
        joint_torques = np.zeros(12, dtype=np.float32)

        # joint_kp = self.model_params.get('joint_stiffness', np.array([200.0] * 12, dtype=np.float32))
        # joint_kd = self.model_params.get('joint_damping', np.array([2.0] * 12, dtype=np.float32))

        joint_kp = np.array([30.0] * 12, dtype=np.float32)
        joint_kd = np.array([0.5] * 12, dtype=np.float32)

        if isinstance(joint_kp, list):
            joint_kp = np.array(joint_kp, dtype=np.float32)
        if isinstance(joint_kd, list):
            joint_kd = np.array(joint_kd, dtype=np.float32)

        with self.latest_command_lock:
            self.latest_command = {
                'enable_development_mode': True,
                'joint_positions': joint_positions.tolist(),
                'joint_velocities': joint_velocities.tolist(),
                'joint_torques': joint_torques.tolist(),
                'joint_kp': joint_kp.tolist(),
                'joint_kd': joint_kd.tolist()
            }

    def on_development_mode_start(self):
        self.start_time = time.time()
        self.step_count = 0
        print(f"[{self.__class__.__name__}] Development mode started: wave motion active")

    def on_development_mode_end(self):
        print(f"[{self.__class__.__name__}] Development mode ended: stopping wave motion")
        with self.latest_command_lock:
            self.latest_command = {
                'enable_development_mode': False,
            }


def main():
    import argparse
    import os

    parser = argparse.ArgumentParser(description='Wave Algorithm Runner')
    parser.add_argument('--config', type=str, default='config.yaml',
                        help='Path to configuration file (default: config.yaml)')
    args = parser.parse_args()

    config_path = args.config
    if not os.path.isabs(config_path):
        script_dir = os.path.dirname(os.path.abspath(__file__))
        potential_path = os.path.join(script_dir, config_path)
        if os.path.exists(potential_path):
            config_path = potential_path
        else:
            config_path = os.path.abspath(config_path)

    print(f"[{RunAlgorithm.__name__}] Using config file: {config_path}")

    try:
        algorithm = RunAlgorithm(config_path)
        algorithm.run()
    except Exception as e:
        print(f"Error: {e}")
        import traceback
        traceback.print_exc()
        sys.exit(1)


if __name__ == '__main__':
    main()
