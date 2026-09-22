<p align="center">
  <a href="./README.md">🌎 English</a> | <a href="./README.zh.md">🇨🇳 中文</a> | 🇷🇺 Русский
</p>

# Скрипты пакета вторичной разработки Quad48

Этот документ описывает каталог `scripts/` в автономном пакете вторичной разработки. Скрипты рассчитаны на уже упакованный каталог разработки `yobotics_quad48` и в основном используются для запуска контроллера, запуска симуляции, настройки сети LCM, мониторинга сообщений LCM, подготовки окружения Python и просмотра runtime-журналов.

Английская версия: [README.md](./README.md). Китайская версия: [README.zh.md](./README.zh.md).

## Перед использованием

По возможности выполняйте команды из корня пакета разработки:

```bash
cd yobotics_quad48
```

Обычная структура пакета:

```text
yobotics_quad48/
├── bin/                  # исполняемый файл контроллера x86_64, например ybt_ctrl
├── bin_rk3588/           # исполняемый файл контроллера RK3588/aarch64
├── lib/                  # runtime shared-библиотеки x86_64
├── lib_rk3588/           # runtime shared-библиотеки RK3588/aarch64
├── log/                  # runtime-журналы и CSV-вывод журналов
├── lcm-types/            # определения типов LCM и сгенерированные файлы
├── mujoco_sim/           # код симуляции MuJoCo
├── resources/            # модели и ресурсы робота
├── scripts/              # скрипты, описанные здесь
├── config.yaml           # конфигурация контроллера
└── config_sim.yaml       # конфигурация симуляции
```

Сначала проверьте права на выполнение:

```bash
chmod +x scripts/*.sh
```

## Рекомендуемый рабочий процесс

### 1. Подготовка Python-окружения

```bash
bash scripts/setup_conda_env.sh
```

Установить или восстановить только Python-привязки LCM:

```bash
bash scripts/install_python_lcm.sh
```

### 2. Настройка сети LCM

Если сообщения LCM отсутствуют, инструменты мониторинга не показывают данные или связь между несколькими машинами не работает:

```bash
sudo bash scripts/setup_lcm_network.sh
```

Обычно для этого требуется `sudo`, потому что скрипт изменяет настройки сетевого интерфейса и multicast-маршрутов.

### 3. Генерация типов LCM

После изменения файлов `.lcm` в `lcm-types/`, а также если отсутствуют сгенерированные файлы Python/C++:

```bash
bash scripts/generate_lcm_types.sh
```

### 4. Запуск симуляции и контроллера

```bash
bash scripts/start_mujoco.sh --config config_sim.yaml
bash scripts/run_robot_controller.sh
```

Симуляция без графического окна:

```bash
bash scripts/start_mujoco.sh --headless
```

Отображение обратной связи физического робота в MuJoCo Viewer:

```bash
bash scripts/start_hardware_viewer.sh
```

### 5. Мониторинг и анализ данных

```bash
bash scripts/monitor_lcm.sh
bash scripts/monitor_lcm.sh --no-gui
python3 scripts/data_viewer.py
python3 scripts/motor_trace_viewer.py log/motor_trace.csv
```

## Скрипты запуска

### `run_robot_controller.sh`

Запускает упакованный контроллер. По результату `uname -m` выбирает каталоги `bin*/` и `lib*/` для x86_64 или RK3588/aarch64.

```bash
bash scripts/run_robot_controller.sh
bash scripts/run_robot_controller.sh --config config.yaml
```

Используйте его для запуска контроллера на физическом роботе, проверки `bin/ybt_ctrl` или `bin_rk3588/ybt_ctrl`, а также для отладки параметров контроллера в `config.yaml`.

Примечания:

- По возможности запускайте из корня пакета.
- Без аргументов используется `config.yaml`, а контроллер выбирается по архитектуре.
- Если отсутствуют shared-библиотеки, проверьте соответствующий каталог `lib/` или `lib_rk3588/`.
- Если после запуска не появляется состояние, проверьте симуляцию и сеть LCM.

### `start_mujoco.sh`

Запускает симуляцию MuJoCo. По умолчанию читает упакованную конфигурацию симуляции или принимает пользовательский путь к конфигурации. Скрипт выбирает `bin/` и `lib/` для x86_64 либо `bin_rk3588/` и `lib_rk3588/` для RK3588/aarch64.

```bash
bash scripts/start_mujoco.sh
bash scripts/start_mujoco.sh --config config_sim.yaml
bash scripts/start_mujoco.sh --headless
```

Используйте его для локальной отладки симуляции и проверки моделей, конфигурации и ресурсов.

### `start_hardware_viewer.sh`

Запускает аппаратный MuJoCo Viewer реального времени. Скрипт задает `PYTHONPATH` и запускает `hardware_mujoco_viewer.py`, который получает LCM-обратную связь физического робота и отображает углы суставов, ориентацию корпуса и высоту.

Параметры по умолчанию:

- XML-модель: `resources/robots/quad48/scene_terrain.xml`
- URL LCM: `udpm://239.255.76.67:7667?ttl=255`
- Частота обновления Viewer: `60 Hz`

```bash
bash scripts/start_hardware_viewer.sh
bash scripts/start_hardware_viewer.sh --xml resources/robots/quad48/scene_flat.xml
bash scripts/start_hardware_viewer.sh --lcm-url "udpm://239.255.76.67:7667?ttl=255"
bash scripts/start_hardware_viewer.sh --viewer-hz 30
bash scripts/start_hardware_viewer.sh --help
```

### `hardware_mujoco_viewer.py`

Python Viewer состояния физического робота в MuJoCo. Его можно запускать напрямую или через `start_hardware_viewer.sh`. Он обновляет позу MuJoCo по полученной аппаратной обратной связи и не продвигает физическую симуляцию.

```bash
python3 scripts/hardware_mujoco_viewer.py
python3 scripts/hardware_mujoco_viewer.py --xml resources/robots/quad48/scene_flat.xml
python3 scripts/hardware_mujoco_viewer.py --lcm-url "udpm://239.255.76.67:7667?ttl=255"
python3 scripts/hardware_mujoco_viewer.py --joint-channel leg_control_data --robot-state-channel QUAD_ROBOT_STATE
python3 scripts/hardware_mujoco_viewer.py --height 0.45 --x 0.0 --y 0.0 --viewer-hz 60 --stale-timeout 2.0
```

Основные параметры:

- `--xml`: путь к XML MuJoCo, абсолютный или относительно корня пакета.
- `--lcm-url`: URL LCM для аппаратной обратной связи.
- `--joint-channel`: канал обратной связи суставов, по умолчанию `leg_control_data`, тип сообщения `quad_joint_state_t`.
- `--robot-state-channel`: канал состояния корпуса, по умолчанию `QUAD_ROBOT_STATE`, тип сообщения `sport_client_state_t`.
- `--height`: высота floating-base по умолчанию, если не получена корректная высота корпуса.
- `--x`, `--y`: фиксированная позиция в мировых координатах Viewer.
- `--viewer-hz`: только частота обновления Viewer.
- `--stale-timeout`: число секунд без новых сообщений перед выводом предупреждения о устаревших данных.

## Другие распространенные скрипты

- `monitor_lcm.sh`: запускает монитор LCM; используйте `--no-gui` в текстовых окружениях.
- `launch_lcm_spy.sh`: запускает официальный инструмент LCM spy.
- `setup_lcm_network.sh`: настраивает multicast-маршруты и параметры сетевого интерфейса.
- `generate_lcm_types.sh`: повторно генерирует привязки из файлов `.lcm`.
- `data_viewer.py`: строит графики обычных CSV-журналов или журналов RL-данных.
- `motor_trace_viewer.py`: строит графики целевых и фактических положений мотора, скорости и момента.
- `check_cmake_make_gcc.sh`: проверяет CMake, Make, GCC и G++.

## Примечания по безопасности

- Используйте `config_sim.yaml` для симуляции и `config.yaml` для физического робота.
- Держите контроллер, SDK, WebRTC, симуляцию и внешние алгоритмы на одном URL LCM и одном наборе каналов.
- Перед отправкой команд физическому роботу проверьте модель робота, SPI-устройства, порт IMU, аварийную остановку и безопасную зону.
- Перед завершением контроллера остановите внешние алгоритмы и переведите робота в безопасный режим.
