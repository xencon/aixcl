# HashiCorp Vault Integration

**Phase 3** | Centralized Dynamic Secrets Management

## Overview

Vault provides **dynamic, short-lived credentials** for AIXCL services, replacing static Docker secrets with credentials that:
- Exist only for a limited time (TTL)
- Auto-rotate without service restart
- Have complete audit logging
- Can be instantly revoked

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

### 2. Verify Initialization

Wait 2-3 minutes for stabilization, then check status:

```bash
./aixcl vault status
./aixcl vault passwords
```

### 3. Test Dynamic Credentials

```bash
# Generate app credentials
vault read database/creds/aixcl-app

# Generate admin credentials (maintenance)
vault read database/creds/aixcl-admin
```

### 4. View Audit Logs

```bash
# See all credential access
vault audit list

# View audit log
vault read sys/audit
```

## Dynamic Roles

### aixcl-app (Application Credentials)

- **Purpose**: Regular application connections
- **Permissions**: SELECT, INSERT, UPDATE, DELETE on all tables
- **TTL**: 1 hour (auto-rotates)
- **Max TTL**: 24 hours

### aixcl-admin (Maintenance Credentials)

- **Purpose**: Schema migrations, maintenance
- **Permissions**: ALL PRIVILEGES
- **TTL**: 15 minutes
- **Max TTL**: 1 hour

## Security Benefits

### Before (Docker Secrets)
```
❌ Static password in environment
❌ Manual rotation required
❌ No audit of credential usage
❌ Long-lived credentials
```

### After (Vault Dynamic Secrets)
```
✅ Credentials exist only 1 hour
✅ Automatic rotation every TTL
✅ Every access logged with user/timestamp
✅ Instant revocation capability
✅ No static passwords in config
```

## Production Hardening

### Required Before Production

1. **Disable Dev Mode**
   ```bash
   # Production requires:
   # - TLS encryption
   # - Auto-unseal (AWS KMS, Azure Key Vault, etc.)
   # - HA cluster (3+ nodes)
   # - Sealed startup
   ```

2. **Enable TLS**
   ```hcl
   listener "tcp" {
     tls_cert_file = "/vault/tls/vault.crt"
     tls_key_file  = "/vault/tls/vault.key"
   }
   ```

3. **Configure Auto-Unseal**
   ```hcl
   seal "awskms" {
     region     = "us-east-1"
     kms_key_id = "alias/vault-unseal"
   }
   ```

4. **Enable Audit Device**
   ```bash
   vault audit enable file file_path=/var/log/vault/audit.log
   ```

## Monitoring

### Health Checks

```bash
# Vault status
vault status

# Database connection health
vault read database/creds/aixcl-app

# Audit log health
vault audit list
```

### Key Metrics

- **Credential generation rate**: Should match service connections
- **Failed authentication**: Watch for brute force attempts
- **Lease expiration**: Ensure auto-rotation working
- **Audit log growth**: Plan log rotation

## Troubleshooting

### Vault Won't Start

```bash
# Check logs
podman logs vault

# Verify unsealed
vault status

# Check PostgreSQL connection
vault read database/config/postgresql
```

### Credentials Not Rotating

```bash
# Check lease list
vault list sys/leases/lookup/database/creds/aixcl-app

# Verify TTL
vault read database/roles/aixcl-app

# Force rotation
vault lease revoke -prefix database/creds/aixcl-app
```

### Service Can't Connect

```bash
# Test credential generation
vault read database/creds/aixcl-app

# Check PostgreSQL logs
podman logs postgres

# Verify network connectivity
vault read database/config/postgresql
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

- **CC6.1**: Encryption at rest and in transit
- **CC6.2**: Access controls via policies
- **CC7.2**: Audit trail of all credential access
- **CC8.1**: Change management for credential rotation

## Migration from Docker Secrets

### Current (Phase 2)
```yaml
environment:
  POSTGRES_PASSWORD_FILE: /run/secrets/postgres_password
```

### Target (Phase 3)
```yaml
volumes:
  - /run/secrets/database-creds:/run/secrets/database-creds:ro
```

### Migration Steps

1. Deploy Vault alongside existing services
2. Initialize Vault with init-vault.sh
3. Test dynamic credentials
4. Update services to use Vault Agent
5. Gradual rollout (canary deployment)
6. Remove Docker secrets after validation

## References

- [Vault PostgreSQL Database Secrets Engine](https://developer.hashicorp.com/vault/docs/secrets/databases/postgresql)
- [Vault AppRole Authentication](https://developer.hashicorp.com/vault/docs/auth/approle)
- [Vault Agent with Auto-Auth](https://developer.hashicorp.com/vault/docs/agent/autoauth)
- [SECURITY.md Phase 3 Roadmap](/SECURITY.md)

---

**Status**: Development Mode (not production ready)  
**Next**: TLS, Auto-unseal, HA cluster
