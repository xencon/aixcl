# OpenCode Integration for AIXCL

OpenCode is the recommended local-first IDE integration for AIXCL. It connects directly to your AIXCL inference engine (Ollama, vLLM, or llama.cpp) to provide AI-powered coding assistance, including chat, autocomplete, and agentic workflows.

## Overview

Unlike other AI tools that rely on cloud backends, OpenCode is designed to be local-first, ensuring that your code and conversations stay within your controlled environment. It is a fundamental part of the AIXCL **Runtime Core**.

## Setup Instructions

### 1. Prerequisite: Start AIXCL

Ensure your AIXCL stack is running and your preferred inference engine is healthy:

```bash
./aixcl stack start --profile dev
./aixcl stack status
```

### 2. Configure OpenCode

OpenCode connects to your AIXCL stack via the OpenAI-compatible API provided by the inference engine (usually on port `11434`).

- **Base URL**: `http://localhost:11434/v1` (or your host IP if running remotely)
- **API Key**: Not required for local AIXCL deployments (use `ollama` or any string if prompted)

### 3. Model Configuration

You can use any model already pulled into your AIXCL engine. For the best experience with OpenCode, we recommend:

```bash
# High-performance coding assistant
./aixcl models add qwen2.5-coder:7b

# Lightweight autocomplete
./aixcl models add qwen2.5-coder:1.5b
```

## Configuration Example

You can use the following configuration as a template for your OpenCode settings (usually found in `~/.opencode/config.json` or your IDE settings). This configuration defines AIXCL as a custom provider and maps local models for use.

```json
{
  "provider": {
    "aixcl-local": {
      "api": "openai",
      "options": {
        "baseURL": "http://localhost:11434/v1",
        "apiKey": "ollama"
      },
      "models": {
        "qwen2.5-coder:7b": {
          "name": "Qwen 2.5 Coder (7B)"
        },
        "qwen2.5-coder:1.5b": {
          "name": "Qwen 2.5 Coder (1.5B)"
        }
      }
    }
  },
  "model": "aixcl-local/qwen2.5-coder:7b",
  "small_model": "aixcl-local/qwen2.5-coder:1.5b"
}
```

## Usage Examples

### 1. Code Explanations
Highlight a block of code in your editor and ask OpenCode:
> "Explain how this function handles error states and suggest improvements for local-first reliability."

### 2. Unit Test Generation
Select a class or function and use the shortcut for test generation:
> "Generate Vitest unit tests for this component, ensuring all edge cases are covered."

### 3. Refactoring
Ask OpenCode to optimize a specific algorithm:
> "Refactor this loop to be more memory-efficient and idiomatic for TypeScript 5.0."

## Features

- **Local Chat**: Interact with your models directly within your editor.
- **Privacy First**: All inference happens on your local AIXCL stack.
- **Agentic Workflows**: Use AIXCL skills and agents directly through the OpenCode interface.

## Troubleshooting

- **Connection Refused**: Ensure the inference engine is running and bound to the correct network interface. Check `./aixcl stack status`.
- **Model Not Found**: Verify the model name exactly matches what is listed in `./aixcl models list`.
