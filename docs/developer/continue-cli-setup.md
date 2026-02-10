# Continue CLI (cn) with Ollama - Agentic Setup

Continue CLI provides a terminal-based agent (TUI and headless) that uses **Ollama only** (no LLM-Council). This setup targets agentic workflows with tool-capable models.

## Prerequisites

- **Ollama** running and reachable (e.g. AIXCL stack: `./aixcl stack start`).
- Models pulled in Ollama: `qwen3-coder:latest`, `glm-4.7-flash:latest` (or add via `./aixcl models add qwen3-coder:latest glm-4.7-flash:latest`).
- **Node.js 20+** for installing the CLI.

## Install Continue CLI

```bash
# Option A: install script
curl -fsSL https://raw.githubusercontent.com/continuedev/continue/main/extensions/cli/scripts/install.sh | bash

# Option B: npm (Node 20+)
npm i -g @continuedev/cli
```

Verify: `cn --version` and `which cn`.

## Configuration

AIXCL provides an Ollama-only config with agentic models and `tool_use`:

- **Config file:** `.continue/cli-ollama.yaml`
- **Models:** `qwen3-coder:latest`, `glm-4.7-flash:latest` (must exist in Ollama)
- **Agent mode:** Config sets `capabilities: [tool_use]` for both models.

**Important:** Use an **absolute path** for `--config` so the CLI finds the file:

```bash
cn --config /absolute/path/to/aixcl/.continue/cli-ollama.yaml
```

From the AIXCL repo root you can use:

```bash
cn --config "$(pwd)/.continue/cli-ollama.yaml"
```

## Running in agentic mode

- **TUI (interactive):** Tools that modify state (e.g. run commands, write files) prompt for approval. Approve when you want the agent to run `gh` or other commands.

  ```bash
  cn --config "$(pwd)/.continue/cli-ollama.yaml"
  ```

- **Full auto (all tools allowed without asking):**

  ```bash
  cn --config "$(pwd)/.continue/cli-ollama.yaml" --auto
  ```

- **Headless (no TUI):** Use for non-interactive runs. Tools that require confirmation are not available.

  ```bash
  cn --config "$(pwd)/.continue/cli-ollama.yaml" -p "Your prompt"
  ```

## Developer workflow agent

A single agent runs the full AIXCL issue-first workflow (create issue, create branch, commit, push, create PR, assign and label):

- **Agent file:** `.continue/agents/developer-workflow.md`
- **Use:** Run in TUI so you can approve `gh` and `git` tool calls at each step.

From the AIXCL repo root:

```bash
cn --config "$(pwd)/.continue/cli-ollama.yaml" --agent .continue/agents/developer-workflow.md
```

Describe the work you want to do (e.g. "add docs for Continue CLI" or "fix the encoding bug"). The agent will propose an issue (title, body, labels), create it, then on your say-so create the branch, and later help with commit message, PR creation, and PR assign/labels. Approve each tool call when prompted. Set the issue type (Feature/Task/Bug) in the GitHub UI after the issue is created if needed.

## Troubleshooting

- **Config not found:** Use an absolute path for `--config` (e.g. `$(pwd)/.continue/cli-ollama.yaml`).
- **Model not found:** Ensure Ollama is running and the model is pulled: `curl -s http://localhost:11434/api/tags`.
- **No tool use:** Ensure your config includes `capabilities: [tool_use]` for the model and you are not in headless mode if you need interactive tool approval.
- **Agent does not create the issue:** The agent must call the Bash tool to run `gh issue create`. If it only prints the command, the agent instructions may not be followed by the model. Try: (1) Look for a tool approval prompt in the TUI (e.g. "Run this command?") and approve it. (2) Run with `--auto` once to allow all tools without asking and confirm the issue is created (then use without `--auto` for normal use).
- **Verbose logs:** `cn --verbose ...`; logs under `~/.continue/logs/cn.log`.
