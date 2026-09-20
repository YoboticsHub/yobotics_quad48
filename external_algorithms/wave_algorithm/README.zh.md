# wave_algorithm

本算法通过调整四足机器人每条腿的 thigh 和 calf 关节位置，使机器人躯干产生上下波动。

## 运行方式

```bash
python3 external_algorithms/wave_algorithm/run_algorithm.py --config external_algorithms/wave_algorithm/config.yaml
```

## 设计思路

- 继承 `external_algorithms.algorithm_base.AlgorithmBase`
- 直接在 `_run_inference` 中生成周期性波形动作
- 在 `process_action` 中把波形映射到 12 维关节目标位置
- `hip` 关节保持默认位置，`thigh` / `calf` 负责躯干高度变化
