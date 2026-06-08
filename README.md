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

## Quick Start

### Step 1: Install Prerequisites

**Container Engine (choose one):**

```bash
# Podman (recommended -- primary engine)
sudo apt-get update
sudo apt-get install -y podman podman-compose

# Docker (fallback -- optional)
sudo apt-get install -y docker.io docker-compose-v2
```

**Required tools:**

```bash
sudo apt-get install -y git gnupg2 gh
```

**Verify:**

```bash
podman --version    # Should show 4.9+
gpg --version       # Should show 2.2+
gh --version        # Should show 2.x+
```

**Contributors only -- CI tools:**

```bash
# yamllint (available via apt)
sudo apt-get install -y yamllint

# ShellCheck 0.11.0+ (apt package 0.9.0 is too old -- use GitHub releases)
curl -sSL https://github.com/koalaman/shellcheck/releases/download/v0.11.0/shellcheck-v0.11.0.linux.x86_64.tar.xz | tar -xJ -C /tmp
sudo cp /tmp/shellcheck-v0.11.0/shellcheck /usr/local/bin/shellcheck
```

> **VM users (QEMU/SLIRP networking):** If image pulls fail mid-download, add the following to `/etc/docker/daemon.json` to work around MTU limitations:
> ```json
> {"dns": ["8.8.8.8", "8.8.4.4"], "mtu": 1400, "max-concurrent-downloads": 1}
> ```
> Then restart Docker: `sudo systemctl restart docker`

### Step 2: Clone and Initialise

```bash
git clone https://github.com/xencon/aixcl.git
cd aixcl
./aixcl stack init
```

`stack init` automatically:
- Detects and configures Podman (rootless) or Docker
- Adds `docker=podman` alias and `DOCKER_HOST` to `~/.bashrc`
- Creates `.env` from `config/.env.example`
- Creates `opencode.json` from `config/opencode.json.example`
- Initialises all external Docker/Podman volumes
- Prompts for admin username and email

After init, reload your shell:

```bash
source ~/.bashrc
```

### Step 3: Start the Stack

```bash
./aixcl stack start --profile sys
```

This pulls images, starts all services, initialises Vault, and generates bootstrap credentials. Allow 3-5 minutes for full startup on first run.

Check status:

```bash
./aixcl stack status
```

**Important:** Vault auto-seals whenever its container restarts (e.g. after `./aixcl stack stop` or host reboot). If services fail to start, unseal Vault first:

```bash
# Unseal Vault after every stack restart
./aixcl vault unseal

# Wait 30 seconds for bootstrap agents, then verify
./aixcl stack status
```

### Step 5: Test Inference (Hello World)

### Step 4: View Credentials

```bash
./aixcl vault passwords
```

### Step 5: Add a Model and Test Inference

```bash
./aixcl models add qwen2.5-coder:0.5b
```

Test via API:

```bash
curl http://localhost:11434/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{"model": "qwen2.5-coder:0.5b", "messages": [{"role": "user", "content": "Hello, are you working?"}]}'
```

## Access Points

| Service | URL | Login |
|---------|-----|-------|
| Open WebUI | http://localhost:8080 | Username: `admin`, Password: `./aixcl vault passwords` |
| pgAdmin | http://localhost:5050 | Email: `admin@example.com`, Password: `./aixcl vault passwords` |
| Grafana | http://localhost:3000 | Username: `admin`, Password: `./aixcl vault passwords` |
| Vault UI | http://localhost:8200 | Token: `VAULT_DEV_TOKEN` env var |
| Prometheus | http://localhost:9090 | No auth (localhost only) |
| Loki | http://localhost:3100 | API only -- use Grafana for log browsing |
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
| Install bash completion | `./aixcl utils bash-completion` |
| Full clean removal | `./aixcl utils prune --all` |

---

## Security Features (Mandatory)

The following are **not optional** and cannot be disabled:

- - [x] **Podman rootless** - No privileged containers
- - [x] **GPG-signed commits** - All commits to main must be signed (CODEOWNERS only)
- - [x] **HashiCorp Vault** - Dynamic secrets with automatic rotation
- - [x] **PostgreSQL SSL** - Encrypted database connections
- - [x] **Host firewall** - Network isolation at host level

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

# Soft reset -- removes volumes and state, keeps images for fast restart
./aixcl utils prune
aixcl-setup

# Full wipe -- removes everything including images (slow rebuild)
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
