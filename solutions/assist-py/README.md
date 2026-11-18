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

## Хранение данных (ЛР №3)

PostgreSQL 15 хранит заметки в базе `fedchenko57`. Именованный volume
`fedchenko-pgdata` монтируется в `/var/lib/postgresql/data` и используется при
пересоздании PostgreSQL. Ассистент слушает порт `8057`. При заданной
`DATABASE_URL` он создаёт таблицу `notes` при первом запуске. Запрос `/health`
проверяет доступность таблицы. Запуски из ЛР №2 без `DATABASE_URL` хранят заметки
в памяти процесса.

Команды ниже выполняются из `solutions/assist-py`. Этапы запускаются по порядку.
Порты хоста `5487` и `8057` должны быть свободны.

| Команда | Что выполняется |
| --- | --- |
| `bash lab3.sh 1` | Создаёт volume, запускает `fedchenko-postgres` с публикацией `5487:5432`, собирает `fedchenko-assistant:v3` и запускает `fedchenko-assistant` с публикацией `8057:8057`. Ассистент подключается к `host.docker.internal:5487`. Выводит ответы четырёх HTTP-запросов. |
| `bash lab3.sh 2` | Пересоздаёт ассистента, проверяет изменение ID контейнера и сохранение первой заметки. Выводит время и логин с именем хоста. |
| `bash lab3.sh 3` | Запускает `fedchenko-assistant-config` с привязкой `config:/app/config:ro` и выводит конфигурацию из контейнера. |
| `bash lab3.sh 4` | Пересоздаёт оба контейнера в сети `fedchenko-backend` с прежним volume. Ассистент подключается к `fedchenko-postgres:5432` через Docker DNS. У PostgreSQL больше нет опубликованного порта. Проверяет HTTP и ping снаружи и изнутри сети. |
| `bash lab3.sh 5` | Выводит контейнеры, volume и сеть вместе с временем, логином и хостом. |

Чтобы проверить обновление привязанного файла на этапе 3, измените на хосте
`maintenance_mode=false` на `maintenance_mode=true` в `config/app.conf` и
выполните:

```bash
docker restart fedchenko-assistant-config
docker exec fedchenko-assistant-config cat /app/config/app.conf
```

После демонстрации верните исходное значение в файле. Параметры файла служат для
проверки bind mount. Учебные учётные данные передаются в контейнеры через
переменные окружения.

Сохраните скриншоты терминала в `solutions/reports/lab-3/` под именами
`step-01-curl.png`, `step-02-persistence.png`, `step-03-config.png`,
`step-04-ping-outside.png`, `step-04-ping-inside.png` и
`step-05-infrastructure.png`. В каталоге отчёта дважды выполните
`pdflatex -no-shell-escape -halt-on-error main.tex` и сохраните готовый
`main.pdf` как `ЛР3_Федченко_МВ_467857.pdf`.
