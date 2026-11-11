# Assistant

Персональный ассистент на FastAPI. Репозиторий ведётся в рамках лабораторных по Docker и Kubernetes.

Автор: Федченко Максим, ИСУ 467857

## Как запустить

```bash
docker build -t fedchenko-assistant:v1 .
docker run -d \
  --name fedchenko-assistant-1 \
  -p 5487:5487 \
  -e APP_OWNER=fedchenko \
  -e APP_SECRET=secret57fedchenko \
  fedchenko-assistant:v1
```

## Переменные окружения

| Переменная | Для чего | Пример |
| --- | --- | --- |
| `APP_OWNER` | ваша фамилия, показывается на главной и в `/me` | `fedchenko` |
| `APP_SECRET` | секретный ключ для эндпоинта `/secret/{key}` | `secret57fedchenko` |
| `PORT` | порт приложения (задан в Dockerfile) | `5487` |

## Как проверить

```bash
curl http://localhost:5487/health
curl http://localhost:5487/me
curl http://localhost:5487/secret/secret57fedchenko
```

## Docker: сборка и оптимизация образа (ЛР №2)

В каталоге два Dockerfile:

- `Dockerfile` - базовая версия (Этап 1 лабораторной).
- `Dockerfile.optimized` - multi-stage сборка с `pip install --no-cache-dir`, установкой `curl` и `HEALTHCHECK` (Этапы 2 и 4).

```bash
# Базовый образ
docker build -t fedchenko-assistant:v1 .

# Оптимизированный образ
docker build -t fedchenko-assistant:v2 -f Dockerfile.optimized .

# Финальная версия с healthcheck
docker build -t fedchenko-assistant:final -f Dockerfile.optimized .
docker tag fedchenko-assistant:final fedchenko-assistant:1.0.0

# Статус healthcheck
docker ps --filter "name=fedchenko-assistant" --format "table {{.Names}}\t{{.Status}}"
```

`.dockerignore` исключает из контекста сборки `__pycache__/`, кеши, `.git`, логи и сами Dockerfile/README, чтобы образ не раздувался и не тащил лишние/чувствительные файлы.
