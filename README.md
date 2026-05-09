# AIXCL

**A self-hosted, local-first AI development platform with enterprise security.**

Run Large Language Models locally with HashiCorp Vault, GPG-signed commits, and rootless Podman.

---

## Mandatory Minimum Requirements

| Requirement | Value | Notes |
|-------------|-------|-------|
| **Container Engine** | Podman 4.9+ | Rootless mode required |
| **GPG** | 2.2+ | All commits must be signed |
| **CPU** | 4 cores | 8+ cores recommended |
| **RAM** | 8 GB | 16+ GB for larger models |
| **Disk** | 32 GB | 128+ GB for multiple models |
| **OS** | Linux | Ubuntu 22.04+ tested |

---

## Quick Start (5 minutes)

### Step 1: Install Prerequisites

```bash
# Ubuntu/Debian
sudo apt-get update
sudo apt-get install -y podman gnupg2 git

# Fedora/RHEL
sudo dnf install -y podman gnupg2 git

# Verify installations
podman --version  # Should show 4.9+
gpg --version     # Should show 2.2+
```

### Step 2: Configure Podman Rootless

AIXCL requires rootless Podman. Run the setup script once per machine:

```bash
./scripts/utils/setup-podman-rootless.sh
```

**What this modifies on your local machine:**

| File | Purpose |
|------|---------|
| `~/.bashrc` | Adds `DOCKER_BIN=podman` and `DOCKER_HOST` exports |
| `/etc/subuid` | Configures subordinate UIDs for rootless containers (via sudo) |
| `/etc/subgid` | Configures subordinate GIDs for rootless containers (via sudo) |
| `~/.config/containers/containers.conf` | Podman network and security defaults |
| `~/.config/containers/registries.conf` | Docker Hub search registry |
| `~/.config/containers/storage.conf` | Rootless storage driver settings |
| `.env.podman` (repo root) | Project-specific `DOCKER_HOST` override |

**After setup, reload your shell:**

```bash
source ~/.bashrc
```

**Verify rootless mode:**

```bash
podman info | grep "rootless"
# Should show: "rootless: true"
```

### Step 3: Check, Initialize and Start

The quickest way to get started — add this alias to your shell:

```bash
alias aixcl-setup='./aixcl utils check-env && ./aixcl stack init && ./aixcl stack start --profile sys'
```

Then run:

```bash
aixcl-setup
```

Or run each step manually:

```bash
./aixcl utils check-env          # Verify environment prerequisites
./aixcl stack init               # Generate .env, credentials and Vault secrets (one-time)
./aixcl stack start --profile sys  # Start the full stack

# Wait for healthy status (about 2-3 minutes for full stabilization)
./aixcl stack status
```

Services started (12 in sys profile):

| Category | Service | Port |
|----------|---------|------|
| **Runtime** | Ollama (inference) | 11434 |
| | OpenCode (agent) | Plugin |
| **Persistence** | PostgreSQL | 5432 |
| | pgAdmin | 5050 |
| **Observability** | Prometheus | 9090 |
| | Grafana | 3000 |
| | Loki (logs) | 3100 |
| | cAdvisor (containers) | - |
| | node-exporter (host) | 9100 |
| | postgres-exporter (DB) | 9187 |
| | alertmanager | 9093 |
| | nvidia-gpu-exporter | 9445 |
| **Secrets** | Vault | 8200 |
| **UI** | Open WebUI | 8080 |

### Step 5: Verify Vault (Auto-Initialized)

Vault initializes automatically during stack startup. The process takes 2-3 minutes:

```bash
# Check Vault status
./aixcl vault status

# View generated bootstrap passwords
./aixcl vault passwords
```

### Step 6: Test Inference (Hello World)

**A. Via Open WebUI (Browser)**

**A. Via OpenCode (CLI)**

```bash
# Add a small test model first
./aixcl models add qwen2.5-coder:0.5b
```

1. Open http://localhost:8080 in your browser
2. Log in with username `admin` and the password from `./aixcl vault passwords`
3. Configure the AIXCL endpoint via the admin setting `http://localhost:11434/`
4. Click "New Chat" in the top left
5. Select "qwen2.5-coder:0.5b" from the model dropdown
6. Type: "Hello! Can you confirm you're working?"
7. **Expected:** The model responds with a greeting

**B. Via OpenCode CLI**

```bash
# Add the model (for local provider)
./aixcl models add qwen2.5-coder:0.5b

# Start OpenCode
opencode

# At the prompt, connect to your preferred provider
/connect

# Then type:
# > Hello! Can you help me write a Python function?

# Expected: The AI responds with code suggestions
```

**C. Via API (curl)**

```bash
# Add the model
./aixcl models add qwen2.5-coder:0.5b

# Test via API
curl http://localhost:11434/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{
    "model": "qwen2.5-coder:0.5b",
    "messages": [{"role": "user", "content": "Hello, are you working?"}]
  }'

# Expected output: JSON response with the model's reply
```

**All three methods should show the model responding to your hello!**

---

## Access Points

| Service | URL | Login |
|---------|-----|-------|
| Open WebUI | http://localhost:8080 | Username: `admin`, Password: `./aixcl vault passwords` |
| pgAdmin | http://localhost:5050 | Email: `pgadmin@admin.com`, Password: `./aixcl vault passwords` |
| Grafana | http://localhost:3000 | Username: `admin`, Password: `./aixcl vault passwords` |
| Vault UI | http://localhost:8200 | Token: `VAULT_DEV_TOKEN` env var |
| Prometheus | http://localhost:9090 | No auth (localhost only) |
| Loki | http://localhost:3100 | No auth (localhost only) |
| Alertmanager | http://localhost:9093 | No auth (localhost only) |
| Ollama API | http://localhost:11434 | No auth (localhost only) |

Get current service credentials:
```bash
./aixcl vault credentials
```

---

## Mandatory Workflow

**Every commit must be GPG-signed:**

```bash
# Configure Git (one-time)
git config --global commit.gpgsign true

# Commits are automatically signed
vim some-file.txt
git add some-file.txt
git commit -m "feat: add new feature"  # Automatically signed

# Verify signature
git log --show-signature -1
```

---

## Common Commands

| Task | Command |
|------|---------|
| Check status | `./aixcl stack status` |
| View logs | `./aixcl stack logs` |
| Stop stack | `./aixcl stack stop` |
| Add model | `./aixcl models add <model>` |
| Chat CLI | `opencode` |
| Vault credentials | `./aixcl vault credentials` |
| Rotate credentials | `./aixcl vault rotate` |
| Verify GPG | `gpg --list-secret-keys --keyid-format LONG` |

---

## Security Features (Mandatory)

The following are **not optional** and cannot be disabled:

- ✅ **Podman rootless** - No privileged containers
- ✅ **GPG-signed commits** - All commits to main must be signed (CODEOWNERS only)
- ✅ **HashiCorp Vault** - Dynamic secrets with automatic rotation
- ✅ **PostgreSQL SSL** - Encrypted database connections
- ✅ **Host firewall** - Network isolation at host level

See [SECURITY.md](SECURITY.md) for architecture details.

---

## Troubleshooting

### "GPG signing failed"

```bash
# Re-run setup
./scripts/utils/setup-gpg.sh

# Verify key exists
gpg --list-secret-keys --keyid-format LONG
```

### "Podman not running rootless"

```bash
# Check user namespaces
sysctl kernel.unprivileged_userns_clone

# Should return 1, if not:
echo 'kernel.unprivileged_userns_clone=1' | sudo tee /etc/sysctl.d/99-userns.conf
sudo sysctl --system
```

### "Podman rootless setup failed"

If `./scripts/utils/setup-podman-rootless.sh` fails, check manually:

```bash
# Verify subordinate UIDs/GIDs are configured
grep "^$(whoami):" /etc/subuid
grep "^$(whoami):" /etc/subgid

# If missing, add them manually (requires sudo)
echo "$(whoami):100000:65536" | sudo tee -a /etc/subuid
echo "$(whoami):100000:65536" | sudo tee -a /etc/subgid

# Start the podman socket manually
systemctl --user start podman.socket

# Re-run the setup script
./scripts/utils/setup-podman-rootless.sh
```

### "Vault not initializing"

```bash
# Check Vault status
podman logs vault | tail -20

# Ensure Vault is healthy before init
./aixcl stack status
```

### "Services won't start"

```bash
# Check for port conflicts
sudo lsof -i :11434  # Ollama
sudo lsof -i :8080   # Open WebUI
sudo lsof -i :8200   # Vault

# Soft reset — removes volumes and state, keeps images for fast restart
./aixcl utils prune
aixcl-setup

# Full wipe — removes everything including images (slow rebuild)
./aixcl utils prune --all
aixcl-setup
```

---

## Next Steps

1. **Add more models**: `./aixcl models add qwen2.5-coder:1.5b`
2. **Customize**: Edit `.env` for your environment
3. **Learn**: See [docs/](docs/) for detailed guides
4. **Contribute**: Read [CONTRIBUTING.md](CONTRIBUTING.md)

---

## License

Apache License 2.0
