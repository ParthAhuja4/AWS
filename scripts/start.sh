#!/usr/bin/env bash
# Start LocalStack with this project's configuration.
#
# The LocalStack CLI reads config only from its own process environment and
# from ~/.localstack/<profile>.env -- it never reads ./.env. Running
# `localstack start -d` directly therefore ignored PERSISTENCE and
# LOCALSTACK_VOLUME_DIR entirely. This script loads .env first, so the
# settings actually reach the container.
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_DIR"

if [[ ! -f .env ]]; then
  echo "error: no .env found in $PROJECT_DIR" >&2
  exit 1
fi

set -a
# shellcheck disable=SC1091
source .env
set +a

: "${LOCALSTACK_VOLUME_DIR:=$PROJECT_DIR/localstack-data}"
export LOCALSTACK_VOLUME_DIR
mkdir -p "$LOCALSTACK_VOLUME_DIR"

echo "LOCALSTACK_PERSISTENCE=${LOCALSTACK_PERSISTENCE:-<unset>}  volume=$LOCALSTACK_VOLUME_DIR"
exec "$PROJECT_DIR/venv/bin/localstack" start -d "$@"
