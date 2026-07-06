# Service Contract -- OpenCode

**Category:** Supported AI Coding Client
**Enforcement Level:** Advisory

## Purpose

Developer-facing AI interaction layer. OpenCode is a terminal-based (TUI) AI coding agent that connects to the Inference Engine via the OpenAI-compatible API for AI-powered code assistance.

AIXCL is client-agnostic above the API layer. OpenCode is one documented client; other MCP-compatible or OpenAI-API-compatible clients (e.g. Claude Code, Cursor) are equally valid. This contract documents how OpenCode integrates, not that it is required.

## Depends On

- Inference Engine (via OpenAI-compatible API)

## Exposes

- Terminal (TUI) interface for AI-powered code assistance
- Developer interaction layer (agents, commands, and skills under `.opencode/`)

## Must Not Depend On

- Monitoring, logging, automation

## Configuration

Client configuration lives in `.opencode/` (agents, rules, skills). Mirror parity with `.claude/` is maintained so governance rules apply consistently across supported clients.
