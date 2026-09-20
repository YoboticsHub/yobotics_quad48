# E15 SDK User Guide

The original Chinese SDK guide is preserved next to this file.

## 1. Runtime Prerequisites

- The control framework must use **LCM control mode**; otherwise the SDK cannot establish communication.
- Current integration target: `quad48-rl-control-framework-rk3588`.

## 2. Communication Channels

- Control command: `QUAD_ROBOT_CONTROL` (`sport_client_cmd_t`)
- State feedback: `QUAD_ROBOT_STATE` (`sport_client_state_t`)
- Joint state: `leg_control_data` (`quad_joint_state_t`)
- Joint command mirror: `leg_control_command` (`quad_joint_command_t`)
- Development-mode command: `Y15_development_command`
- Development-mode state: `Y15_development_state`

## 3. API Numbers

- `1000`: PASSIVE
- `1001`: DAMP
- `1002`: RL_WALK
- `1003`: RL_RUN
- `1005`: DEVELOPMENT
- `1006`: RECOVERY_STAND
- `1007`: STAND_DOWN

## 4. SDK Package Contents

- `include/`: header files
- `lib/libyobotics_sdk.a`: static library
- `example/E15/E15_sport_client.cpp`: keyboard-control example
- `example/E15/E15_robot_state_client.cpp`: state-reading example

## 5. Build and Run

```bash
mkdir -p build && cd build
cmake ..
make -j4
```

Optional environment variable:

- `YOBOTICS_LCM_URL`: LCM URL, for example `udpm://239.255.76.67:7667?ttl=255`.

Example commands:

```bash
./E15_sport_client
./E15_robot_state_client
```

## 6. Control Fields

- `Move(vx, vy, vyaw)`: sets velocity commands.
- `BodyHeight(h)`: sets body-height command, mapped to `v_des[2]`.
- `Euler(roll, pitch)`: sets attitude commands, mapped to `omega_des[0/1]`.
- These fields are consumed only in `RL_WALK`, `RL_RUN`, and `DEVELOPMENT` modes.

## 7. Multi-Machine Deployment and Control Switching

- If the SDK and robot side run on different computers, both sides must use the same LCM multicast URL and the network must allow UDP multicast.
- Whether LCM control is enabled on the robot side is still determined by the local control-framework configuration.

## 8. Ubuntu 16/20/22/24 Compatibility

- The SDK follows `C++11` constraints and is compatible with common Ubuntu 16/20/22/24 build environments.
- If a prebuilt `libyobotics_sdk.a` is copied from another system, rebuild it on the target Ubuntu system before linking.
