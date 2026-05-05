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

### Step 2: Configure GPG (Maintainers Only)

**Note:** GPG signing is required for CODEOWNERS pushing to main/dev branches. Contributors using fork+PR workflow do not need GPG.

**For CODEOWNERS:**

```bash
# Generate GPG key (if you don't have one)
gpg --full-generate-key

# List your keys
gpg --list-secret-keys --keyid-format LONG

# Configure Git to sign commits
git config --global commit.gpgsign true
git config --global user.signingkey YOUR_KEY_ID

# Export public key for GitHub
gpg --armor --export YOUR_KEY_ID
# Copy output and add to GitHub Settings → SSH and GPG keys
```

### Step 3: Verify Podman

```bash
# Check Podman version
podman --version

# Verify rootless mode is working
podman info | grep "rootless"
# Should show: "rootless: true"

# If rootless is not enabled, see Troubleshooting section below
```

### Step 4: Initialize the Stack

```bash
# Generate .env file and admin credentials (one-time setup)
./aixcl stack init

# Start with system profile (includes all services)
./aixcl stack start --profile sys

# Wait for healthy status (about 60 seconds)
./aixcl stack status
```

Services started:
- **Ollama** on port 11434 (inference API)
- **PostgreSQL** on port 5432 (database)
- **Open WebUI** on port 8080 (chat interface)
- **Vault** on port 8200 (secrets management)
- **Grafana** on port 3000 (monitoring)

### Step 5: Verify Vault (Auto-Initialized)

Vault initializes automatically when the stack starts. No manual steps required.

```bash
# Check Vault status
./aixcl vault status

# Or access Vault UI at http://localhost:8200
# Token: aixcl-dev-token
```

### Step 6: Test Inference (Hello World)

**A. Via Open WebUI (Browser)**

```bash
# Add a small test model first
./aixcl models add qwen2.5-coder:0.5b
```

1. Open http://localhost:8080 in your browser
2. Click "Get Started" to create an account (first user becomes admin)
3. Click "New Chat" in the top left
4. Select "qwen2.5-coder:0.5b" from the model dropdown
5. Type: "Hello! Can you confirm you're working?"
6. **Expected:** The model responds with a greeting

**B. Via OpenCode CLI**

```bash
# Add the model
./aixcl models add qwen2.5-coder:0.5b

# Start OpenCode
opencode

# At the prompt, type:
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
| Open WebUI | http://localhost:8080 | First user = admin |
| Grafana | http://localhost:3000 | admin/admin |
| Vault UI | http://localhost:8200 | Token: aixcl-dev-token |
| Ollama API | http://localhost:11434 | No auth (localhost only) |

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
- ✅ **GPG-signed commits** - All commits to main/dev must be signed
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

# Clean restart
./aixcl stack stop
./aixcl utils clean
./aixcl stack start --profile sys
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
