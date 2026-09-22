<p align="center">
  <a href="./README.md">🌎 English</a> | <a href="./README.zh.md">🇨🇳 中文</a> | 🇷🇺 Русский
</p>

# Руководство пользователя WebRTC_server

`WebRTC_server` запускает на стороне робота сервис публикации видео и данных через WebRTC. Он захватывает видео с камеры и передает его удаленному клиенту через WebRTC. Также сервис принимает управляющие JSON-сообщения через DataChannel, пересылает их в управляющий канал LCM и возвращает состояние робота из канала состояния LCM обратно клиенту.

Английская версия: [README.md](./README.md). Китайская версия: [README.zh.md](./README.zh.md).

## Содержимое каталога

- `control_publisher.py`: рекомендуемая точка входа. Запускает `signaling_server.py` и `publisher.py`, отслеживает их состояние и перезапускает, если дочерний процесс неожиданно завершился.
- `signaling_server.py`: WebSocket-сервер сигнализации. По умолчанию слушает `0.0.0.0:8765` и пересылает сообщения WebRTC Offer/Answer/ICE.
- `publisher.py`: WebRTC-публикатор. Читает кадры камеры, устанавливает P2P-соединение и обрабатывает связь DataChannel и LCM.
- `config.json`: runtime-конфигурация камеры, каналов LCM, адреса сигнализации и параметров битрейта для низкой задержки.
- `test.py`: тестовая/отладочная версия публикатора. Для обычного использования предпочтительнее `publisher.py` или `control_publisher.py`.
- Справочный документ полей JSON Yobotics: описание JSON-полей управления и состояния.

## Предварительные условия

### Зависимости Python

```bash
conda activate robot_controller
python -m pip install websockets aiortc opencv-python numpy av
```

Для управления через LCM и пересылки состояния:

```bash
python -m pip install lcm
```

Или используйте вспомогательный скрипт проекта:

```bash
bash scripts/install_python_lcm.sh
```

### Файлы типов LCM

`publisher.py` импортирует следующие сгенерированные файлы из `lcm-types/python/`:

- `sport_client_cmd_t.py`
- `sport_client_state_t.py`

Если они отсутствуют, сгенерируйте их:

```bash
bash scripts/generate_lcm_types.sh
```

Структура развертывания:

```text
robot-software/
├── build/
├── lcm-types/
└── WebRTC_server/
```

## Конфигурация

Отредактируйте `WebRTC_server/config.json`:

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

Основные поля:

- `use_camera`: включает реальную камеру; `false` использует виртуальный кадр.
- `camera.device_index`: индекс камеры OpenCV, соответствующий `/dev/video*`.
- `camera.width/height/fps`: разрешение захвата и частота кадров.
- `lcm.url`: multicast URL LCM.
- `lcm.control_channel`: LCM-канал для управляющего JSON, полученного из DataChannel.
- `lcm.state_channel`: LCM-канал состояния робота, на который подписывается сервис и который пересылается клиенту.
- `signaling.server`: WebSocket-адрес сигнализации, используемый публикатором.
- `webrtc.*`: параметры низкой задержки и управления битрейтом.

## Запуск

Рекомендуемый единый запуск:

```bash
cd ~/robot-software
python3 WebRTC_server/control_publisher.py
```

Эта команда запускает `signaling_server.py` и `publisher.py`, а также перезапускает их при завершении процесса или обнаружении `restart.flag`.

Раздельный отладочный запуск:

```bash
python3 WebRTC_server/signaling_server.py
python3 WebRTC_server/publisher.py
```

Удаленный клиент должен использовать `ws://<robot_ip>:8765` как адрес сигнализации.

## Проверки во время работы

```bash
ls /dev/video*
ss -lntp | grep 8765
bash scripts/monitor_lcm.sh --no-gui
sudo bash scripts/setup_lcm_network.sh
```

Если `camera.device_index` равен `4`, обычно это соответствует `/dev/video4`. Наличие `0.0.0.0:8765` означает, что сервер сигнализации слушает порт.

## Устранение неполадок

- Камера не открывается: проверьте `/dev/video*`, обновите `camera.device_index` и убедитесь, что есть права на чтение камеры.
- Импорт LCM завершается ошибкой: установите Python LCM и проверьте, что `lcm-types/python/` содержит `sport_client_cmd_t.py` и `sport_client_state_t.py`.
- Клиент не подключается: проверьте порт робота `8765`, URL клиента, например `ws://192.168.1.134:8765`, и сетевую доступность.
- Задержка видео слишком высокая: уменьшите разрешение/FPS камеры или битрейт и оставьте `webrtc.low_latency` равным `true`.

## Остановка сервиса

В foreground-режиме нажмите `Ctrl+C`. Если сервис управляется systemd или другим supervisor, остановите его соответствующей командой управления сервисом.
