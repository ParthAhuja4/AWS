#!/usr/bin/env bash
# Stop LocalStack gracefully.
#
# With the default SNAPSHOT_SAVE_STRATEGY (ON_SHUTDOWN) the state snapshot is
# written during shutdown. Killing the container instead (`docker rm -f
# localstack-main`, `docker kill`) discards everything created since startup.
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_DIR"

set -a
# shellcheck disable=SC1091
[[ -f .env ]] && source .env
set +a

exec "$PROJECT_DIR/venv/bin/localstack" stop
