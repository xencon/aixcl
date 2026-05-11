# AIXCL Configuration

This directory contains configuration files for AIXCL.

## Structure

```
config/
├── .env.example           # Template for environment variables
├── opencode.json.example  # Template for OpenCode AI configuration
├── README.md              # This file
└── profiles/
    ├── bld.env            # Observability-focused profile
    └── sys.env            # System-oriented profile
```

## Files

### .env.example
Template for environment configuration. Copy this to `.env` in the project root:

```bash
cp config/.env.example .env
```

### opencode.json.example
Template for OpenCode configuration. Defines the AIXCL local provider pointing to the Ollama
OpenAI-compatible endpoint. The live `opencode.json` is gitignored because `./aixcl models add`
writes model entries into it at runtime.

`./aixcl stack init` copies this file to `opencode.json` automatically on first run. To reset
a customised config back to the vanilla state:

```bash
cp config/opencode.json.example opencode.json
```

### profiles/*.env
Profile-specific configuration files. These define the services and settings for each deployment profile.

## Profile Descriptions

| Profile | Description | Services |
|---------|-------------|----------|
| bld | Observability-focused | Inference engine + full monitoring stack |
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
