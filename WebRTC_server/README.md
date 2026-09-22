<p align="center">
  🌎 English | <a href="./README.zh.md">🇨🇳 中文</a> | <a href="./README.ru.md">🇷🇺 Русский</a>
</p>

# WebRTC_server User Guide

`WebRTC_server` starts a WebRTC video/data publishing service on the robot side. It captures camera video and sends it to a remote client through WebRTC. It also receives JSON control messages through a DataChannel, forwards them to the LCM control channel, and sends robot state from the LCM state channel back to the client.

Chinese source: [README.zh.md](./README.zh.md).

## Directory Contents

- `control_publisher.py`: recommended entry point. Starts `signaling_server.py` and `publisher.py`, monitors them, and restarts them if a child process exits unexpectedly.
- `signaling_server.py`: WebSocket signaling server. It listens on `0.0.0.0:8765` by default and relays WebRTC Offer/Answer/ICE messages.
- `publisher.py`: WebRTC publisher. It reads camera frames, establishes a P2P connection, and handles DataChannel and LCM communication.
- `config.json`: runtime configuration for camera, LCM channels, signaling address, and low-latency bitrate parameters.
- `test.py`: test/debug publisher. Prefer `publisher.py` or `control_publisher.py` for normal use.
- Yobotics JSON field reference document: control/state JSON field reference.

## Prerequisites

### Python Dependencies

```bash
conda activate robot_controller
python -m pip install websockets aiortc opencv-python numpy av
```

For LCM control and state forwarding:

```bash
python -m pip install lcm
```

Or use the project helper:

```bash
bash scripts/install_python_lcm.sh
```

### LCM Type Files

`publisher.py` imports these generated files from `lcm-types/python/`:

- `sport_client_cmd_t.py`
- `sport_client_state_t.py`

Generate them if missing:

```bash
bash scripts/generate_lcm_types.sh
```

Deployment layout:

```text
robot-software/
├── build/
├── lcm-types/
└── WebRTC_server/
```

## Configuration

Edit `WebRTC_server/config.json`:

```json
{
  "use_camera": true,
  "camera": {
    "device_index": 4,
    "width": 640,
    "height": 360,
    "fps": 15
  },
  "lcm": {
    "url": "udpm://239.255.76.67:7667?ttl=255",
    "control_channel": "QUAD_ROBOT_CONTROL",
    "state_channel": "QUAD_ROBOT_STATE"
  },
  "signaling": {
    "server": "ws://localhost:8765"
  },
  "webrtc": {
    "low_latency": true,
    "max_fps": 15,
    "min_bitrate_kbps": 300,
    "start_bitrate_kbps": 500,
    "max_bitrate_kbps": 900
  }
}
```

Common fields:

- `use_camera`: enable the real camera; `false` uses a virtual frame.
- `camera.device_index`: OpenCV camera index, corresponding to `/dev/video*`.
- `camera.width/height/fps`: capture resolution and frame rate.
- `lcm.url`: LCM multicast URL.
- `lcm.control_channel`: LCM channel for control JSON received from DataChannel.
- `lcm.state_channel`: LCM channel subscribed for robot state and forwarded back to the client.
- `signaling.server`: WebSocket signaling address used by the publisher.
- `webrtc.*`: low-latency and bitrate-control parameters.

## Startup

Recommended unified startup:

```bash
cd ~/robot-software
python3 WebRTC_server/control_publisher.py
```

This starts `signaling_server.py` and `publisher.py`, and restarts them when a process exits or `restart.flag` is detected.

Separate debug startup:

```bash
python3 WebRTC_server/signaling_server.py
python3 WebRTC_server/publisher.py
```

The remote client should use `ws://<robot_ip>:8765` as the signaling address.

## Runtime Checks

```bash
ls /dev/video*
ss -lntp | grep 8765
bash scripts/monitor_lcm.sh --no-gui
sudo bash scripts/setup_lcm_network.sh
```

If `camera.device_index` is `4`, it usually maps to `/dev/video4`. Seeing `0.0.0.0:8765` means the signaling server is listening.

## Troubleshooting

- Camera cannot open: check `/dev/video*`, update `camera.device_index`, and confirm camera read permissions.
- LCM import fails: install Python LCM and confirm `lcm-types/python/` contains `sport_client_cmd_t.py` and `sport_client_state_t.py`.
- Client cannot connect: confirm robot port `8765`, client URL such as `ws://192.168.1.134:8765`, and network reachability.
- Video latency is high: reduce camera resolution/FPS or bitrate and keep `webrtc.low_latency` as `true`.

## Stop the Service

Press `Ctrl+C` in foreground mode. If managed by systemd or another supervisor, stop it with the corresponding service-management command.
