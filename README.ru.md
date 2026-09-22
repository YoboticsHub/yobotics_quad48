<p align="center">
  <a href="./README.md">🌎 English</a> | <a href="./README.zh.md">🇨🇳 中文</a> | 🇷🇺 Русский
</p>

# Фреймворк управления четвероногим роботом на основе обучения с подкреплением

[📖 Онлайн-документация](https://yoboticshub.github.io/yobotics_quad48/ru/index.html)

> Пакет RL-управления, симуляции и развертывания для четвероногого робота quad48 / Yobotics Quad. Поддерживает работу в симуляции MuJoCo в реальном времени. Среда выполнения: Ubuntu 20.04 или новее, с дистрибутивами контроллера для x86_64 и RK3588/aarch64.

Информация о версии находится в [VERSION.txt](./VERSION.txt). Этот репозиторий предназначен для поставки и вторичной разработки пакета управления `quad48 / Yobotics Quad`. Он включает бинарные файлы контроллера и runtime-библиотеки, симуляцию MuJoCo, типы сообщений LCM, сервис WebRTC, фреймворк внешних алгоритмов и примеры SDK для `E15`.

Английская версия доступна в [README.md](./README.md), китайская версия — в [README.zh.md](./README.zh.md). Онлайн-руководство собирается через [mkdocs.yml](./mkdocs.yml).

## Обзор возможностей

Текущие режимы управления:

- `DAMP`
- `RECOVERY_STAND`
- `RL_WALK`
- `RL_RUN`
- `DEVELOPMENT`

Основные сценарии запуска:

1. Симуляция MuJoCo: используйте [config_sim.yaml](./config_sim.yaml) и [scripts/start_mujoco.sh](./scripts/start_mujoco.sh).
2. Управление физическим роботом: используйте [config.yaml](./config.yaml) и [scripts/run_robot_controller.sh](./scripts/run_robot_controller.sh).

Внешние алгоритмы подключаются через LCM только в режиме `DEVELOPMENT`. См. [external_algorithms/README.ru.md](./external_algorithms/README.ru.md).

## Быстрый старт

Начните с симуляции, чтобы проверить окружение и файлы модели.

### 1. Настройка окружения

```bash
# Однокомандная настройка Conda-окружения: Python + MuJoCo + LCM + ONNX Runtime
./scripts/setup_conda_env.sh
```

При необходимости выполните ручную настройку:

```bash
# Создать Conda-окружение
conda create -n quad_controller python=3.8

# Системные зависимости
sudo apt-get install -y liblcm-dev libeigen3-dev

# Python-зависимости
pip install numpy==1.24.4 mujoco==3.2.3 pyyaml onnxruntime pillow

# Python-привязки LCM
./scripts/install_python_lcm.sh

# Настройка сети LCM, если требуется
sudo ./scripts/setup_lcm_network.sh
```

### 2. Запуск симуляции

```bash
# Активировать окружение
conda activate quad_controller

# Запустить симулятор и контроллер вместе
./scripts/start_mujoco.sh

# Запустить клиент управления SDK
./yobotics_sdk/build/E15_sport_client
```

Нажмите `Ctrl+C`, чтобы остановить все процессы.

## Работа с физическим роботом

Перед запуском на физическом роботе сначала выполните проверку в MuJoCo, чтобы убедиться, что Python-окружение, файлы модели и базовая конфигурация работоспособны. Хост робота обычно работает под Ubuntu на RK3588/aarch64. Как минимум проверьте, что в пакете развертывания присутствуют:

- `bin_rk3588/`: точки входа контроллера для RK3588/aarch64
- `lib_rk3588/`: runtime-библиотеки для RK3588/aarch64
- `config.yaml`: конфигурация физического робота по умолчанию
- `actor_model/`: ONNX-модели политик, используемые режимами `RL_WALK` и `RL_RUN`
- `resources/`: URDF, XML, mesh-файлы и связанные ресурсы робота

При локальной проверке на x86_64 скрипты автоматически переключаются на `bin/` и `lib/`.

### 1. Проверка конфигурации

Режим физического робота использует [config.yaml](./config.yaml). Перед запуском проверьте:

- `simulation.enable_mujoco: false`: отключает MuJoCo и переводит систему на путь управления физическим роботом.
- `motor_communication.type: spi_legacy`: использует текущий аппаратный канал связи SPI.
- `gamepad.device_type: hybrid`: разрешает локальный пульт управления и управляющий ввод через LCM/WebRTC.
- `safety_checker.enable_safety_check: True`: оставляет проверки безопасности включенными. Отключать защиту на реальном роботе не рекомендуется.

#### Краткая справка по конфигурации моделей

Скрипт запуска выбирает каталог контроллера x86_64 или RK3588/aarch64 по результату `uname -m`, но аппаратную конфигурацию конкретного робота все равно нужно проверить вручную в `config.yaml`.

| Модель / платформа | `motor_communication.spi_type` | `motor_communication.spi_device0` | `motor_communication.spi_device1` | `imu.type` | `imu.port_base` | `imu.port_number` | `development.robot_id` | LCM-каналы режима разработки |
|-----------|--------------------------------|-----------------------------------|-----------------------------------|------------|-----------------|-------------------|------------------------|-------------------|
| `y15 / x86_64` | `"Y15"` | `"/dev/spidev2.0"` | `"/dev/spidev2.1"` | `"lord"` | `"/dev/ttyUSB"` | `0` | `"Y15"` | `Y15_development_state` / `Y15_development_command` |
| `E15 / ARM(RK3588/aarch64)` | `"E15"` | `"/dev/spidev3.0"` | `"/dev/spidev4.0"` | `"hipnuc"` | `"/dev/ttyS0"` | оставить закомментированным или не задавать | `"E15"` | `E15_development_state` / `E15_development_command` |

Если Y15 использует `lord`, раскомментируйте `port_number` и задайте его согласно фактическому номеру устройства. Если E15 использует `hipnuc`, задайте `port_base` как полный путь к последовательному устройству.

Если скопировано несколько конфигурационных файлов для разных моделей, явно укажите нужный файл при запуске:

```bash
bash scripts/run_robot_controller.sh --config config.yaml
bash scripts/run_robot_controller.sh --config config_y15.yaml
bash scripts/run_robot_controller.sh --config config_e15.yaml
```

При изменении каналов пульта, последовательного порта, SPI или LCM сначала обновите `config.yaml` и держите конфигурацию WebRTC согласованной с основным контроллером.

### 2. Запуск контроллера

Запускайте из корня репозитория:

```bash
bash scripts/run_robot_controller.sh --config config.yaml
```

Скрипт выбирает пути к контроллеру и библиотекам по результату `uname -m`:

- x86_64: `bin/ybt_ctrl` и `lib/`
- RK3588/aarch64: `bin_rk3588/ybt_ctrl` и `lib_rk3588/`

Сейчас скрипт настраивает multicast-сеть LCM на `eth1`. Если робот использует другой сетевой интерфейс, обновите [scripts/run_robot_controller.sh](./scripts/run_robot_controller.sh) или настройте multicast LCM согласно локальной сети площадки.

### 3. Опционально: запуск удаленного управления и видео WebRTC

Чтобы включить видео WebRTC и удаленное управление, сначала убедитесь, что каналы управления/состояния в [WebRTC_server/config.json](./WebRTC_server/config.json) совпадают со следующими полями `config.yaml`:

- `gamepad.lcm_control_channel`
- `gamepad.lcm_state_channel`

Затем запустите из корня пакета развертывания робота:

```bash
python3 WebRTC_server/control_publisher.py
```

Конфигурация WebRTC, зависимости и устранение неполадок описаны в [WebRTC_server/README.ru.md](./WebRTC_server/README.ru.md).

### 4. Проверки во время работы и остановка

- По умолчанию журналы контроллера записываются в `log/robot_log.txt`, а ключевые состояния также выводятся в терминал.
- Используйте `bash scripts/monitor_lcm.sh` или `bash scripts/launch_lcm_spy.sh`, чтобы проверить каналы LCM и частоту сообщений.
- Если после запуска контроллера состояние робота не появляется, сначала проверьте подключения моторов/SPI/IMU, интерфейс LCM и параметры связи в `config.yaml`.
- Нажмите `Ctrl+C`, чтобы остановить контроллер в foreground-режиме. Для foreground-сервиса WebRTC используется такая же остановка через `Ctrl+C`.

## Точки входа и каталоги

- `bin/`: входной каталог дистрибутива x86_64. `bin/ybt_ctrl` — скрипт запуска, а `bin/ybt_ctrl.bin` — фактический бинарный файл контроллера.
- `lib/`: runtime-библиотеки x86_64, включая ONNX Runtime и другие shared-библиотеки.
- `bin_rk3588/`: входной каталог дистрибутива RK3588/aarch64 с той же структурой, что и `bin/`.
- `lib_rk3588/`: runtime-библиотеки RK3588/aarch64.
- `config.yaml`: конфигурация физического робота по умолчанию.
- `config_sim.yaml`: конфигурация симуляции MuJoCo по умолчанию.
- `actor_model/`: ONNX-модели политик, используемые режимами `RL_WALK` и `RL_RUN`.
- `mujoco_sim/`: Python-модуль симуляции MuJoCo.
- `resources/`: XML, URDF, mesh-файлы и ресурсы робота.
- `scripts/`: настройка окружения, запуск контроллера, мониторинг LCM, настройка сети и связанные скрипты.
- `external_algorithms/`: фреймворк интеграции внешних алгоритмов для режима разработки.
- `WebRTC_server/`: сервис видео WebRTC и удаленного управления.
- `yobotics_sdk/`: SDK E15, примеры программ и инструменты сборки/развертывания.
- `lcm-types/`: определения протокола LCM и сгенерированный код Python/C++/Java.

### Режимы

| Режим | Описание |
|------|------|
| `DAMP` | Режим фиксации/демпфирования суставов, удерживает текущую позу. |
| `RECOVERY_STAND` | Автоматически восстанавливает стоячую позу. |
| `RL_WALK` | RL-управление ходьбой с поддержкой джойстика и удаленного управления WebRTC. |
| `RL_RUN` | RL-управление бегом. |
| `DEVELOPMENT` | Режим разработки внешних алгоритмов через интерфейс LCM. |

### Файлы конфигурации

Важные поля `config.yaml`:

- `simulation.enable_mujoco`: переключатель режима симуляции/физического робота.
- `simulation.mujoco.xml_path`: путь к файлу сцены MuJoCo.
- `motor_communication.type`: режим связи, `lcm` для симуляции и `spi_legacy` для физического робота.
- `motor_communication.spi_type`: аппаратная модель, `Y15` или `E15`.
- `motor_communication.spi_device0` / `motor_communication.spi_device1`: пути SPI-устройств, которые должны соответствовать модели и Linux-узлам устройств.
- `imu.type`: тип драйвера IMU. E15 использует `hipnuc`, Y15 использует `lord`.
- `imu.port_base`: путь к последовательному устройству IMU или префикс имени устройства.
- `imu.port_number`: используется только для Y15/lord. Раскомментируйте и объедините с `port_base`, чтобы получить фактический путь устройства.
- `development.robot_id`: идентификатор робота в режиме разработки для сопоставления LCM-сообщений.
- `development.state_channel` / `development.command_channel`: LCM-каналы состояния и команд режима разработки.
- `gamepad.device_type`: тип удаленного управления, например `gamepad`, `at9s` или `lcm`.
- `safety_checker`: многоуровневая конфигурация проверок безопасности.

## Точки входа для разработки

- [external_algorithms/README.ru.md](./external_algorithms/README.ru.md): интеграция внешних алгоритмов в режиме разработки.
- `lcm-types/`: управляющий протокол и поля сообщений.
- [scripts/launch_lcm_spy.sh](./scripts/launch_lcm_spy.sh): просмотр сообщений, частот и конфигурации каналов.
- [yobotics_sdk/SDK_User_Guide.md](./yobotics_sdk/SDK_User_Guide.md): руководство по интеграции SDK для клиентских приложений.
