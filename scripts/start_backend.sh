#!/usr/bin/env bash
#
# Start the Bubbler FastAPI backend with a local Postgres + pgvector database.
#
# Usage (from repo root):
#   ./scripts/start_backend.sh              # start DB (Docker), apply schema, run API
#   ./scripts/start_backend.sh --seed       # same, plus insert sample posts
#   ./scripts/start_backend.sh --rebuild-db # drop public schema and reapply schema.sql
#   ./scripts/start_backend.sh --no-docker  # use Postgres already running (see backend/.env)
#
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BACKEND="$ROOT/backend"
ENV_FILE="$BACKEND/.env"
ENV_EXAMPLE="$BACKEND/.env.example"
SCHEMA="$BACKEND/app/db/schema.sql"
CONTAINER_NAME="${BUBBLER_DB_CONTAINER:-bubbler-db}"
DB_IMAGE="${BUBBLER_DB_IMAGE:-pgvector/pgvector:pg16}"
API_HOST="${BUBBLER_API_HOST:-127.0.0.1}"
API_PORT="${BUBBLER_API_PORT:-8000}"

USE_DOCKER=true
RUN_SEED=false
REBUILD_DB="${BUBBLER_REBUILD_DB:-false}"

usage() {
  cat <<'EOF'
Start the Bubbler backend (Postgres + FastAPI).

Options:
  --seed         Insert sample topics/posts after setup (scripts/seed_db.py)
  --rebuild-db   Drop the public schema and reapply schema.sql (wipes local data)
  --no-docker    Skip Docker; connect to Postgres using backend/.env
  -h, --help     Show this help

Environment overrides:
  BUBBLER_DB_CONTAINER   Docker container name (default: bubbler-db)
  BUBBLER_DB_IMAGE       Postgres image (default: pgvector/pgvector:pg16)
  BUBBLER_API_HOST       Uvicorn bind host (default: 127.0.0.1)
  BUBBLER_API_PORT       Uvicorn bind port (default: 8000)
  BUBBLER_REBUILD_DB     Set to 1/true to rebuild the database (same as --rebuild-db)
  BUBBLER_PYTHON         Python 3.12 interpreter (auto-detected if unset)

Examples:
  ./scripts/start_backend.sh
  ./scripts/start_backend.sh --seed
  ./scripts/start_backend.sh --rebuild-db --seed
  ./scripts/start_backend.sh --no-docker
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --seed)
      RUN_SEED=true
      shift
      ;;
    --rebuild-db)
      REBUILD_DB=true
      shift
      ;;
    --no-docker)
      USE_DOCKER=false
      shift
      ;;
    -h | --help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown option: $1" >&2
      usage >&2
      exit 1
      ;;
  esac
done

log() {
  printf '==> %s\n' "$*"
}

fail() {
  printf 'error: %s\n' "$*" >&2
  exit 1
}

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || fail "Missing required command: $1"
}

# Pipfile requires Python 3.12. Prefer an explicit 3.12 binary so macOS Homebrew
# defaults (often newer than 3.12) do not break torch / sentence-transformers.
resolve_python() {
  local candidate
  local -a candidates=(
    "${BUBBLER_PYTHON:-}"
    python3.12
    /opt/homebrew/bin/python3.12
    /usr/local/bin/python3.12
  )

  for candidate in "${candidates[@]}"; do
    [[ -n "$candidate" ]] || continue
    if command -v "$candidate" >/dev/null 2>&1; then
      candidate="$(command -v "$candidate")"
    elif [[ ! -x "$candidate" ]]; then
      continue
    fi
    if "$candidate" -c 'import sys; raise SystemExit(0 if sys.version_info[:2] == (3, 12) else 1)' 2>/dev/null; then
      printf '%s\n' "$candidate"
      return 0
    fi
  done

  fail "Python 3.12 is required (see backend/Pipfile). Install it (e.g. brew install python@3.12) or set BUBBLER_PYTHON to a 3.12 interpreter."
}

is_macos() {
  [[ "$(uname -s)" == "Darwin" ]]
}

load_env_file() {
  # shellcheck disable=SC1090
  set -a
  source "$ENV_FILE"
  set +a
}

ensure_env_file() {
  if [[ -f "$ENV_FILE" ]]; then
    return
  fi

  if [[ ! -f "$ENV_EXAMPLE" ]]; then
    fail "Missing $ENV_FILE and $ENV_EXAMPLE"
  fi

  cp "$ENV_EXAMPLE" "$ENV_FILE"
  log "Created $ENV_FILE from .env.example"
}

schema_is_applied() {
  local result
  if $USE_DOCKER; then
    result="$(docker exec "$CONTAINER_NAME" psql -U "$DB_USER" -d "$DATABASE" -tAc \
      "SELECT to_regclass('public.users') IS NOT NULL;" 2>/dev/null || true)"
  else
    result="$(PGPASSWORD="$DATABASE_PASSWORD" psql -h "$HOST" -p "$PORT" -U "$DB_USER" -d "$DATABASE" -tAc \
      "SELECT to_regclass('public.users') IS NOT NULL;" 2>/dev/null || true)"
  fi
  [[ "$result" == "t" ]]
}

apply_schema() {
  log "Applying database schema from app/db/schema.sql"
  if $USE_DOCKER; then
    docker exec -i "$CONTAINER_NAME" psql -U "$DB_USER" -d "$DATABASE" <"$SCHEMA"
  else
    PGPASSWORD="$DATABASE_PASSWORD" psql -h "$HOST" -p "$PORT" -U "$DB_USER" -d "$DATABASE" -f "$SCHEMA"
  fi
}

rebuild_database() {
  log "Rebuilding database (dropping public schema; all local data will be lost)"
  local reset_sql
  reset_sql="$(cat <<SQL
DROP SCHEMA IF EXISTS public CASCADE;
CREATE SCHEMA public;
GRANT ALL ON SCHEMA public TO "$DB_USER";
GRANT ALL ON SCHEMA public TO public;
SQL
)"
  if $USE_DOCKER; then
    docker exec -i "$CONTAINER_NAME" psql -U "$DB_USER" -d "$DATABASE" <<<"$reset_sql"
  else
    PGPASSWORD="$DATABASE_PASSWORD" psql -h "$HOST" -p "$PORT" -U "$DB_USER" -d "$DATABASE" <<<"$reset_sql"
  fi
  apply_schema
}

wait_for_postgres() {
  log "Waiting for Postgres to accept connections"
  local attempts=0
  local max_attempts=30

  while (( attempts < max_attempts )); do
    if $USE_DOCKER; then
      if docker exec "$CONTAINER_NAME" pg_isready -U "$DB_USER" -d "$DATABASE" >/dev/null 2>&1; then
        return 0
      fi
    else
      if PGPASSWORD="$DATABASE_PASSWORD" pg_isready -h "$HOST" -p "$PORT" -U "$DB_USER" -d "$DATABASE" >/dev/null 2>&1; then
        return 0
      fi
    fi
    attempts=$((attempts + 1))
    sleep 1
  done

  fail "Postgres did not become ready in time"
}

start_docker_database() {
  require_cmd docker

  if ! docker info >/dev/null 2>&1; then
    fail "Docker is installed but not running. Start Docker Desktop and try again."
  fi

  if docker ps -a --format '{{.Names}}' | grep -qx "$CONTAINER_NAME"; then
    if ! docker ps --format '{{.Names}}' | grep -qx "$CONTAINER_NAME"; then
      log "Starting existing container: $CONTAINER_NAME"
      docker start "$CONTAINER_NAME" >/dev/null
    else
      log "Using running container: $CONTAINER_NAME"
    fi
  else
    log "Creating Postgres container: $CONTAINER_NAME (host port $PORT)"
    docker run -d \
      --name "$CONTAINER_NAME" \
      -e POSTGRES_USER="$DB_USER" \
      -e POSTGRES_PASSWORD="$DATABASE_PASSWORD" \
      -e POSTGRES_DB="$DATABASE" \
      -p "${PORT}:5432" \
      "$DB_IMAGE" >/dev/null
  fi

  wait_for_postgres
}

verify_local_postgres() {
  require_cmd psql
  wait_for_postgres
}

install_python_deps() {
  require_cmd pipenv

  local python_bin
  python_bin="$(resolve_python)"
  export PIPENV_PYTHON="$python_bin"
  log "Using Python: $python_bin"

  # Pipfile.lock was historically resolved on Linux and can list NVIDIA CUDA
  # wheels. Those entries are marked Linux-only; on macOS pipenv still needs a
  # clean resolve of torch (CPU/MPS). Prefer a locked install, and if that
  # fails on Darwin (stale lock / missing markers), fall back to --skip-lock.
  log "Installing Python dependencies (pipenv install)"
  if (cd "$BACKEND" && pipenv install); then
    return 0
  fi

  if is_macos; then
    log "Locked install failed on macOS; retrying without Pipfile.lock (CPU/MPS torch)"
    (cd "$BACKEND" && pipenv install --skip-lock) || fail "pipenv install failed on macOS"
    return 0
  fi

  fail "pipenv install failed"
}

seed_database() {
  log "Seeding sample topics and posts"
  (cd "$BACKEND" && pipenv run python ../scripts/seed_db.py)
}

print_ready_message() {
  cat <<EOF

Backend setup complete.
  Health:  http://${API_HOST}:${API_PORT}/health
  API:     http://${API_HOST}:${API_PORT}
  Docs:    http://${API_HOST}:${API_PORT}/docs

Press Ctrl+C to stop the server.
EOF
}

main() {
  [[ -f "$SCHEMA" ]] || fail "Schema file not found: $SCHEMA"

  ensure_env_file
  load_env_file

  : "${DATABASE:?DATABASE is required in backend/.env}"
  : "${DB_USER:?DB_USER is required in backend/.env}"
  : "${DATABASE_PASSWORD:?DATABASE_PASSWORD is required in backend/.env}"
  : "${HOST:?HOST is required in backend/.env}"
  : "${PORT:?PORT is required in backend/.env}"

  # Resolve early so macOS users get a clear error before Docker/schema work.
  export PIPENV_PYTHON
  PIPENV_PYTHON="$(resolve_python)"

  if $USE_DOCKER; then
    start_docker_database
  else
    log "Skipping Docker; using Postgres at ${HOST}:${PORT}"
    verify_local_postgres
  fi

  if [[ "$REBUILD_DB" == true || "$REBUILD_DB" == 1 ]]; then
    rebuild_database
  elif schema_is_applied; then
    log "Database schema already applied (use --rebuild-db after schema changes)"
  else
    apply_schema
  fi

  install_python_deps

  if $RUN_SEED; then
    seed_database
  fi

  print_ready_message
  # Single worker so the Hugging Face embedding model loads once in-process.
  log "Starting uvicorn on ${API_HOST}:${API_PORT} (workers=1)"
  cd "$BACKEND"
  exec pipenv run uvicorn main:app --host "$API_HOST" --port "$API_PORT" --workers 1
}

main "$@"
