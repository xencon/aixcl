# AIXCL Configuration

This directory contains configuration files for AIXCL.

## Structure

```
config/
├── .env.example           # Template for environment variables
├── README.md              # This file
└── profiles/
    ├── usr.env            # User-oriented runtime profile
    ├── dev.env            # Developer workstation profile
    ├── ops.env            # Observability-focused profile
    └── sys.env            # System-oriented profile
```

## Files

### .env.example
Template for environment configuration. Copy this to `.env` in the project root:

```bash
cp config/.env.example .env
```

### profiles/*.env
Profile-specific configuration files. These define the services and settings for each deployment profile.

## Profile Descriptions

| Profile | Description | Services |
|---------|-------------|----------|
| usr | User-oriented runtime (minimal footprint) | Inference engine + PostgreSQL |
| dev | Developer workstation | Inference engine + UI + DB + pgAdmin |
| ops | Observability-focused | Inference engine + full monitoring stack |
| sys | System-oriented | Complete stack with automation |

## Usage

The main `.env` file in the project root is used for:
- Inference engine selection (ollama, vllm, llamacpp)
- Database credentials
- API keys and secrets
- Default profile selection

Profile configurations in `profiles/` are used for:
- Service composition
- Profile-specific settings
- Default models per profile
