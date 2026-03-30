# OpenCode Integration for AIXCL

OpenCode is the recommended local-first CLI integration for AIXCL. It connects directly to your
AIXCL inference engine (Ollama, vLLM, or llama.cpp) to provide AI-powered coding assistance,
including chat, autocomplete, and agentic workflows — entirely on-device.

## Overview

Unlike other AI tools that rely on cloud backends, OpenCode is a local-first CLI tool, ensuring
that your code and conversations stay within your controlled environment. It is a fundamental part
of the AIXCL **Runtime Core**.

Agent workflow rules, permissions, and governance are loaded automatically at session start from
`AGENTS.md` and `DEVELOPMENT.md` via the `instructions` field in `opencode.json`. No manual
context loading is required.

---

## Setup Instructions

### 1. Prerequisite: Start AIXCL

Ensure your AIXCL stack is running and your preferred inference engine is healthy:

```bash
./aixcl stack start --profile dev
./aixcl stack status
```

### 2. Start OpenCode

From the repo root:

```bash
./opencode
```

OpenCode will connect to the AIXCL local provider defined in `opencode.json` and load the
governance and workflow rules automatically.

### 3. Model Configuration

You can use any model already pulled into your AIXCL engine. For the best experience with
OpenCode, we recommend:

```bash
# High-performance coding assistant
./aixcl models add qwen2.5-coder:7b

# Lightweight option
./aixcl models add qwen2.5-coder:1.5b
```

---

## Configuration Reference

The `opencode.json` file at the repo root configures the AIXCL provider, auto-loads governance
documents, and sets agent permissions. The full structure is:

```json
{
  "$schema": "https://opencode.ai/config.json",

  "instructions": [
    "AGENTS.md",
    "DEVELOPMENT.md"
  ],

  "permission": {
    "bash": {
      "*":              "ask",
      "git status":     "allow",
      "git diff *":     "allow",
      "git log *":      "allow",
      "git add *":      "allow",
      "git commit *":   "ask",
      "git push *":     "deny",
      "grep *":         "allow",
      "cat *":          "allow",
      "ls *":           "allow",
      "gh issue *":     "allow",
      "gh pr create *": "ask",
      "gh pr edit *":   "ask",
      "./aixcl *":      "ask"
    },
    "edit":     "ask",
    "webfetch": "ask"
  },

  "provider": {
    "aixcl-local": {
      "api": "openai",
      "options": {
        "baseURL": "http://localhost:11434/v1",
        "apiKey": "",
        "stream": false
      },
      "models": {
        "Qwen/Qwen2.5-Coder-1.5B-Instruct": {
          "name": "vLLM: Qwen 2.5 Coder (1.5B)"
        },
        "qwen2.5-coder:1.5b": {
          "name": "Ollama: Qwen 2.5 Coder (1.5B)"
        },
        "qwen2.5-coder-1.5b-instruct-q4_k_m.gguf": {
          "name": "llama.cpp: Qwen 2.5 Coder (1.5B)"
        },
        "Qwen/Qwen2.5-Coder-0.5B-Instruct": {
          "name": "Qwen/Qwen2.5-Coder-0.5B-Instruct"
        }
      }
    }
  },

  "model": "aixcl-local/qwen2.5-coder-1.5b-instruct-q4_k_m.gguf"
}
```

### Instructions

The `instructions` field loads `AGENTS.md` and `DEVELOPMENT.md` at every session start. This
gives the agent the full authority hierarchy, security model, issue templates, and PR workflow
without any manual prompting.

### Permissions

Permissions follow a last-matching-rule-wins pattern. The default posture is:

| Operation | Permission |
|---|---|
| Read-only git commands (`status`, `diff`, `log`) | `allow` |
| Read-only shell commands (`grep`, `cat`, `ls`) | `allow` |
| `git add` | `allow` |
| `git commit`, PR creation, file edits | `ask` |
| `git push` | `deny` |
| `./aixcl *` stack commands | `ask` |
| Everything else | `ask` |

`git push` is denied outright — the local model cannot push to the remote without a human
explicitly overriding the permission in `opencode.json`.

---

## Extending OpenCode

Custom slash commands and agents can be added to the repo without modifying `opencode.json`:

- **Custom commands:** `.opencode/commands/<name>.md`
- **Custom agents:** `.opencode/agents/<name>.md`

---

## Usage Examples

### Code explanation

```
> Explain how this function handles error states and suggest improvements.
```

### Test generation

```
> Generate tests for this function covering all edge cases.
```

### Refactoring

```
> Refactor this to be more idiomatic shell — avoid subshells where possible.
```

---

## Troubleshooting

**Connection refused** — Ensure the inference engine is running and bound to the correct
interface. Check with `./aixcl stack status`.

**Model not found** — Verify the model name exactly matches the output of `./aixcl models list`.

**Agent not following workflow rules** — Confirm `AGENTS.md` and `DEVELOPMENT.md` are present at
the repo root and listed in the `instructions` field of `opencode.json`.
