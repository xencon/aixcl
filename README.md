[![AIXCL](https://github.com/xencon/aixcl/raw/main/AIXCL.png)](https://youtu.be/YaBABt0TsPI)

# AIXCL

**A self-hosted, local-first AI stack for running and integrating LLMs.**

AIXCL is a privacy-focused platform for individuals and teams who want full control over their models. It provides a simple CLI, a web interface, and a containerized stack to run, manage, and integrate Large Language Models directly into your developer workflow.

## Prerequisites

* **Docker & Docker Compose** installed.
* **8 GB VRAM** (minimum recommended).
* **32 GB RAM** (minimum recommended).
* **128 GB Disk Space** (for models and images).

## Get Started in 3 Steps

**1. Clone and Verify**

```
git clone https://github.com/xencon/aixcl.git && cd aixcl
./aixcl utils check-env
```

**2. Start the Stack**

```
# Choose a profile: usr (minimal), dev (UI+DB), ops (Observability), sys (Full)
./aixcl stack start --profile usr
```

**3. Choose your engine**

```
./aixcl models config engine set ollama
```

**4. Add your first model**

```
./aixcl models add qwen2.5-coder:7b
```

**5. Prompt the model with OpenCode**

```
./opencode
```

---

## 🛠 Management Examples

### 1. Engine Management

AIXCL supports multiple backends. You can switch them instantly:

```
# Auto-detect optimal engine based on your hardware
./aixcl config engine auto

# Manually switch to vLLM (Great for high-end GPUs)
./aixcl config engine set vllm

# Manually switch to llama.cpp (Great for CPU/Apple Silicon)
./aixcl config engine set llamacpp

# Restart to apply changes
./aixcl stack restart engine
```

### 2. Model Management

Manage your local library across any active engine:

```
# Add from Ollama Registry
./aixcl models add llama3.2:3b

# Add directly from Hugging Face (GGUF)
./aixcl models add hf.co/bartowski/Llama-3.2-1B-Instruct-GGUF:Q4_K_M

# List all local models
./aixcl models list

# Remove a model
./aixcl models remove llama3.2:3b
```

### 3. OpenCode CLI Integration

AIXCL is designed to power local agentic development workflows via the OpenCode CLI. OpenCode connects to your stack for local chat, autocomplete, and agentic coding — all running on-device.

* **Endpoint:** `http://localhost:11434/v1`
* **Start a session:** `./opencode`
* **Setup:** See [OpenCode Setup Guide](https://github.com/xencon/aixcl/blob/main/docs/developer/opencode-setup.md) for full configuration details.

Agent workflow rules and permissions are configured automatically via `opencode.json` and `DEVELOPMENT.md`.

---

## 🚀 Common Commands

| Command | Description |
| --- | --- |
| `./aixcl stack status` | Check service health and OpenCode connectivity |
| `./aixcl stack logs engine` | View real-time inference logs |
| `./aixcl stack stop` | Stop all services gracefully |
| `./aixcl stack clean` | Wipe unused containers and volumes (Fresh start) |

---

## 📚 Documentation

* [User Guide](https://github.com/xencon/aixcl/blob/main/docs/user/usage.md) - Detailed workflows and tips.
* [Architecture](https://github.com/xencon/aixcl/blob/main/docs/architecture/governance) - Profiles and service contracts.
* [Security](https://github.com/xencon/aixcl/blob/main/docs/operations/security.md) - Rootless Podman/Docker operations.
* [OpenCode Setup](https://github.com/xencon/aixcl/blob/main/docs/developer/opencode-setup.md) - CLI configuration and agent workflow.
* [Contributing](https://github.com/xencon/aixcl/blob/main/DEVELOPMENT.md) - Issue-first workflow, templates, and PR requirements.

## License

Apache License 2.0 - See [LICENSE](https://github.com/xencon/aixcl/blob/main/LICENSE).
