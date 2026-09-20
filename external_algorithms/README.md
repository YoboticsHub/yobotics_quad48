# External Algorithm Development Demos

This directory contains external algorithm demos that connect to robot development mode through LCM. Each demo lives in its own subdirectory and usually contains `config.yaml` and `run_algorithm.py`. The demos use `AlgorithmBase` and `LCMInterface` to receive state, run policy inference or rule-based computation, and publish joint commands.

Chinese source: [README.zh.md](./README.zh.md).

Current demos are grouped into two styles:

- **DRL-based demos**: load an ONNX policy model and generate 12-dimensional joint actions from robot state and action history.
- **Model-based demos**: do not depend on DRL policy files; they use explicit control models, motion rules, or analytic functions to generate joint targets.

## Directory Structure

```text
external_algorithms/
├── README.md
├── algorithm_base.py
├── lcm_interface.py
├── walk_algorithm/
│   ├── config.yaml
│   ├── run_algorithm.py
│   └── quadTSnet.onnx
└── wave_algorithm/
    ├── README.md
    ├── config.yaml
    └── run_algorithm.py
```

## Architecture

- `algorithm_base.py`: base class for configuration loading, policy loading, development-mode lifecycle, inference loop, and high-frequency LCM command sending.
- `lcm_interface.py`: LCM wrapper that subscribes to `development_state_t` and publishes `development_command_t`.
- `walk_algorithm/`: DRL locomotion demo based on an ONNX policy model.
- `wave_algorithm/`: explicit sine-wave model/rule-control demo.

## Demo Overview

| Demo | Directory | Development style | Main dependencies | Robot / LCM channels |
| --- | --- | --- | --- | --- |
| Walking/running policy demo | `walk_algorithm/` | DRL-based | `onnxruntime`, `numpy`, `LCM` | `Y15`, `Y15_development_state`, `Y15_development_command` |
| Body-wave demo | `wave_algorithm/` | Model-based | `numpy`, `LCM` | `Y15`, `Y15_development_state`, `Y15_development_command` |

## `walk_algorithm/`

`walk_algorithm` is a single-ONNX-policy demo. It uses `policy.type: "onnx"`, and the policy file is `quadTSnet.onnx`.

Main flow:

1. Subscribe to robot development-mode state through LCM.
2. Build observations from body angular velocity, gravity projection, desired velocity, joint position, joint velocity, and previous action.
3. Run the ONNX policy model to produce a 12-dimensional action.
4. Convert the action to 12-dimensional joint targets using `action_scale` and `default_joint_pos`.
5. Generate PD commands from `joint_stiffness` / `joint_damping` and publish them through LCM.

## `wave_algorithm/`

`wave_algorithm` is an explicit rule-control demo. It uses `policy.type: "none"` and does not load ONNX or PyTorch policy models.

Main flow:

1. Override `_load_policy()` and skip policy loading.
2. Generate sinusoidal actions from runtime in `_run_inference()`.
3. Keep hip joints at default positions and offset thigh/calf joints with a sine wave.
4. Generate joint target positions, velocities, torques, Kp, and Kd in `process_action()`.
5. Publish development-mode commands through LCM so the robot body moves up and down.

## Run

From the project root:

```bash
python3 external_algorithms/walk_algorithm/run_algorithm.py --config external_algorithms/walk_algorithm/config.yaml
python3 external_algorithms/wave_algorithm/run_algorithm.py --config external_algorithms/wave_algorithm/config.yaml
```

Or enter a demo directory first:

```bash
cd external_algorithms/walk_algorithm
python3 run_algorithm.py --config config.yaml

cd external_algorithms/wave_algorithm
python3 run_algorithm.py --config config.yaml
```

## Configuration

### `policy`

- `type`: policy type. DRL demos use `"onnx"`; rule-control demos can use `"none"`.
- `path`: ONNX policy path. Relative paths are resolved from the demo directory.
- `read_metadata`: whether to read model parameters from ONNX metadata.
- `warmup_count`: number of policy warmup runs.
- `action_threshold`: abnormal-action threshold.

### `model_params`

- `num_actions`: action dimension; current quadruped demos use 12.
- `num_obs`: observation dimension.
- `default_joint_pos`: default joint positions.
- `joint_stiffness`: joint Kp.
- `joint_damping`: joint Kd.
- `action_scale`: policy action scaling.

### `lcm`

- `url`: LCM URL; empty string uses the default configuration.
- `state_channel`: subscribed development-mode state channel.
- `command_channel`: published development-mode command channel.
- `robot_id`: robot ID; must match FSM configuration.

### `execution`

- `frequency`: policy inference or rule-computation frequency.
- `lcm_send_frequency`: cached-command LCM sending frequency, capped at 200 Hz.
- `auto_start`: whether to enter development mode automatically after receiving state.
- `auto_end`: whether to exit development mode automatically when the algorithm stops.
- `max_execution_time`: maximum execution time; `0` means unlimited.

### `rl_mode`

- `true`: DRL policy demo.
- `false`: explicit model/rule-control demo.

### `debug`

- `print_config`: print the configuration on startup.
- `print_metadata`: print ONNX metadata during loading.

## Extending the Package

### Add a DRL-Based Demo

1. Create a directory such as `your_drl_algorithm/`.
2. Prepare `config.yaml` with ONNX policy path, LCM channels, execution frequency, and model parameters.
3. In `run_algorithm.py`, inherit from `AlgorithmBase`.
4. Implement `compute_observation(state)`.
5. Implement `process_action(state, action)`.
6. Override `_run_inference()` or `_load_policy()` if the model has a special input/output structure.

### Add a Model-Based Demo

1. Set `policy.type: "none"`.
2. Override `_load_policy()` and set `self.policy` to `None`.
3. Generate actions in `_run_inference()` from time, state, trajectory planning, or a control model.
4. Convert actions to development-mode commands in `process_action()`.
5. Set `rl_mode.is_rl_mode` according to FSM expectations, usually `false`.

## Dependencies

- Python 3.6+
- `numpy`
- `pyyaml`
- `lcm` Python bindings
- `onnxruntime` for DRL ONNX policies
- `onnx` when reading parameters from ONNX metadata

## Safety Notes

- Confirm that `robot_id`, `state_channel`, and `command_channel` exactly match the FSM configuration.
- Verify action amplitude, joint order, and PD parameters in simulation or on a safety stand before hardware.
- Check DRL output for NaN, Inf, and abnormally large actions before publishing commands.
- After replacing a policy model, confirm `num_actions`, `num_obs`, `default_joint_pos`, and `action_scale` against the training configuration.
- Publish a disable command when development mode ends to avoid stale commands.
