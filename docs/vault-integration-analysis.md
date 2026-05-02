# Vault Integration Analysis: Moving from Static to Dynamic Secrets

## Executive Summary

**Current State:** All secrets in `.env` file (static, long-lived)  
**Target State:** Vault-managed dynamic credentials (short-lived, auto-rotated)  
**Impact:** SIGNIFICANT - Changes user workflow, deployment process, and operational model  
**Effort:** High (2-3 weeks implementation + testing)

---

## Current Secrets Architecture

### Secrets in `.env`:
```bash
POSTGRES_USER=admin                    # Static username
POSTGRES_PASSWORD=admin               # Static password (indefinite lifetime)
PGADMIN_PASSWORD=admin                 # Static password
OPENWEBUI_PASSWORD=admin               # Static password
GRAFANA_ADMIN_USER=admin              # Static (commented out)
GRAFANA_ADMIN_PASSWORD=admin           # Static (commented out)
```

### Problems:
1. **Long-lived credentials** - Never expire, high blast radius if leaked
2. **Plaintext storage** - In `.env` file, version controlled risk
3. **No audit trail** - Who used what when?
4. **No rotation** - Manual process, error-prone
5. **Shared credentials** - Multiple services use same credentials
6. **No least-privilege** - admin/admin has full access

---

## Vault-Based Architecture

### What Vault Provides:
1. **Dynamic credentials** - Generated on-demand, TTL-based (e.g., 1 hour)
2. **Automatic rotation** - No manual intervention
3. **Audit logging** - Every secret access logged
4. **Short-lived** - Reduces blast radius
5. **Role-based** - Different credentials for different services
6. **No plaintext** - Secrets never written to disk (in production)

### New Architecture Flow:

```
┌─────────────────┐     ┌─────────────────┐     ┌─────────────────┐
│   Open WebUI    │────▶│   Vault Agent   │────▶│     Vault       │
│                 │     │   (sidecar)     │     │   (secrets)     │
└─────────────────┘     └─────────────────┘     └─────────────────┘
         │                                               │
         │                                               │
         │         ┌─────────────────┐                   │
         └────────▶│   PostgreSQL    │◀────────────────┘
                   │                 │
                   │  ┌─────────────┐│
                   │  │ Dynamic     ││
                   │  │ Credentials ││
                   │  └─────────────┘│
                   └─────────────────┘
```

### User Experience Comparison:

| Aspect | Current (.env) | Future (Vault) |
|--------|---------------|----------------|
| **First setup** | Copy `.env.example` → `.env`, edit values | Run Vault init, configure policies |
| **Starting stack** | `./aixcl stack start` | `./aixcl stack start` (Vault auto-initializes) |
| **Getting credentials** | `cat .env` | `vault read database/creds/...` |
| **Password rotation** | Manual edit + restart | Automatic (every hour) |
| **Adding new service** | Edit `.env` + restart | Configure Vault role + policy |
| **Debugging DB** | Use static admin/admin | Generate temporary admin credentials |
| **Backup/Restore** | Backup `.env` file | Backup Vault storage + policies |
| **Multi-user** | Everyone shares same `.env` | Individual Vault tokens with policies |

---

## Implementation Phases

### Phase 1: Vault Infrastructure (Week 1)

**1.1 Deploy Vault**
- ✅ Already in `docker-compose.vault.yml`
- Running in dev mode (auto-unseal)

**1.2 Initialize Vault**
```bash
# One-time setup
./scripts/vault/init-vault.sh
```

This creates:
- Database secrets engine
- PostgreSQL connection config
- Two roles: `aixcl-app` (1h TTL), `aixcl-admin` (15m TTL)
- AppRole authentication for services
- Audit logging

**1.3 Verify Vault**
```bash
vault status
vault read database/creds/aixcl-app
```

### Phase 2: Service Integration (Week 1-2)

**2.1 PostgreSQL Service Changes**

Current:
```yaml
postgres:
  environment:
    POSTGRES_USER: admin
    POSTGRES_PASSWORD: admin
```

Future:
```yaml
postgres:
  environment:
    POSTGRES_USER_FILE: /run/secrets/db-username
    POSTGRES_PASSWORD_FILE: /run/secrets/db-password
  volumes:
    - /run/secrets:/run/secrets:ro
```

**2.2 Open WebUI Integration**

Needs Vault Agent sidecar:
```yaml
open-webui:
  volumes:
    - /run/secrets:/run/secrets:ro
  environment:
    DATABASE_URL_FILE: /run/secrets/database-url

vault-agent-webui:
  image: hashicorp/vault:1.18
  volumes:
    - /run/secrets:/run/secrets
    - ./vault/agent-webui.hcl:/etc/vault/agent.hcl:ro
  command: agent -config=/etc/vault/agent.hcl
```

**2.3 PostgreSQL Exporter**

Current:
```yaml
environment:
  DATA_SOURCE_NAME: "postgresql://admin:admin@..."
```

Future:
- Needs Vault Agent to write credentials to file
- Read from file on container start

**2.4 pgAdmin**

pgAdmin stores connection info in its own database. Options:
1. Mount credentials file, configure pgAdmin to read it
2. Use pgAdmin's native credential management
3. Keep static credentials just for pgAdmin (admin access only)

### Phase 3: Secretless Operation (Week 2-3)

**3.1 Remove from `.env`**
```bash
# Remove:
POSTGRES_USER=admin
POSTGRES_PASSWORD=admin
PGADMIN_PASSWORD=admin
# Keep non-secrets only:
POSTGRES_DATABASE=webui
```

**3.2 Update CLI**
```bash
# Add Vault status check
./aixcl vault status
./aixcl vault credentials  # Get temp DB credentials
./aixcl vault rotate        # Force rotation
```

**3.3 Documentation**
- Update README with Vault workflow
- Add troubleshooting guide
- Document AppRole setup for new services

---

## Critical User Experience Changes

### 🔴 BREAKING CHANGES

**1. First-Time Setup**

Before:
```bash
git clone ...
cp .env.example .env
# Edit .env with passwords
./aixcl stack start
```

After:
```bash
git clone ...
./aixcl vault init  # One-time Vault setup
./aixcl stack start
# Vault auto-initializes on first run
```

**2. Database Access for Debugging**

Before:
```bash
psql -U admin -d webui -h localhost
# Password: admin (from .env)
```

After:
```bash
# Get dynamic credentials
./aixcl vault credentials
# Returns:
#   Username: v-token-aixcl-app-xxxxxxxx
#   Password: xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxx
#   TTL: 59m

psql -U v-token-aixcl-app-xxxxxxxx -d webui -h localhost
# Enter temp password
```

**3. Password Rotation**

Before:
```bash
# Manual process
vim .env  # Change password
./aixcl stack restart postgres
# Update all services using that password
```

After:
```bash
# Automatic - happens every hour
# Or force immediate rotation:
./aixcl vault rotate postgres
```

### 🟡 WORKFLOW CHANGES

**4. Backup Strategy**

Before:
```bash
tar czf backup.tar.gz .env data/
```

After:
```bash
# Backup Vault storage (encrypted)
tar czf backup.tar.gz vault-data/ data/
# Also backup policies:
vault policy list > vault-policies-backup.txt
```

**5. Disaster Recovery**

Before:
- Restore `.env` file
- Start services

After:
- Restore Vault storage
- Unseal Vault (if not using auto-unseal)
- Verify policies
- Services auto-reconnect

**6. Adding New Service**

Before:
```bash
# Add to docker-compose.yml
# Add to .env
# Restart
```

After:
```bash
# Add to docker-compose.yml
# Create Vault role:
vault write database/roles/new-service ...
# Create policy:
vault policy write new-service ...
# Configure Vault Agent sidecar
# Restart
```

---

## Technical Challenges

### Challenge 1: Rootless Podman + Vault Agent

**Problem:** Vault Agent needs to write credentials to `/run/secrets` which must be shared between containers

**Solution:**
- Use tmpfs volume shared between service and agent
- In rootless mode, this works within user namespace

```yaml
volumes:
  - type: tmpfs
    target: /run/secrets
    tmpfs:
      size: 1M
```

### Challenge 2: Credential Rotation Timing

**Problem:** What happens when credentials expire mid-transaction?

**Solutions:**
1. **Graceful rotation:** Vault Agent sends HUP signal, service reloads
2. **Connection pooling:** Use short-lived connections (already in PostgreSQL)
3. **Retry logic:** Services should retry on auth failure
4. **Overlapping TTLs:** New credentials generated before old expire

### Challenge 3: Bootstrap Problem

**Problem:** PostgreSQL needs credentials to start, but Vault needs PostgreSQL to be running to configure database engine

**Solution:**
1. Start PostgreSQL with bootstrap credentials (from env file or Kubernetes secret)
2. Initialize Vault
3. Configure database engine with bootstrap credentials
4. Future restarts use Vault credentials

**Alternative:** Use Vault's `static-roles` for bootstrap then migrate to dynamic

### Challenge 4: pgAdmin Integration

**Problem:** pgAdmin stores connection configuration internally

**Options:**
1. **Static credentials:** Keep pgAdmin using static admin credentials (admin only)
2. **Credential sync:** Script to update pgAdmin config when Vault credentials rotate
3. **pgAgent:** Use pgAdmin's background agent to handle connections

**Recommendation:** Option 1 - pgAdmin is admin-only, static is acceptable

### Challenge 5: Development vs Production

**Current:** Dev mode Vault (auto-unseal, in-memory)

**Production:** Real Vault (manual seal/unseal, HA, Raft storage)

**Implications:**
- Different initialization paths
- Dev: `./aixcl vault init` (automated)
- Prod: Manual unseal with Shamir keys
- Need profile-based configuration

---

## Security Benefits (Why Do This?)

### 1. Blast Radius Reduction
- **Before:** One password compromise = full database access indefinitely
- **After:** Credential compromise valid for only 1 hour

### 2. Audit Trail
- **Before:** No logs of who used what password
- **After:** Every credential generation logged in Vault audit log

### 3. No Credential Sprawl
- **Before:** Password in `.env`, logs, backups, CI/CD
- **After:** Credentials never leave Vault (except to service memory)

### 4. Automatic Compliance
- **Before:** Manual rotation, easy to forget
- **After:** Automatic rotation every hour

### 5. Least Privilege
- **Before:** All services use admin/admin
- **After:** Each service gets scoped credentials (SELECT only, etc.)

---

## Migration Strategy

### Option A: Big Bang (Not Recommended)
- Stop everything
- Configure Vault
- Update all services
- Start everything
- **Risk:** High - one problem breaks everything

### Option B: Gradual (Recommended)

**Phase 1: Parallel Deployment**
- Keep `.env` working
- Add Vault alongside
- Services can use either
- Test Vault path

**Phase 2: Service-by-Service**
1. PostgreSQL exporter (low risk)
2. Open WebUI (medium risk)
3. pgAdmin (optional - keep static)
4. Remove `.env` secrets

**Phase 3: Cleanup**
- Remove `.env` secrets
- Update documentation
- Train users

### Option C: Hybrid (Pragmatic)
- Keep static credentials for:
  - Initial PostgreSQL bootstrap
  - pgAdmin (admin tool)
  - Emergency access
- Use dynamic for:
  - Application services
  - Automated exporters
  - CI/CD pipelines

**Recommendation:** Option C - Gets security benefits quickly without breaking workflows

---

## Implementation Checklist

### Prerequisites
- [ ] Vault container tested in rootless Podman
- [ ] Vault persistence verified (external volume)
- [ ] Network connectivity (host mode working)

### Phase 1: Infrastructure
- [ ] Deploy Vault service
- [ ] Initialize Vault (`./scripts/vault/init-vault.sh`)
- [ ] Configure database secrets engine
- [ ] Create roles (app, admin)
- [ ] Create policies
- [ ] Enable AppRole auth
- [ ] Test credential generation

### Phase 2: Service Migration
- [ ] PostgreSQL exporter with Vault Agent
- [ ] Open WebUI with Vault Agent
- [ ] Configure credential file mounts
- [ ] Test credential rotation
- [ ] Handle rotation edge cases

### Phase 3: User Experience
- [ ] Update `./aixcl` CLI with vault commands
- [ ] Create `vault credentials` command
- [ ] Create `vault rotate` command
- [ ] Update README
- [ ] Add troubleshooting guide

### Phase 4: Cleanup
- [ ] Remove secrets from `.env`
- [ ] Update `.env.example`
- [ ] Add `.env` to `.gitignore` (if not already)
- [ ] Document migration path

---

## Questions to Resolve

1. **Should we keep `.env` for non-secret config?**
   - Yes - database name, ports, etc. still useful

2. **What happens if Vault goes down?**
   - Services continue with cached credentials
   - New services can't start
   - Need Vault HA for production

3. **How do we debug database issues?**
   - Provide `./aixcl vault debug-db` command
   - Generates temporary admin credentials
   - Logs access for audit

4. **What about local development vs CI/CD?**
   - Local: Vault in dev mode
   - CI/CD: Vault in dev mode or static credentials
   - Production: Real Vault deployment

5. **How do we backup/restore?**
   - Backup Vault storage volume
   - Backup policies and roles
   - Document restore procedure

---

## Recommendation

**Start with Option C (Hybrid):**

1. **Week 1:** Deploy Vault, configure PostgreSQL engine, test credential generation
2. **Week 2:** Migrate PostgreSQL exporter to Vault (low-risk)
3. **Week 3:** Migrate Open WebUI to Vault (higher usage)
4. **Week 4:** Keep pgAdmin on static, remove `.env` secrets, update docs

**Benefits:**
- Gets security improvements quickly
- Doesn't break development workflow
- Allows gradual learning/adoption
- Can roll back if issues

**Risks:**
- More complex architecture to maintain
- Learning curve for developers
- Potential service disruption during migration
- Debugging becomes harder (dynamic credentials)

**Alternative:**
Keep static credentials but:
1. Add `.env` to `.gitignore`
2. Document credential rotation procedure
3. Use PostgreSQL roles (read-only for apps)
4. Add audit logging

This is 80% of the security benefit with 20% of the complexity.

---

**Your thoughts? Should we proceed with Vault integration or simplify approach?**
