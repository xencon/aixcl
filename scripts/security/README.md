# Docker Secrets Management for AIXCL

**Phase 1.6** | Adversarial Security Hardening

## Overview

This document describes the Docker secrets management implementation for AIXCL, replacing plaintext `.env` credentials with secure Docker secrets.

**Status**: Implemented  
**Security Impact**: HIGH (eliminates credential exposure in environment variables)  
**Breaking Change**: Yes - requires migration from legacy .env credentials

---

## Problem Statement

### Security Debt (Pre-Phase 1.6)

| Issue | Risk | Current State |
|-------|------|---------------|
| Plaintext credentials in .env | Any user with file read can steal credentials | HIGH risk |
| Environment variable exposure | Credentials visible in `docker inspect` | MEDIUM risk |
| No rotation mechanism | Manual password changes required | LOW risk |
| No audit trail | Cannot track credential access | MEDIUM risk |

### Post-Phase 1.6 State

| Control | Implementation | Risk Level |
|---------|---------------|------------|
| Docker secrets | Credentials stored in Docker encrypted backend | LOW |
| File-based secret access | Secrets mounted as files in /run/secrets/ | LOW |
| Secret rotation | Automated via init-secrets.sh --rotate | LOW |
| Audit logging | Docker secret access logged by daemon | LOW |

---

## Architecture

### How Docker Secrets Work

```
┌─────────────────────────────────────────────────────────────┐
│                    Docker Swarm Mode                        │
│  ┌─────────────┐    ┌─────────────┐    ┌─────────────┐     │
│  │   Manager   │────│   Secret    │────│  Encrypted  │     │
│  │    Node     │    │   Store     │    │   Raft Log  │     │
│  └─────────────┘    └─────────────┘    └─────────────┘     │
│         │                                                   │
│         │ Distributes to worker nodes                       │
│         ▼                                                   │
│  ┌─────────────┐                                           │
│  │   Worker    │                                           │
│  │    Node     │                                           │
│  └─────────────┘                                           │
│         │                                                   │
│         │ Mounts secret as tmpfs in container               │
│         ▼                                                   │
│  ┌─────────────┐                                           │
│  │  Container  │  /run/secrets/postgres_password (tmpfs)   │
│  │  (AIXCL)    │  Memory-only, never touches disk          │
│  └─────────────┘                                           │
└─────────────────────────────────────────────────────────────┘
```

**Key Properties**:
- Secrets are encrypted at rest (in Raft log)
- Secrets are decrypted only on worker nodes that need them
- Mounted as tmpfs (memory-only) inside containers
- Never written to container layer or host filesystem

---

## Implementation Details

### Secret Types

| Secret Name | Type | Description |
|-------------|------|-------------|
| `postgres_user` | Credential | PostgreSQL username |
| `postgres_password` | Credential | PostgreSQL password (32 chars, random) |
| `pgadmin_email` | Credential | pgAdmin login email |
| `pgadmin_password` | Credential | pgAdmin password (32 chars, random) |
| `openwebui_email` | Credential | Open WebUI login email |
| `openwebui_password` | Credential | Open WebUI password (32 chars, random) |
| `grafana_admin_user` | Credential | Grafana admin username |
| `grafana_admin_password` | Credential | Grafana admin password (32 chars, random) |
| `database_url` | Derived | Full PostgreSQL connection string |
| `postgres_exporter_dsn` | Derived | Prometheus exporter connection string |

### File Structure

```
scripts/security/
├── init-secrets.sh          # Create/rotate/verify secrets
├── start-with-secrets.sh    # Start stack with secrets
└── README.md               # This documentation

services/
├── docker-compose.yml              # Base configuration
└── docker-compose.secrets.yml      # Secrets overlay

.env                              # Non-sensitive config only
```

---

## Usage

### First-Time Setup

```bash
# 1. Initialize Docker secrets from .env (or generate new)
./scripts/security/init-secrets.sh

# 2. Verify secrets were created
./scripts/security/init-secrets.sh --verify

# 3. Start AIXCL with secrets
./scripts/security/start-with-secrets.sh [profile]
```

### Daily Operations

```bash
# Start with secrets (profile: bld, sys)
./scripts/security/start-with-secrets.sh sys

# Verify secrets exist
./scripts/security/init-secrets.sh --verify

# View running services
docker compose -f services/docker-compose.yml \
  -f services/docker-compose.secrets.yml ps

# View logs
docker compose -f services/docker-compose.yml \
  -f services/docker-compose.secrets.yml logs -f

# Stop services
docker compose -f services/docker-compose.yml \
  -f services/docker-compose.secrets.yml down
```

### Secret Rotation

```bash
# Rotate all secrets (generates new random passwords)
./scripts/security/init-secrets.sh --rotate

# Note: You must restart services to apply new secrets
./scripts/security/start-with-secrets.sh dev
```

### Cleanup

```bash
# Remove all secrets (DESTRUCTIVE - will break running services)
./scripts/security/init-secrets.sh --clean
```

---

## Migration Guide

### From .env to Docker Secrets

**Step 1: Prepare**
```bash
# Backup your .env
cp .env .env.backup.$(date +%Y%m%d)

# Verify Docker swarm mode
docker info --format '{{.Swarm.LocalNodeState}}'
# Should output: "active"
```

**Step 2: Initialize Secrets**
```bash
# This will:
# - Read existing values from .env
# - Create Docker secrets
# - Generate new passwords if not in .env
./scripts/security/init-secrets.sh
```

**Step 3: Verify**
```bash
./scripts/security/init-secrets.sh --verify
```

**Step 4: Start Services**
```bash
# Stop old services first (if running)
./aixcl stack stop

# Start with secrets
./scripts/security/start-with-secrets.sh dev
```

**Step 5: Update Credentials**
```bash
# Get new random passwords
docker secret inspect --format='{{.Spec.Name}}' postgres_password
# Note: You cannot view secret values after creation
# Use .env.backup for reference during migration
```

### Rollback to .env

```bash
# Stop services with secrets
docker compose -f services/docker-compose.yml \
  -f services/docker-compose.secrets.yml down

# Clean secrets
./scripts/security/init-secrets.sh --clean

# Start with standard .env
./aixcl stack start --profile sys
```

---

## Security Considerations

### What's Protected

| Protected | Mechanism |
|-----------|-----------|
| Credentials at rest | Docker encrypted Raft log |
| Credentials in transit | TLS between swarm nodes |
| Credentials in containers | tmpfs mount (memory only) |
| Credential access | RBAC (swarm manager controls distribution) |

### What's Still Exposed

| Exposed | Mitigation |
|---------|------------|
| Secret values to container processes | Process isolation, non-root users |
| Secret values in application logs | Code review, log scrubbing |
| Secret values via `/proc/*/environ` | tmpfs prevents this (not in env) |
| Docker daemon access | Secure daemon socket, audit logging |

### Threat Model Updates

**Credential Theft → Lateral Movement** (T1078)

| Before | After |
|--------|-------|
| HIGH risk - .env readable by any process | LOW risk - secrets in Docker encrypted store |
| Attack: `cat .env` → credentials stolen | Attack: requires docker daemon compromise |
| Mitigation: file permissions (insufficient) | Mitigation: Docker secrets + daemon security |

---

## Troubleshooting

### Issue: "Docker Swarm mode is not active"

```bash
# Initialize swarm (single-node is fine for development)
docker swarm init --advertise-addr 127.0.0.1

# If already in swarm but shows inactive:
docker swarm leave --force  # DANGER: removes all services
docker swarm init --advertise-addr 127.0.0.1
```

### Issue: "Secret not found"

```bash
# List existing secrets
docker secret ls

# Check if secret exists
docker secret inspect postgres_password

# Recreate missing secret
./scripts/security/init-secrets.sh
```

### Issue: Services fail to start with secrets

```bash
# Check service logs
docker service logs aixcl_postgres

# Common causes:
# 1. Secret file permissions - should be readable by container user
# 2. Secret format - should not have trailing newlines
# 3. Secret path - verify _FILE env vars point to /run/secrets/
```

### Issue: Cannot view secret values

```bash
# This is by design - Docker secrets are write-only
docker secret inspect postgres_password
# Only shows metadata, not the value

# To verify a secret is working:
docker run --rm -v postgres_password:/secret:ro alpine cat /secret
```

---

## Compliance

### PCI DSS Mapping

| Requirement | Status | Evidence |
|-------------|--------|----------|
| 3.6.1 (Key generation) | ✅ Implemented | /dev/urandom CSPRNG |
| 3.6.2 (Key distribution) | ✅ Implemented | Docker encrypted transport |
| 3.6.3 (Key storage) | ✅ Implemented | Docker encrypted Raft log |
| 3.6.4 (Key rotation) | ✅ Implemented | init-secrets.sh --rotate |
| 8.2.1 (Password complexity) | ✅ Implemented | 32 char random passwords |

### SOC 2 Controls

| Control | Implementation |
|---------|---------------|
| CC6.1 | Secrets encryption at rest and in transit |
| CC6.2 | Access controls on secrets |
| CC6.3 | Secret rotation procedures |
| CC7.2 | Audit logging of secret access |

---

## References

- [Docker Secrets Documentation](https://docs.docker.com/engine/swarm/secrets/)
- [AIXCL Security Architecture](/SECURITY.md)
- [Docker Compose Secrets](https://docs.docker.com/compose/compose-file/09-secrets/)

---

**Document Version**: 1.0  
**Last Updated**: 2026-05-01  
**Owner**: Security Team  
**Review Cycle**: Quarterly
