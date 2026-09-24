# Quad48 Quadruped Robot Control Framework User Manual

This manual guides users through installation, configuration, startup, debugging, and secondary development of the Quad48 quadruped robot control framework.

## Document Information

<table>
  <colgroup>
    <col style="width: 7em; min-width: 7em;" />
    <col />
  </colgroup>
  <thead>
    <tr><th>Item</th><th>Content</th></tr>
  </thead>
  <tbody>
    <tr><td>Document version</td><td>1.0</td></tr>
    <tr><td>Applicable software</td><td>Quad48 quadruped robot control framework</td></tr>
    <tr><td>Revision date</td><td>2026-09-04</td></tr>
    <tr><td>Applicable models</td><td>Quad48 control framework. Physical robot coverage includes <strong>E15</strong> (RK3588 / aarch64) and <strong>Y15</strong> (x86_64). Simulation and SDK workflows are shared. SPI, IMU, and binary-directory differences are described in 3.1 Hardware Deployment Principles and 3.2 Update config.yaml.</td></tr>
  </tbody>
</table>

## Recommended Reading Path

| User type | Recommended path | Goal |
| --- | --- | --- |
| First-time user | Part 1 -> Part 2 | Finish environment setup and run MuJoCo simulation |
| Field delivery engineer | Part 1 -> Part 2 -> Part 3 | Move from simulation verification to hardware deployment |
| SDK integrator | Part 1 -> Part 4 | Read state, send motion commands, or control through HTTP |
| ROS 2 integrator | Part 1 -> Part 4 -> Part 6 | Build the ROS 2 SDK and send motion commands through a standard topic |
| Algorithm developer | Part 2 -> Part 5 -> Part 3 | Verify a custom algorithm in simulation before hardware deployment |

## Operating Principles

- Simulate first, then run hardware: every new model, script, and parameter set must be verified in MuJoCo or on a safety stand before physical operation.
- Start from default configuration, then change gradually: do not change multiple communication, model, and safety parameters at once.
- Verify the algorithm before using the robot: confirm joint order, action amplitude, PD parameters, LCM channels, and logging output.
- Before hardware operation, confirm the emergency stop, power, ground environment, cables, IMU, and SPI device configuration.

## Common Entry Points

These are common commands only. Read the corresponding chapters before formal operation.

```bash
# Prepare Python / MuJoCo / LCM environment
bash scripts/setup_conda_env.sh

# Start MuJoCo simulation
bash scripts/start_mujoco.sh --config config_sim.yaml

# Start hardware controller
bash scripts/run_robot_controller.sh --config config.yaml

# Monitor LCM channels
bash scripts/monitor_lcm.sh --no-gui
```

Physical robot operation involves motion-safety risk. Do not repeatedly run an abnormal model, script, or configuration before the cause is understood.

## Robot Operation Video

Example with the E15 quadruped robot:

![type:video](videos/E15.mp4)
