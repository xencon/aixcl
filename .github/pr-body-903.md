## Summary

Removes stale generated files and dated reports, and updates all documentation to use Agentic terminology instead of AI-Assisted.

Fixes #903

## Changes

### Removed Stale Files
- tests/test-results.md - Generated test output
- tests/opencode-test-results.md - Incomplete test results
- tests/opencode-engine-integration-results.md - Generated results
- tests/comparison-results.md - Generated results
- tests/interactive-opencode-test.md - Generated test doc
- docs/operations/platform-test-report-2026-04-23.md - Dated report
- docs/operations/platform-test-report-consolidated-2026-04-23.md - Dated report
- ENGINE_TEST_RESULTS.md - Historical test data

### Terminology Updates
| File | Change |
|------|--------|
| AGENTS.md | AI assistant -> agentic coding assistant, Safe Areas for AI Contribution -> Safe Areas for Agentic Contribution |
| DEVELOPMENT.md | scope: all agents and AI assistants -> all agents; Agent Compliance section updated |
| docs/developer/development-workflow.md | AI Assistant Instructions -> Agent Instructions |
| docs/architecture/governance/01_ai_guidance.md | Title: AI Guidance -> Agentic Guidance |
| docs/architecture/governance/00_invariants.md | Section 9: AI Assistant Guidance -> Agentic Guidance |
| docs/architecture/governance/GOVERNANCE_COMPLIANCE.md | AI Assistant Guidelines -> Agentic Guidelines |
| docs/architecture/governance/service_contracts/README.md | AI-assisted safe modification -> agentic safe modification |
| ai/README.md | AI Agentic Workflow -> Agentic Workflow |

### Verification
- [x] All stale files removed
- [x] All terminology updated consistently
- [x] Commit follows conventional format
- [x] References issue #903
- [x] PR assigned and labeled
- [x] CI checks passing
