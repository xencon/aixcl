#!/bin/bash
#
# PostgreSQL Secret Reader Entrypoint
# Reads credentials from Docker secrets and exports as environment variables

set -e

# Read secrets from files if _FILE variables are set
if [[ -n "${POSTGRES_USER_FILE:-}" && -f "$POSTGRES_USER_FILE" ]]; then
  export POSTGRES_USER="$(cat "$POSTGRES_USER_FILE")"
  unset POSTGRES_USER_FILE
fi

if [[ -n "${POSTGRES_PASSWORD_FILE:-}" && -f "$POSTGRES_PASSWORD_FILE" ]]; then
  export POSTGRES_PASSWORD="$(cat "$POSTGRES_PASSWORD_FILE")"
  unset POSTGRES_PASSWORD_FILE
fi

# Execute the original entrypoint
exec docker-entrypoint.sh "$@"
