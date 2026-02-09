# Goose CLI Agent Setup

Goose is a terminal-based AI agent from [Block](https://github.com/block/goose) that connects to local Ollama models and provides shell command execution, MCP server integration, and configurable permission controls.

This complements the Continue plugin by providing a pure terminal experience for AI-assisted development workflows.

## Prerequisites

- Ollama running locally (part of AIXCL runtime core)
- Node.js (for the GitHub MCP server via npx)
- GitHub CLI (`gh`) authenticated
- A GitHub Personal Access Token with `repo` scope

## Installation

Install the Goose CLI:

```bash
curl -fsSL https://github.com/block/goose/releases/download/stable/download_cli.sh | CONFIGURE=false bash
```

Verify the installation:

```bash
goose --version
```

## Configuration

### Goose Global Config

The Goose configuration lives at `~/.config/goose/config.yaml`. The AIXCL setup configures:

- **Provider**: Ollama (local LLM inference)
- **Model**: `qwen2.5:14b-instruct` (or any Ollama model with tool-calling support)
- **Mode**: `smart_approve` (auto-approves reads, prompts for writes)
- **Extensions**:
  - `developer` (built-in) -- shell access, file editing
  - `github` (MCP server) -- structured GitHub API operations

### Setting the GitHub Token

Goose reads the GitHub token from the `GITHUB_TOKEN` environment variable. Set it in your shell profile:

```bash
export GITHUB_TOKEN="ghp_your_token_here"
```

Or use the token from `gh` CLI:

```bash
export GITHUB_TOKEN=$(gh auth token)
```

### Project-Level Configuration

The `.goosehints` file in the project root provides AIXCL-specific guidance to Goose, including:

- Issue-first development workflow
- Label guidelines
- Commit message format
- Architectural invariants

## Usage

### Starting a Session

Navigate to the AIXCL project directory and start a Goose session:

```bash
cd /path/to/aixcl
goose session
```

### Example Workflows

**Create an issue and start working on it:**
```
Create a GitHub issue for fixing the logging format in the CLI,
then create a branch and start implementing the fix.
```

**Review and triage issues:**
```
List all open issues and summarize them by component label.
```

**Create a PR for current changes:**
```
Create a pull request for the current branch referencing issue #123.
```

### Permission Modes

Goose supports four permission modes:

| Mode | Description |
|------|-------------|
| `auto` | Full autonomy -- no confirmation needed |
| `smart_approve` | Auto-approves reads, confirms writes (recommended) |
| `approve` | Confirms all tool usage |
| `chat` | Conversation only, no tool execution |

Change mode mid-session:
```
/mode smart_approve
```

### Adding Extensions Mid-Session

Enable the GitHub extension for a single session:
```bash
goose session --with-extension "GITHUB_PERSONAL_ACCESS_TOKEN=${GITHUB_TOKEN} npx -y @modelcontextprotocol/server-github"
```

## Model Recommendations

For tool-calling workflows (issues, PRs, shell commands), use models with strong function-calling support:

| Model | Tool Calling | Notes |
|-------|-------------|-------|
| `qwen2.5:14b-instruct` | Good | Recommended default |
| `qwen2.5-coder:7b` | Good | Smaller, code-focused |
| `llama3.1:8b` | Limited | Basic tool support |
| `gemma3:12b` | Limited | May struggle with complex tool chains |

Models without tool-calling support can only be used in chat mode (`/mode chat`).

## Updating Goose

```bash
goose update
```

## Troubleshooting

### Ollama Not Reachable

Ensure Ollama is running:
```bash
aixcl start   # starts the AIXCL stack including Ollama
```

Or start Ollama directly:
```bash
ollama serve
```

### GitHub Token Issues

Verify your token has the required scopes:
```bash
gh auth status
```

Required scopes: `repo`, `read:org` (minimum for issue/PR operations).

### Extension Timeout

If the GitHub MCP server times out, increase the timeout in `~/.config/goose/config.yaml`:
```yaml
  github:
    timeout: 600  # 10 minutes
```

## Related Documentation

- [Development Workflow](development-workflow.md) -- Issue-first development process
- [Contributing](contributing.md) -- General contribution guidelines
- [Goose Documentation](https://block.github.io/goose/docs/getting-started/installation) -- Official Goose docs
- [MCP Protocol](https://modelcontextprotocol.io/introduction) -- Model Context Protocol specification
