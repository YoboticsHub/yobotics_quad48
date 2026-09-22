<p align="center">
  🌎 English | <a href="./README.zh.md">🇨🇳 中文</a> | <a href="./README.ru.md">🇷🇺 Русский</a>
</p>

# yobotics_sdk_e15_260408_lib_generate

This project contains the E15 SDK, example programs, and an HTTP example service for motion control and navigation control.

Chinese source: [README.zh.md](./README.zh.md). A short SDK integration guide is available at [SDK_User_Guide.md](./SDK_User_Guide.md).

## Directory Overview

- `include/`: SDK headers
- `lib/libyobotics_sdk.a`: static library
- `example/http_server.cpp`: E15 HTTP control-service example
- `example/sport_client.cpp`: motion-control example
- `example/robot_state_client.cpp`: state-subscription example
- `dist/`: package output directory
- `tools/`: build and deployment scripts

## Build Examples

```bash
mkdir -p build && cd build
cmake ..
make -j4
```

Default example executables:

- `yobot_sport_client`
- `yobot_robot_state_client`
- `yobot_http_server`

## Install the SDK

```bash
mkdir -p build && cd build
cmake .. -DCMAKE_INSTALL_PREFIX=/opt/yobotics_sdk_e15_260408
make -j4
sudo make install
```

## Link the Static Library Directly

```bash
g++ -std=c++11 your_app.cpp \
  -I./include -I./include/common -I./include/robot -I./include/robot/channel \
  ./lib/libyobotics_sdk.a -llcm -lpthread -o your_app
```

## HTTP Control Service

Default configuration:

- Service address: `http://192.168.1.100:8080`
- Default token: `E15_Robot_Secure_Token_123`
- Request header: `Authorization: Bearer <token>`

Environment variables:

- `SERVER_HOST`
- `SERVER_PORT`
- `ROBOT_HTTP_TOKEN`
- `YOBOTICS_LCM_URL`

### Common Request Header

```bash
-H "Authorization: Bearer E15_Robot_Secure_Token_123" -H "Content-Type: application/json"
```

PowerShell example:

```powershell
$headers = @{
  Authorization = "Bearer E15_Robot_Secure_Token_123"
  "Content-Type" = "application/json"
}
```

---

## Motion Control API

### 1. Query Overall Status

```bash
curl -X GET "http://192.168.1.34:8080/control/status" -H "Authorization: Bearer E15_Robot_Secure_Token_123"
```

### 2. Update Motion Control Command

Endpoint: `POST /control/motion`

Supported fields:

- `mode`: `passive` / `damp` / `recovery_stand` / `stand_down` / `rl_walk` / `development`
- `vx`
- `vy`
- `vyaw`
- `body_height`
- `roll`
- `pitch`

Notes:

- When `mode` is not `rl_walk` or `development`, velocity and attitude-related values are cleared automatically.
- Current limits: `vx` `[-1.5, 1.5]`, `vy` `[-1.0, 1.0]`, `vyaw` `[-1.5, 1.5]`, `body_height` `[-0.20, 0.20]`, `roll` `[-0.50, 0.50]`, `pitch` `[-0.50, 0.50]`.

### 2.1 Switch to Damping Mode

```bash
curl -X POST "http://192.168.1.100:8080/control/motion" -H "Authorization: Bearer E15_Robot_Secure_Token_123" -H "Content-Type: application/json" -d "{"mode":"damp"}"
```

### 2.2 Recover to Stand

```bash
curl -X POST "http://192.168.1.34:8080/control/motion" -H "Authorization: Bearer E15_Robot_Secure_Token_123" -H "Content-Type: application/json" -d "{"mode":"recovery_stand"}"
```

### 2.3 Enter RL Walk and Send Forward Velocity

```bash
curl -X POST "http://192.168.1.100:8080/control/motion" \
  -H "Authorization: Bearer E15_Robot_Secure_Token_123" \
  -H "Content-Type: application/json" \
  -d "{"mode":"rl_walk","vx":0.3,"vy":0.0,"vyaw":0.0}"
```

### 2.4 RL Walk Lateral Motion and Turning

```bash
curl -X POST "http://192.168.1.100:8080/control/motion" \
  -H "Authorization: Bearer E15_Robot_Secure_Token_123" \
  -H "Content-Type: application/json" \
  -d "{"mode":"rl_walk","vx":0.1,"vy":0.2,"vyaw":0.3}"
```

### 2.5 Adjust Body Height and Attitude

```bash
curl -X POST "http://192.168.1.100:8080/control/motion" \
  -H "Authorization: Bearer E15_Robot_Secure_Token_123" \
  -H "Content-Type: application/json" \
  -d "{"mode":"development","body_height":0.05,"roll":0.05,"pitch":-0.05}"
```

### 2.6 Update Partial Fields

For example, update only yaw velocity:

```bash
curl -X POST "http://192.168.1.100:8080/control/motion" \
  -H "Authorization: Bearer E15_Robot_Secure_Token_123" \
  -H "Content-Type: application/json" \
  -d "{"vyaw":0.4}"
```

This endpoint performs an incremental update based on the current cached command.

### 3. Stop Motion

Endpoint: `POST /control/stop`

```bash
curl -X POST "http://192.168.1.100:8080/control/stop" \
  -H "Authorization: Bearer E15_Robot_Secure_Token_123"
```

### 4. Motion-Control Error Tests

Use invalid modes, invalid field types, or a wrong token to verify validation and authentication:

```bash
curl -X POST "http://192.168.1.100:8080/control/motion" \
  -H "Authorization: Bearer E15_Robot_Secure_Token_123" \
  -H "Content-Type: application/json" \
  -d "{"mode":"run_fast"}"

curl -X POST "http://192.168.1.100:8080/control/motion" \
  -H "Authorization: Bearer E15_Robot_Secure_Token_123" \
  -H "Content-Type: application/json" \
  -d "{"mode":123}"

curl -X GET "http://192.168.1.100:8080/control/status" \
  -H "Authorization: Bearer wrong_token"
```

---

## Navigation Control API

### 1. Query Navigation Status

```bash
curl -X GET "http://192.168.1.34:8080/control/nav/status" -H "Authorization: Bearer E15_Robot_Secure_Token_123"
```

Important fields:

- `data.nav_state.code`
- `data.nav_state.code_desc`
- `data.last_command.expected_response_code`
- `data.last_command.matched_expected_response`
- `data.summary.status`
- `data.summary.goal_reached`

### 2. Navigation Command Endpoint

Endpoint: `POST /control/nav`

Supported commands:

- `start_mapping`
- `end_mapping`
- `start_cutter`
- `end_cutter`
- `start_localization`
- `end_localization`
- `start_nav`
- `end_nav`
- `start_goal_program`
- `end_goal_program`
- `send_goal`
- `clear_goal`
- `start_all`
- `stop_all`

Examples:

```bash
curl -X POST "http://192.168.1.100:8080/control/nav" \
  -H "Authorization: Bearer E15_Robot_Secure_Token_123" \
  -H "Content-Type: application/json" \
  -d "{"cmd_type":"start_localization"}"

curl -X POST "http://192.168.1.100:8080/control/nav" \
  -H "Authorization: Bearer E15_Robot_Secure_Token_123" \
  -H "Content-Type: application/json" \
  -d "{"cmd_type":"start_nav"}"
```

Expected states include `nav_state.code = 20265` for localization ACK and `nav_state.code = 20267` with `last_command.matched_expected_response = true` for navigation ACK.

### 2.6 Send a Goal

`params` must contain 8 space-separated numbers:

`goal_index x y z roll pitch yaw w`

```bash
curl -X POST "http://192.168.1.100:8080/control/nav" \
  -H "Authorization: Bearer E15_Robot_Secure_Token_123" \
  -H "Content-Type: application/json" \
  -d "{"cmd_type":"send_goal","params":"1 0.5 0.0 0.0 0.0 0.0 0.0 1.0"}"
```

Expected sequence:

- Immediately after sending: `summary.status = "waiting_ack"`
- After ACK: `summary.status = "ack_received"`
- After reaching the goal: `summary.status = "goal_reached"`

### 2.7 Clear / Stop Navigation

```bash
curl -X POST "http://192.168.1.100:8080/control/nav" \
  -H "Authorization: Bearer E15_Robot_Secure_Token_123" \
  -H "Content-Type: application/json" \
  -d "{"cmd_type":"clear_goal"}"

curl -X POST "http://192.168.1.100:8080/control/nav" \
  -H "Authorization: Bearer E15_Robot_Secure_Token_123" \
  -H "Content-Type: application/json" \
  -d "{"cmd_type":"stop_all"}"
```

### 3. Navigation Error Tests

Test missing `cmd_type`, missing `params` for `send_goal`, comma-separated `params`, and wrong parameter counts to verify request validation.

---

## Recommended Joint-Debug Sequence

### Motion Control

1. `POST /control/motion` -> `{"mode":"damp"}`
2. `POST /control/motion` -> `{"mode":"recovery_stand"}`
3. `POST /control/motion` -> `{"mode":"rl_walk","vx":0.2}`
4. `GET /control/status`
5. `POST /control/stop`

### Navigation Control

1. `start_localization`
2. Query `/control/nav/status`.
3. `start_nav`
4. `start_goal_program`
5. `send_goal`
6. Poll `/control/nav/status`.
7. Check whether `summary.status` becomes `goal_reached`.

---

## PowerShell Examples

```powershell
Invoke-RestMethod `
  -Uri "http://192.168.1.100:8080/control/nav/status" `
  -Method Get `
  -Headers @{ Authorization = "Bearer E15_Robot_Secure_Token_123" }

Invoke-RestMethod `
  -Uri "http://192.168.1.100:8080/control/motion" `
  -Method Post `
  -Headers @{ Authorization = "Bearer E15_Robot_Secure_Token_123" } `
  -ContentType "application/json" `
  -Body '{"mode":"rl_walk","vx":0.3,"vy":0.0,"vyaw":0.0}'

Invoke-RestMethod `
  -Uri "http://192.168.1.100:8080/control/nav" `
  -Method Post `
  -Headers @{ Authorization = "Bearer E15_Robot_Secure_Token_123" } `
  -ContentType "application/json" `
  -Body '{"cmd_type":"send_goal","params":"1 0.5 0.0 0.0 0.0 0.0 0.0 1.0"}'
```

---

## LCM / Navigation Enable Joint Debugging

This applies to `POST /control/nav/enable` -> `NAV_ENABLE_CTRL` -> `RL_WALK`.

### Prerequisites

1. The controller is running and `RL_WALK` has entered navigation subscription logic.
2. Controller log printed: `[RL_Walk][NAV] Subscribed to NAV_CONTROL and NAV_ENABLE_CTRL`.
3. HTTP service is running and `/control/status` plus `/control/nav/status` are reachable.
4. HTTP server and controller use the same LCM multicast URL, currently `udpm://239.255.76.67:7667?ttl=255`.
5. The robot can switch to `rl_walk`; navigation enable requires current mode to be `rl_walk`.

### Basic Flow

```bash
curl -X GET "http://192.168.1.100:8080/control/status" -H "Authorization: Bearer E15_Robot_Secure_Token_123"

curl -X POST "http://192.168.1.100:8080/control/motion" -H "Authorization: Bearer E15_Robot_Secure_Token_123" -H "Content-Type: application/json" -d "{"mode":"rl_walk"}"

curl -X POST "http://192.168.1.34:8080/control/nav/enable" -H "Authorization: Bearer E15_Robot_Secure_Token_123" -H "Content-Type: application/json" -d "{"nav_enabled":true}"
```

Expected response:

```json
{"code":0,"msg":"nav enable updated", ...}
```

Expected controller log:

```text
[RL_Walk][NAV] NAV_ENABLE_CTRL received: 1
```

Disable navigation:

```bash
curl -X POST "http://192.168.1.34:8080/control/nav/enable" -H "Authorization: Bearer E15_Robot_Secure_Token_123" -H "Content-Type: application/json" -d "{"nav_enabled":false}"
```

The controller should print:

```text
[RL_Walk][NAV] NAV_ENABLE_CTRL received: 0
```

With the current logic, navigation blending is enabled if either condition is true:

1. Remote-control side: `rcCommand->variable[0] == 1`
2. LCM command: `NAV_ENABLE_CTRL == 1`

### Troubleshooting

- `curl` succeeds but controller has no log: check network, LCM URL, controller rebuild/restart, and `RL_WALK` mode.
- `/control/nav/enable` returns 400: current mode is usually not `rl_walk`.
- `/control/nav/status` is normal but enable has no effect: `NAV_ENABLE_CTRL` path is not connected or controller navigation blending is not enabled.
- Enabled but still no motion: confirm continuous `NAV_CONTROL`, valid robot posture, FSM output permission, and no `setAllMotorsToZero()` self-check trigger.
