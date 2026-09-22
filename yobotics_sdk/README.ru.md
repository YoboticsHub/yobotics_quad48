<p align="center">
  <a href="./README.md">🌎 English</a> | <a href="./README.zh.md">🇨🇳 中文</a> | 🇷🇺 Русский
</p>

# yobotics_sdk_e15_260408_lib_generate

Этот проект содержит SDK для E15, примеры программ и пример HTTP-сервиса для управления движением и навигацией.

Английская версия: [README.md](./README.md). Китайская версия: [README.zh.md](./README.zh.md). Краткое руководство по интеграции SDK доступно в [SDK_User_Guide.md](./SDK_User_Guide.md).

## Обзор каталога

- `include/`: заголовки SDK
- `lib/libyobotics_sdk.a`: статическая библиотека
- `example/http_server.cpp`: пример HTTP-сервиса управления E15
- `example/sport_client.cpp`: пример управления движением
- `example/robot_state_client.cpp`: пример подписки на состояние
- `dist/`: каталог вывода пакета
- `tools/`: скрипты сборки и развертывания

## Сборка примеров

```bash
mkdir -p build && cd build
cmake ..
make -j4
```

Исполняемые файлы примеров по умолчанию:

- `yobot_sport_client`
- `yobot_robot_state_client`
- `yobot_http_server`

## Установка SDK

```bash
mkdir -p build && cd build
cmake .. -DCMAKE_INSTALL_PREFIX=/opt/yobotics_sdk_e15_260408
make -j4
sudo make install
```

## Прямая линковка статической библиотеки

```bash
g++ -std=c++11 your_app.cpp \
  -I./include -I./include/common -I./include/robot -I./include/robot/channel \
  ./lib/libyobotics_sdk.a -llcm -lpthread -o your_app
```

## HTTP-сервис управления

Конфигурация по умолчанию:

- Адрес сервиса: `http://192.168.1.100:8080`
- Токен по умолчанию: `E15_Robot_Secure_Token_123`
- Заголовок запроса: `Authorization: Bearer <token>`

Переменные окружения:

- `SERVER_HOST`
- `SERVER_PORT`
- `ROBOT_HTTP_TOKEN`
- `YOBOTICS_LCM_URL`

### Общий заголовок запроса

```bash
-H "Authorization: Bearer E15_Robot_Secure_Token_123" -H "Content-Type: application/json"
```

Пример PowerShell:

```powershell
$headers = @{
  Authorization = "Bearer E15_Robot_Secure_Token_123"
  "Content-Type" = "application/json"
}
```

---

## API управления движением

### 1. Запрос общего состояния

```bash
curl -X GET "http://192.168.1.34:8080/control/status" -H "Authorization: Bearer E15_Robot_Secure_Token_123"
```

### 2. Обновление команды управления движением

Endpoint: `POST /control/motion`

Поддерживаемые поля:

- `mode`: `passive` / `damp` / `recovery_stand` / `stand_down` / `rl_walk` / `development`
- `vx`
- `vy`
- `vyaw`
- `body_height`
- `roll`
- `pitch`

Примечания:

- Когда `mode` не равен `rl_walk` или `development`, значения, связанные со скоростью и ориентацией, очищаются автоматически.
- Текущие ограничения: `vx` `[-1.5, 1.5]`, `vy` `[-1.0, 1.0]`, `vyaw` `[-1.5, 1.5]`, `body_height` `[-0.20, 0.20]`, `roll` `[-0.50, 0.50]`, `pitch` `[-0.50, 0.50]`.

### 2.1 Переключение в режим демпфирования

```bash
curl -X POST "http://192.168.1.100:8080/control/motion" -H "Authorization: Bearer E15_Robot_Secure_Token_123" -H "Content-Type: application/json" -d "{"mode":"damp"}"
```

### 2.2 Восстановление в стоячую позу

```bash
curl -X POST "http://192.168.1.34:8080/control/motion" -H "Authorization: Bearer E15_Robot_Secure_Token_123" -H "Content-Type: application/json" -d "{"mode":"recovery_stand"}"
```

### 2.3 Вход в RL Walk и отправка скорости вперед

```bash
curl -X POST "http://192.168.1.100:8080/control/motion" \
  -H "Authorization: Bearer E15_Robot_Secure_Token_123" \
  -H "Content-Type: application/json" \
  -d "{"mode":"rl_walk","vx":0.3,"vy":0.0,"vyaw":0.0}"
```

### 2.4 Боковое движение и поворот в RL Walk

```bash
curl -X POST "http://192.168.1.100:8080/control/motion" \
  -H "Authorization: Bearer E15_Robot_Secure_Token_123" \
  -H "Content-Type: application/json" \
  -d "{"mode":"rl_walk","vx":0.1,"vy":0.2,"vyaw":0.3}"
```

### 2.5 Регулировка высоты и ориентации корпуса

```bash
curl -X POST "http://192.168.1.100:8080/control/motion" \
  -H "Authorization: Bearer E15_Robot_Secure_Token_123" \
  -H "Content-Type: application/json" \
  -d "{"mode":"development","body_height":0.05,"roll":0.05,"pitch":-0.05}"
```

### 2.6 Частичное обновление полей

Например, обновить только yaw-скорость:

```bash
curl -X POST "http://192.168.1.100:8080/control/motion" \
  -H "Authorization: Bearer E15_Robot_Secure_Token_123" \
  -H "Content-Type: application/json" \
  -d "{"vyaw":0.4}"
```

Этот endpoint выполняет инкрементальное обновление на основе текущей кэшированной команды.

### 3. Остановка движения

Endpoint: `POST /control/stop`

```bash
curl -X POST "http://192.168.1.100:8080/control/stop" \
  -H "Authorization: Bearer E15_Robot_Secure_Token_123"
```

### 4. Тесты ошибок управления движением

Используйте недопустимые режимы, неверные типы полей или неправильный токен, чтобы проверить валидацию и аутентификацию:

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

## API управления навигацией

### 1. Запрос состояния навигации

```bash
curl -X GET "http://192.168.1.34:8080/control/nav/status" -H "Authorization: Bearer E15_Robot_Secure_Token_123"
```

Важные поля:

- `data.nav_state.code`
- `data.nav_state.code_desc`
- `data.last_command.expected_response_code`
- `data.last_command.matched_expected_response`
- `data.summary.status`
- `data.summary.goal_reached`

### 2. Endpoint команд навигации

Endpoint: `POST /control/nav`

Поддерживаемые команды:

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

Примеры:

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

Ожидаемые состояния включают `nav_state.code = 20265` для ACK локализации и `nav_state.code = 20267` с `last_command.matched_expected_response = true` для ACK навигации.

### 2.6 Отправка цели

`params` должен содержать 8 чисел, разделенных пробелами:

`goal_index x y z roll pitch yaw w`

```bash
curl -X POST "http://192.168.1.100:8080/control/nav" \
  -H "Authorization: Bearer E15_Robot_Secure_Token_123" \
  -H "Content-Type: application/json" \
  -d "{"cmd_type":"send_goal","params":"1 0.5 0.0 0.0 0.0 0.0 0.0 1.0"}"
```

Ожидаемая последовательность:

- Сразу после отправки: `summary.status = "waiting_ack"`
- После ACK: `summary.status = "ack_received"`
- После достижения цели: `summary.status = "goal_reached"`

### 2.7 Очистка / остановка навигации

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

### 3. Тесты ошибок навигации

Проверьте отсутствие `cmd_type`, отсутствие `params` для `send_goal`, `params` через запятую и неверное число параметров, чтобы проверить валидацию запроса.

---

## Рекомендуемая последовательность совместной отладки

### Управление движением

1. `POST /control/motion` -> `{"mode":"damp"}`
2. `POST /control/motion` -> `{"mode":"recovery_stand"}`
3. `POST /control/motion` -> `{"mode":"rl_walk","vx":0.2}`
4. `GET /control/status`
5. `POST /control/stop`

### Управление навигацией

1. `start_localization`
2. Query `/control/nav/status`.
3. `start_nav`
4. `start_goal_program`
5. `send_goal`
6. Poll `/control/nav/status`.
7. Проверьте, становится ли `summary.status` равным `goal_reached`.

---

## Примеры PowerShell

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

## Совместная отладка LCM / включения навигации

Это относится к цепочке `POST /control/nav/enable` -> `NAV_ENABLE_CTRL` -> `RL_WALK`.

### Предварительные условия

1. Контроллер запущен, и `RL_WALK` вошел в логику подписки навигации.
2. В журнале контроллера напечатано: `[RL_Walk][NAV] Subscribed to NAV_CONTROL and NAV_ENABLE_CTRL`.
3. HTTP-сервис запущен, а `/control/status` и `/control/nav/status` доступны.
4. HTTP-сервер и контроллер используют один и тот же multicast URL LCM, сейчас `udpm://239.255.76.67:7667?ttl=255`.
5. Робот может переключиться в `rl_walk`; включение навигации требует, чтобы текущий режим был `rl_walk`.

### Базовый процесс

```bash
curl -X GET "http://192.168.1.100:8080/control/status" -H "Authorization: Bearer E15_Robot_Secure_Token_123"

curl -X POST "http://192.168.1.100:8080/control/motion" -H "Authorization: Bearer E15_Robot_Secure_Token_123" -H "Content-Type: application/json" -d "{"mode":"rl_walk"}"

curl -X POST "http://192.168.1.34:8080/control/nav/enable" -H "Authorization: Bearer E15_Robot_Secure_Token_123" -H "Content-Type: application/json" -d "{"nav_enabled":true}"
```

Ожидаемый ответ:

```json
{"code":0,"msg":"nav enable updated", ...}
```

Ожидаемый журнал контроллера:

```text
[RL_Walk][NAV] NAV_ENABLE_CTRL received: 1
```

Отключение навигации:

```bash
curl -X POST "http://192.168.1.34:8080/control/nav/enable" -H "Authorization: Bearer E15_Robot_Secure_Token_123" -H "Content-Type: application/json" -d "{"nav_enabled":false}"
```

Контроллер должен напечатать:

```text
[RL_Walk][NAV] NAV_ENABLE_CTRL received: 0
```

С текущей логикой смешивание навигации включено, если истинно любое из условий:

1. Сторона пульта: `rcCommand->variable[0] == 1`
2. Команда LCM: `NAV_ENABLE_CTRL == 1`

### Устранение неполадок

- `curl` успешен, но у контроллера нет журнала: проверьте сеть, URL LCM, пересборку/перезапуск контроллера и режим `RL_WALK`.
- `/control/nav/enable` возвращает 400: текущий режим обычно не `rl_walk`.
- `/control/nav/status` нормален, но включение не действует: путь `NAV_ENABLE_CTRL` не подключен или смешивание навигации в контроллере не включено.
- Включено, но движения все равно нет: подтвердите непрерывный `NAV_CONTROL`, корректную позу робота, разрешение выхода FSM и отсутствие срабатывания самопроверки `setAllMotorsToZero()`.
