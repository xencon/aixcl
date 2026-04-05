[![AIXCL](https://github.com/xencon/aixcl/raw/main/AIXCL.png)](https://youtu.be/YaBABt0TsPI)

# AIXCL

**A self-hosted, local-first AI stack for running and integrating LLMs.**

AIXCL is a privacy-focused platform for individuals and teams who want full control over their models. It provides a simple CLI, a web interface, and a containerized stack to run, manage, and integrate Large Language Models directly into your developer workflow.

## Prerequisites

* **Docker & Docker Compose** installed.
* **8 GB VRAM** (minimum recommended).
* **32 GB RAM** (minimum recommended).
* **128 GB Disk Space** (for models and images).

---

## Quick Start

**1. Clone and Verify**

```bash
git clone https://github.com/xencon/aixcl.git && cd aixcl
./aixcl utils check-env
```

> Note: The check will warn if `hf` is missing. Install with pip or brew if you plan to use llama.cpp or vLLM engines.

**2. Start the Stack**

```bash
# Choose a profile: usr (minimal), dev (UI+DB), ops (Observability), sys (Full)
./aixcl stack start --profile usr
```

**3. Choose Your Engine**

```bash
# See available engines
./aixcl engine auto

# Or set manually
./aixcl engine set ollama   # Recommended for beginners
./aixcl engine set vllm     # For high-end GPUs
./aixcl engine set llamacpp  # For GGUF models
```

**4. Add Your First Model**

```bash
# Quick test model (smallest, fastest download)
./aixcl models add qwen2.5-coder:0.5b
```

> See [Quick Test Models](#quick-test-models) for engine-specific options.

**5. Launch OpenCode**

```bash
./opencode
```

---

## Understanding Model Downloads

Models are downloaded on-demand when you run `./aixcl models add`, not during installation. Download times vary based on model size and your connection speed.

### Download Time Estimates

| Model Size | Approximate File Size | Download Time (100 Mbps) | Download Time (20 Mbps) | Download Time (5 Mbps) |
|------------|----------------------|--------------------------|-------------------------|------------------------|
| 0.5B params | ~350-400 MB | ~30 seconds | ~2 minutes | ~5 minutes |
| 1.5B params | ~1 GB | ~1 minute | ~5 minutes | ~15 minutes |
| 7B params | ~4-5 GB | ~5 minutes | ~20 minutes | ~45 minutes |

> **Note:** Times are estimates. Actual speeds depend on network conditions and HuggingFace/Ollama server load.

### Engine-Specific Notes

**vLLM Users:** The vLLM container does not include the `hf` CLI. Models must be pre-downloaded on the host before starting vLLM. See the [vLLM Workaround Guide](docs/operations/vllm-model-download-workaround.md) for details.

**llama.cpp Users:** When switching to llama.cpp from another engine, the model configuration in `opencode.json` is cleared. You must re-add a GGUF model for llama.cpp.

---

## Quick Test Models

These are the smallest viable models for testing your AIXCL setup with OpenCode. **All models below have been tested and verified to work** with the current version of AIXCL.

> **Note:** Using the exact model names shown below ensures compatibility. Other models may work but have not been tested.

### Ollama (Recommended for Beginners)

| Model | Size | Command |
|-------|------|---------|
| Qwen2.5-Coder 0.5B | ~398 MB | `./aixcl models add qwen2.5-coder:0.5b` |

> Ollama models use the format `model:tag`. The `0.5b` tag indicates the smallest variant.
> 
> **✓ Tested:** Successfully tested with OpenCode integration

### vLLM

| Model | Size | Command |
|-------|------|---------|
| Qwen2.5-Coder 0.5B | ~1 GB* | `./aixcl models add Qwen/Qwen2.5-Coder-0.5B-Instruct` |

> *vLLM downloads the full HuggingFace model (safetensors format), which is larger than GGUF.
> 
> **Note:** vLLM container does not include `hf` CLI - see workaround guide.
> 
> **✓ Tested:** Successfully tested with OpenCode integration on RTX 4060

### llama.cpp

| Model | Size | Command |
|-------|------|---------|
| Qwen2.5-Coder 0.5B (Q4_K_M) | ~398 MB | `./aixcl models add Qwen/Qwen2.5-Coder-0.5B-Instruct-GGUF/qwen2.5-coder-0.5b-instruct-q4_k_m.gguf` |

> llama.cpp requires GGUF format models. The format is `username/repo/filename.gguf`.
> 
> **Note:** When switching engines, the model configuration is cleared. Re-add the GGUF model after switching.
> 
> **✓ Tested:** Successfully tested with OpenCode integration

---

## 🛠 Management Examples

### 1. Engine Management

AIXCL supports multiple backends. You can switch them instantly:

```bash
# Auto-detect optimal engine based on your hardware
./aixcl engine auto

# Manually switch to vLLM (Great for high-end GPUs - see notes below)
./aixcl engine set vllm

# Manually switch to llama.cpp (Great for CPU/Apple Silicon)
./aixcl engine set llamacpp

# Restart to apply changes
./aixcl stack restart engine
```

> **vLLM GPU Compatibility:** vLLM requires specific GPU tuning for different cards. If you encounter CUDA errors on startup, the default configuration includes optimizations for RTX 4060 and similar GPUs. For other GPUs, you may need to adjust `--gpu-memory-utilization` and `--max-model-len` in `services/docker-compose.yml`.

> **Engine Testing:** All engines have been tested and validated. See the [Engine Switching Test Plan](docs/operations/engine-switching-test-plan.md) for comprehensive testing details.

### 2. Model Management

Manage your local library across any active engine:

**Ollama Engine:**
```bash
# Add from Ollama Registry (tested model)
./aixcl models add qwen2.5-coder:0.5b

# Add multiple models
./aixcl models add qwen2.5-coder:0.5b llama3.2:3b

# List all local models
./aixcl models list

# Remove a model
./aixcl models remove qwen2.5-coder:0.5b
```

**vLLM Engine:**
```bash
# Add from HuggingFace (full model path) - tested model
./aixcl models add Qwen/Qwen2.5-Coder-0.5B-Instruct

# List downloaded models
./aixcl models list
```

**llama.cpp Engine:**
```bash
# Add GGUF from HuggingFace (requires full path with filename) - tested model
./aixcl models add Qwen/Qwen2.5-Coder-0.5B-Instruct-GGUF/qwen2.5-coder-0.5b-instruct-q4_k_m.gguf

# List GGUF files in volume
./aixcl models list
```

### 3. OpenCode CLI Integration

AIXCL is designed to power local agentic development workflows via the OpenCode CLI. OpenCode connects to your stack for local chat, autocomplete, and agentic coding - all running on-device.

* **Endpoint:** `http://localhost:11434/v1`
* **Start a session:** `./opencode`
* **Setup:** See [OpenCode Setup Guide](https://github.com/xencon/aixcl/blob/main/docs/developer/opencode-setup.md) for full configuration details.

Agent workflow rules and permissions are configured automatically via `opencode.json` and `DEVELOPMENT.md`.

---

## 🚀 Common Commands

| Command | Description |
| --- | --- |
| `./aixcl utils check-env` | Validate environment and dependencies |
| `./aixcl stack status` | Check service health and OpenCode connectivity |
| `./aixcl stack logs engine` | View real-time inference logs |
| `./aixcl stack stop` | Stop all services gracefully |
| `./aixcl utils clean` | Wipe unused containers and volumes (Fresh start) |

---

## 📚 Documentation

* [User Guide](https://github.com/xencon/aixcl/blob/main/docs/user/usage.md) - Detailed workflows and tips.
* [Architecture](https://github.com/xencon/aixcl/blob/main/docs/architecture/governance) - Profiles and service contracts.
* [Security](https://github.com/xencon/aixcl/blob/main/docs/operations/security.md) - Rootless Podman/Docker operations.
* [OpenCode Setup](https://github.com/xencon/aixcl/blob/main/docs/developer/opencode-setup.md) - CLI configuration and agent workflow.
* [Contributing](https://github.com/xencon/aixcl/blob/main/DEVELOPMENT.md) - Issue-first workflow, templates, and PR requirements.

## License

Apache License 2.0 - See [LICENSE](https://github.com/xencon/aixcl/blob/main/LICENSE).
