# Dependency Version Pinning Audit

This document identifies all software dependencies and containers in the project, and indicates which have pinned versions and which do not.

## Summary

- **Python Dependencies**: Partially pinned (minimum versions specified, but not exact)
- **Node.js Dependencies**: Not pinned (using caret ranges)
- **Docker Containers**: Mostly unpinned (using `:latest` tags)
- **Base Images**: Partially pinned
- **GitHub Actions**: Partially pinned
- **System Dependencies**: Not pinned

---

## 1. Python Dependencies

### 1.1 `llm-council/pyproject.toml`
**Status**: ⚠️ **NOT FULLY PINNED** (using minimum version constraints)

| Dependency | Current | Status |
|------------|---------|--------|
| fastapi | `>=0.115.0` | ❌ Not pinned |
| uvicorn[standard] | `>=0.32.0` | ❌ Not pinned |
| python-dotenv | `>=1.0.0` | ❌ Not pinned |
| httpx | `>=0.27.0` | ❌ Not pinned |
| pydantic | `>=2.9.0` | ❌ Not pinned |
| asyncpg | `>=0.29.0` | ❌ Not pinned |

**Note**: `uv.lock` file exists and contains exact pinned versions, but `pyproject.toml` should also specify exact versions for reproducibility.

### 1.2 `requirements.txt`
**Status**: ✅ **FULLY PINNED**

| Dependency | Version | Status |
|------------|---------|--------|
| cffi | `==2.0.0` | ✅ Pinned |
| cryptography | `==46.0.3` | ✅ Pinned |
| numpy | `==2.3.5` | ✅ Pinned |
| pybind11 | `==3.0.1` | ✅ Pinned |
| pycparser | `==2.23` | ✅ Pinned |
| wheel | `==0.45.1` | ✅ Pinned |

### 1.3 Python Base Image
**File**: `llm-council/Dockerfile`
- **Base Image**: `python:3.11-slim`
- **Status**: ⚠️ **NOT FULLY PINNED** (should specify exact patch version like `python:3.11.9-slim`)

### 1.4 Python Package Manager (uv)
**File**: `llm-council/Dockerfile`
- **Installation**: `pip install --no-cache-dir uv`
- **Status**: ❌ **NOT PINNED** (should specify exact version)

---

## 2. Node.js Dependencies

### 2.1 `llm-council/frontend/package.json`
**Status**: ❌ **NOT PINNED** (using caret ranges `^`)

| Dependency | Current | Status |
|------------|---------|--------|
| react | `^19.2.0` | ❌ Not pinned |
| react-dom | `^19.2.0` | ❌ Not pinned |
| react-markdown | `^10.1.0` | ❌ Not pinned |
| @eslint/js | `^9.39.1` | ❌ Not pinned |
| @types/react | `^19.2.5` | ❌ Not pinned |
| @types/react-dom | `^19.2.3` | ❌ Not pinned |
| @vitejs/plugin-react | `^5.1.1` | ❌ Not pinned |
| eslint | `^9.39.1` | ❌ Not pinned |
| eslint-plugin-react-hooks | `^7.0.1` | ❌ Not pinned |
| eslint-plugin-react-refresh | `^0.4.24` | ❌ Not pinned |
| globals | `^16.5.0` | ❌ Not pinned |
| vite | `^7.2.4` | ❌ Not pinned |

**Note**: `package-lock.json` exists and contains exact versions, but `package.json` should also specify exact versions.

### 2.2 Node.js Base Image
**Status**: N/A (frontend runs via npm/vite, not in Docker)

---

## 3. Docker Container Images

### 3.1 `docker-compose.yml`

| Service | Image | Current Tag | Status |
|---------|-------|-------------|--------|
| ollama | `ollama/ollama` | `:latest` | ❌ Not pinned |
| open-webui | `ghcr.io/open-webui/open-webui` | `:latest` | ❌ Not pinned |
| postgres | `postgres` | `:17` | ⚠️ Partially pinned (major version only) |
| pgadmin | `dpage/pgadmin4` | `:9.0` | ⚠️ Partially pinned (minor version only) |
| watchtower | `containrrr/watchtower` | (no tag) | ❌ Not pinned (defaults to `:latest`) |
| prometheus | `prom/prometheus` | `:latest` | ❌ Not pinned |
| grafana | `grafana/grafana` | `:latest` | ❌ Not pinned |
| cadvisor | `gcr.io/cadvisor/cadvisor` | `:latest` | ❌ Not pinned |
| node-exporter | `prom/node-exporter` | `:latest` | ❌ Not pinned |
| postgres-exporter | `prometheuscommunity/postgres-exporter` | `:latest` | ❌ Not pinned |
| nvidia-gpu-exporter | `nvcr.io/nvidia/k8s/dcgm-exporter` | `:3.3.5-3.4.0-ubuntu22.04` | ✅ Fully pinned |
| loki | `grafana/loki` | `:latest` | ❌ Not pinned |
| promtail | `grafana/promtail` | `:latest` | ❌ Not pinned |

### 3.2 System Dependencies in Dockerfile
**File**: `llm-council/Dockerfile`
- **Status**: ❌ **NOT PINNED**
- Packages installed via `apt-get` without version specification:
  - `git` (no version)
  - `curl` (no version)
  - `build-essential` (no version)

---

## 4. GitHub Actions

### 4.1 `.github/workflows/bash-ci.yml`

| Action/Component | Current | Status |
|------------------|---------|--------|
| actions/checkout | `@v6` | ✅ Pinned |
| Docker | Installed via apt (latest) | ❌ Not pinned |
| Docker Compose | Dynamic (fetches latest) | ❌ Not pinned |
| System packages | No versions specified | ❌ Not pinned |

**Issue**: Line 40 fetches Docker Compose version dynamically:
```bash
DOCKER_COMPOSE_VERSION=$(curl -s https://api.github.com/repos/docker/compose/releases/latest | jq -r '.tag_name')
```

---

## 5. Summary by Category

### ✅ Fully Pinned
- `requirements.txt` (Python packages)
- `nvidia-gpu-exporter` container image
- `actions/checkout@v6` in GitHub Actions

### ⚠️ Partially Pinned
- `postgres:17` (major version only)
- `pgadmin4:9.0` (minor version only)
- `python:3.11-slim` (minor version only)
- `pyproject.toml` (minimum versions, but lock file has exact versions)
- `package.json` (caret ranges, but lock file has exact versions)

### ❌ Not Pinned
- Most Docker container images (using `:latest`)
- Node.js dependencies in `package.json` (using `^` ranges)
- Python dependencies in `pyproject.toml` (using `>=` ranges)
- System packages in Dockerfile (apt-get without versions)
- `uv` package manager installation
- Docker and Docker Compose in CI/CD
- System packages in GitHub Actions

---

## 6. Recommendations

1. **Pin all Docker images** to specific version tags (e.g., `postgres:17.2` instead of `postgres:17`)
2. **Pin Python dependencies** in `pyproject.toml` to exact versions (use `==` instead of `>=`)
3. **Pin Node.js dependencies** in `package.json` to exact versions (remove `^` prefix)
4. **Pin base images** to specific patch versions (e.g., `python:3.11.9-slim`)
5. **Pin system packages** in Dockerfile using specific versions
6. **Pin `uv` package manager** to a specific version
7. **Pin Docker Compose version** in GitHub Actions workflow
8. **Pin system packages** in GitHub Actions workflow

---

## 7. Files Requiring Updates

1. `llm-council/pyproject.toml` - Change `>=` to `==` for all dependencies
2. `llm-council/frontend/package.json` - Remove `^` prefix from all dependencies
3. `llm-council/Dockerfile` - Pin Python base image and system packages
4. `docker-compose.yml` - Replace all `:latest` tags with specific versions
5. `.github/workflows/bash-ci.yml` - Pin Docker Compose version

