#!/usr/bin/env bash
# shellcheck shell=bash
# postgres-exporter-vault.sh - Read Vault credentials and start postgres-exporter

# Read credentials from file
if [ -f "/tmp/vault-secrets/pgexporter-creds" ]; then
    export DATA_SOURCE_NAME=$(cat /tmp/vault-secrets/pgexporter-creds)
    echo "Loaded database credentials from Vault"
else
    echo "Warning: Credential file not found at /tmp/vault-secrets/pgexporter-creds"
    exit 1
fi

# Start postgres-exporter
exec /bin/postgres_exporter "$@"
