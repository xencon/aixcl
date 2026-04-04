# AIXCL Scripts

This directory contains essential scripts required by AIXCL and GitHub Actions.

## Structure

```
scripts/
├── checks/           # Validation and compliance checks
│   └── check-agents.sh
└── runtime/          # Container runtime entrypoints
    ├── llamacpp-entrypoint.sh
    └── openwebui.sh
```

## Categories

### checks/
Scripts for validation and compliance checking.

- **check-agents.sh** - Validates AI agents and skills in `ai/` directory for naming conventions and YAML frontmatter compliance.
  - Called by: GitHub Actions (`.github/workflows/check-opencode.yml`)

### runtime/
Docker container entrypoint scripts.

- **llamacpp-entrypoint.sh** - Entrypoint for llama.cpp containers with graceful error handling
  - Called by: `services/docker-compose.yml` (volume mount)
  
- **openwebui.sh** - Sets up Open WebUI with secret generation and admin user
  - Called by: `services/docker-compose.yml` (volume mount)

## Note

Only essential scripts that are actively used by AIXCL or CI/CD workflows are kept here. Standalone utilities and maintenance scripts have been removed per repository maintenance guidelines.

## Usage

```bash
# Check agents compliance (called by CI)
./scripts/checks/check-agents.sh
```

All other scripts are called automatically by Docker Compose or AIXCL.
