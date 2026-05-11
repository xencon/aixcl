# HashiCorp Vault Integration

**Phase 3** | Centralized Dynamic Secrets Management

## Overview

Vault provides **dynamic, short-lived credentials** for AIXCL services, replacing static Docker secrets with credentials that:
- Exist only for a limited time (TTL)
- Auto-rotate without service restart
- Have complete audit logging
- Can be instantly revoked

Vault runs in **production server mode** with file-based persistent storage. Secrets survive container restarts. Unseal keys are GPG-encrypted and stored in `.security/` (gitignored).

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                      AIXCL Stack                           │
│  ┌──────────────┐    ┌──────────────┐    ┌──────────────┐   │
│  │   Services   │────│ Vault Agent  │────│    Vault     │   │
│  │ (PostgreSQL) │    │  (sidecar)   │    │   Server     │   │
│  │  (Grafana)   │    └──────────────┘    └──────────────┘   │
│  └──────────────┘                            │              │
│                                              │              │
│                              ┌───────────────┴──────────┐   │
│                              ▼                          │   │
│                       ┌──────────────┐                  │   │
│                       │  PostgreSQL  │                  │   │
│                       │ (Dynamic     │                  │   │
│                       │  Creds)      │                  │   │
│                       └──────────────┘                  │   │
│                                                         │   │
│  ┌────────────────────────────────────────────────┐    │   │
│  │ Audit Log: Every credential access logged       │    │   │
│  └────────────────────────────────────────────────┘    │   │
└─────────────────────────────────────────────────────────────┘
```

## Dynamic Secrets Flow

1. **Service needs DB credentials** → Requests from Vault Agent
2. **Vault generates new credentials** → Creates PostgreSQL user with random password
3. **Service uses credentials** → Connects to database
4. **TTL expires** → Vault automatically revokes PostgreSQL user
5. **New credentials generated** → Seamless rotation

## Quick Start

### 1. Start the Stack

Vault is included in the `sys` profile and auto-initializes during stack startup:

```bash
./aixcl stack start --profile sys
```

On first start, Vault is initialized and unsealed automatically. Unseal keys and the root token are GPG-encrypted to `.security/`.

### 2. Unseal After Restart

After a stack restart, Vault starts sealed. `stack start` auto-unseals using your GPG key. If your GPG key is not cached in the agent, unseal manually:

```bash
./aixcl vault unseal
```

### 3. Verify Status

```bash
./aixcl vault status
./aixcl vault passwords
```

### 4. Test Dynamic Credentials

```bash
# Generate app credentials
./aixcl vault credentials

# Or via Vault CLI directly (requires VAULT_TOKEN set)
vault read database/creds/aixcl-app
```

### 5. View Logs

```bash
./aixcl vault logs
```

## Dynamic Roles

### aixcl-app (Application Credentials)

- **Purpose**: Regular application connections (Open WebUI)
- **Permissions**: USAGE/CREATE on public schema; SELECT, INSERT, UPDATE, DELETE on all tables
- **TTL**: 1 hour (auto-rotates)
- **Max TTL**: 24 hours
- **Revocation**: `REASSIGN OWNED BY` + `DROP OWNED BY` + `DROP ROLE` -- handles roles that own tables

### aixcl-admin (Maintenance Credentials)

- **Purpose**: Schema migrations, maintenance
- **Permissions**: ALL PRIVILEGES
- **TTL**: 15 minutes
- **Max TTL**: 1 hour

## Unseal Key Management

Vault uses a **5-of-5 Shamir key split with a 3-of-5 unseal threshold**. On first init:

1. `vault operator init` generates 5 key shares and a root token
2. Both are GPG-encrypted with your git signing key and written to `.security/`:
   - `.security/vault-keys.gpg` -- encrypted JSON with all 5 key shares
   - `.security/vault-root-token.gpg` -- encrypted root token
3. Vault is immediately unsealed using shares 1, 2, and 3

The `.security/` directory is gitignored, mode 700, files mode 600.

**Critical**: Loss of all key shares means permanent loss of all Vault data. Back up your GPG private key and `.security/vault-keys.gpg` to a secure offline location.

For full key management guidance see [SECURITY.md -- Vault Unseal Key Management](/SECURITY.md).

## Security Benefits

### Before (Docker Secrets)
```
Static password in environment
Manual rotation required
No audit of credential usage
Long-lived credentials
```

### After (Vault Dynamic Secrets)
```
Credentials exist only 1 hour
Automatic rotation every TTL
Every access logged with user/timestamp
Instant revocation capability
No static passwords in config
```

## Monitoring

### Health Checks

```bash
# Vault seal/unseal status
./aixcl vault status

# Database connection health
./aixcl vault credentials

# View recent logs
./aixcl vault logs 50
```

### Key Metrics

- **Credential generation rate**: Should match service connections
- **Failed authentication**: Watch for brute force attempts
- **Lease expiration**: Ensure auto-rotation working
- **Audit log growth**: Plan log rotation

## Troubleshooting

### Vault Won't Start / Keeps Shutting Down

The most common cause is expired dynamic leases from a prior session. Vault attempts to revoke them on unseal and shuts down if revocation fails (SQLSTATE 2BP01 -- role owns objects).

**Diagnosis**:
```bash
podman logs vault 2>&1 | grep -E "ERROR|shutdown"
```

**Fix**: Delete stale lease files before unsealing, then drop orphaned postgres roles:
```bash
# Delete stale lease files (vault must be sealed)
podman exec vault rm -rf /vault/file/sys/expire/id/database

# Drop orphaned roles (enable trust auth temporarily if needed)
podman exec postgres psql -U admin -d webui -c \
  'REASSIGN OWNED BY "v-root-..."; DROP OWNED BY "v-root-..."; DROP ROLE "v-root-...";'

# Unseal
./aixcl vault unseal
```

### Vault Sealed After Stack Restart

```bash
./aixcl vault unseal
```

If GPG decryption fails ("Is your GPG key available?"), check:
```bash
gpg --list-secret-keys
```

### Credentials Not Rotating

```bash
# Check lease list
vault list sys/leases/lookup/database/creds/aixcl-app

# Verify TTL on role
vault read database/roles/aixcl-app

# Force rotation
vault lease revoke -prefix database/creds/aixcl-app
```

### Service Can't Connect (postgres auth failed)

The Vault database config may have a stale password. Re-run init to sync:

```bash
./aixcl vault init
```

This always re-POSTs the current PostgreSQL password to the database engine.

### Vault Logs

```bash
# Last 50 lines
./aixcl vault logs 50

# Follow live
podman logs -f vault
```

## Compliance

### PCI DSS

| Requirement | Vault Implementation |
|-------------|---------------------|
| 8.2.4 | Dynamic credentials (1h TTL) |
| 10.2.1 | Audit logs (who accessed what) |
| 8.2.5 | No shared accounts (each service gets unique creds) |
| 8.2.6 | Unique IDs for each credential |

### SOC 2

- **CC6.1**: Encryption at rest (GPG-encrypted unseal keys) and in transit
- **CC6.2**: Access controls via policies
- **CC7.2**: Audit trail of all credential access
- **CC8.1**: Change management for credential rotation

## References

- [Vault PostgreSQL Database Secrets Engine](https://developer.hashicorp.com/vault/docs/secrets/databases/postgresql)
- [Vault AppRole Authentication](https://developer.hashicorp.com/vault/docs/auth/approle)
- [Vault Agent with Auto-Auth](https://developer.hashicorp.com/vault/docs/agent/autoauth)
- [SECURITY.md -- Vault Unseal Key Management](/SECURITY.md)

---

**Status**: Production mode (persistent file storage, GPG-encrypted unseal keys)
**Storage**: `aixcl-vault-data` volume (survives container restarts)
**Unseal**: GPG-encrypted key shares in `.security/vault-keys.gpg`
