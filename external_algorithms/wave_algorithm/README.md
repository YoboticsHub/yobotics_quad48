<p align="center">
  🌎 English | <a href="./README.zh.md">🇨🇳 中文</a> | <a href="./README.ru.md">🇷🇺 Русский</a>
</p>

# wave_algorithm

This algorithm adjusts the thigh and calf joint positions of each quadruped leg to make the robot body move up and down.

Chinese source: [README.zh.md](./README.zh.md).

## Run

```bash
python3 external_algorithms/wave_algorithm/run_algorithm.py --config external_algorithms/wave_algorithm/config.yaml
```

## Design

- Inherits from `external_algorithms.algorithm_base.AlgorithmBase`.
- Generates a periodic waveform action directly in `_run_inference`.
- Maps the waveform to 12-dimensional joint target positions in `process_action`.
- Keeps `hip` joints at their default positions, while `thigh` / `calf` joints change body height.
