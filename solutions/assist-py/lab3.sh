#!/usr/bin/env bash
set -eo pipefail
cd "$(dirname "$0")"

owner=fedchenko
pg_port=5487
app_port=8057
export APP_SECRET=secret57fedchenko
export POSTGRES_USER=user_57 POSTGRES_PASSWORD=pgpass_57 POSTGRES_DB=fedchenko57

db=$owner-postgres
assistant=$owner-assistant
config_container=$assistant-config
volume=$owner-pgdata
network=$owner-backend
image=$assistant:v3
base=http://localhost:$app_port

host_options=()
if [[ "$(uname -s)" == Linux ]]; then
  host_options+=(--add-host=host.docker.internal:host-gateway)
fi

start_db() {
  docker run -d --name "$db" "$@" \
    -e POSTGRES_USER -e POSTGRES_PASSWORD -e POSTGRES_DB \
    -v "$volume:/var/lib/postgresql/data" postgres:15
  # Wait for the final TCP listener. The initialization server uses a local socket.
  for ((attempt=0; attempt<60; attempt++)); do
    if docker exec "$db" pg_isready -h 127.0.0.1 -U "$POSTGRES_USER" -d "$POSTGRES_DB" >/dev/null 2>&1; then
      return
    fi
    sleep 1
  done
  docker logs "$db" >&2
  return 1
}

start_app() {
  local name=$1 db_host=$2 db_port=$3
  shift 3
  local DATABASE_URL="postgresql://$POSTGRES_USER:$POSTGRES_PASSWORD@$db_host:$db_port/$POSTGRES_DB"
  export DATABASE_URL
  docker run -d --name "$name" -p "$app_port:$app_port" \
    -e PORT="$app_port" -e APP_OWNER="$owner" -e APP_SECRET -e DATABASE_URL \
    "$@" "$image"
  for ((attempt=0; attempt<30; attempt++)); do
    if curl -fsS "$base/health" >/dev/null 2>&1; then
      return
    fi
    sleep 1
  done
  docker logs "$name" >&2
  return 1
}

request() {
  printf '\n$ curl -fsS %s\n' "$*"
  curl -fsS "$@" | python3 -m json.tool --no-ensure-ascii
}

first_note='ЛР3: данные в БД'
second_note='ЛР3: сеть работает!'
config_mount=("$PWD/config:/app/config:ro")

case "${1:-}" in
  1)
    docker volume create "$volume"
    docker volume ls --filter "name=$volume"
    docker volume inspect "$volume"
    start_db -p "$pg_port:5432"
    docker ps --filter "name=^/$db$" --format 'table {{.Names}}\t{{.Status}}\t{{.Ports}}'
    docker build -t "$image" -f Dockerfile.optimized .
    start_app "$assistant" host.docker.internal "$pg_port" "${host_options[@]}"
    request "$base/"
    request "$base/health"
    request "$base/notes" -H 'Content-Type: application/json' -d "{\"text\": \"$first_note\"}"
    request "$base/notes"
    ;;
  2)
    original_id=$(docker inspect --format '{{.Id}}' "$assistant")
    docker stop "$assistant"
    docker rm "$assistant"
    start_app "$assistant" host.docker.internal "$pg_port" "${host_options[@]}"
    test "$original_id" != "$(docker inspect --format '{{.Id}}' "$assistant")"
    printf '\nТест персистентности: %s\n%s@%s\n' "$(date '+%H:%M:%S')" "$(whoami)" "$(hostname)"
    response=$(curl -fsS "$base/notes")
    printf '%s\n' "$response" | python3 -m json.tool --no-ensure-ascii
    printf '%s\n' "$response" | python3 -c 'import json, sys; assert sys.argv[1] in json.load(sys.stdin)["notes"]' "$first_note"
    ;;
  3)
    docker stop "$assistant"
    docker rm "$assistant"
    start_app "$config_container" host.docker.internal "$pg_port" "${host_options[@]}" -v "${config_mount[@]}"
    printf '$ docker exec %s cat /app/config/app.conf\n' "$config_container"
    docker exec "$config_container" cat /app/config/app.conf
    ;;
  4)
    docker network create "$network"
    docker stop "$db" "$config_container"
    docker rm "$db" "$config_container"
    start_db --network "$network"
    start_app "$assistant" "$db" 5432 --network "$network" -v "${config_mount[@]}"
    request "$base/health"
    request "$base/notes" -H 'Content-Type: application/json' -d "{\"text\": \"$second_note\"}"
    request "$base/notes"
    docker pull alpine:3.18
    printf '\n$ docker run --rm alpine:3.18 ping -c 2 %s\n' "$db"
    if docker run --rm alpine:3.18 ping -c 2 "$db"; then
      printf 'Имя базы разрешилось вне сети %s.\n' "$network" >&2
      exit 1
    else
      status=$?
      if ((status >= 125)); then
        exit "$status"
      fi
    fi
    printf '\n$ docker run --rm --network %s alpine:3.18 ping -c 2 %s\n' "$network" "$db"
    docker run --rm --network "$network" alpine:3.18 ping -c 2 "$db"
    ;;
  5)
    printf 'ЛР3 завершена: %s\nСтудент: %s@%s\n' "$(date '+%d.%m.%Y %H:%M:%S')" "$(whoami)" "$(hostname)"
    printf '\nКонтейнеры:\n'
    docker ps --filter "name=$owner-" --format 'table {{.Names}}\t{{.Status}}\t{{.Ports}}'
    printf '\nVolumes:\n'
    docker volume ls --filter "name=$owner-"
    printf '\nСети:\n'
    docker network ls --filter "name=$owner-"
    ;;
  *)
    printf 'Использование: bash lab3.sh {1|2|3|4|5}\n' >&2
    exit 2
    ;;
esac
