<p align="center">
  <a href="./README.md">🌎 English</a> | <a href="./README.zh.md">🇨🇳 中文</a> | 🇷🇺 Русский
</p>

# wave_algorithm

Этот алгоритм изменяет положения суставов thigh и calf каждой ноги четвероногого робота, чтобы корпус робота двигался вверх и вниз.

Английская версия: [README.md](./README.md). Китайская версия: [README.zh.md](./README.zh.md).

## Запуск

```bash
python3 external_algorithms/wave_algorithm/run_algorithm.py --config external_algorithms/wave_algorithm/config.yaml
```

## Проектирование

- Наследуется от `external_algorithms.algorithm_base.AlgorithmBase`.
- Генерирует периодическое волновое действие напрямую в `_run_inference`.
- Отображает волну в 12-мерные целевые положения суставов в `process_action`.
- Оставляет `hip`-суставы в положениях по умолчанию, а суставы `thigh` / `calf` изменяют высоту корпуса.
