---
name: reviewing-skills
description: >
  Review and audit SKILL.md files against authoring best practices and AIXCL
  repository conventions. Use when asked to review, audit, lint, or improve a
  skill, when a SKILL.md is shared for feedback, or before merging a PR that
  adds or changes a skill. Triggers on "review this skill", "audit skills",
  "lint SKILL.md", "skill feedback".
argument-hint: <skill name, SKILL.md path, or 'all'>
compatibility: OpenCode, Claude Code
metadata:
  category: maintenance
  version: "1.0"
---

# Skill Reviewer

Review SKILL.md files against authoring best practices and produce a structured
report with actionable findings. Report only -- do not edit skills unless
directed after the report.

**Full best-practices reference**: [references/best-practices.md](references/best-practices.md)
(complete authoring guide with examples and rationale).

## Review workflow

Copy this checklist and track progress:

```
Review Progress:
- [ ] Step 1: Read the SKILL.md and all referenced files
- [ ] Step 2: Evaluate metadata (name, description)
- [ ] Step 3: Evaluate content quality
- [ ] Step 4: Evaluate structure and architecture
- [ ] Step 5: Evaluate AIXCL repository conventions
- [ ] Step 6: Evaluate code and scripts (if present)
- [ ] Step 7: Produce the review report
```

### Step 1: Read the skill

Read the target SKILL.md in full, then every file it references (one level
deep). Note:

- Total line count of the SKILL.md body (max 500 lines)
- Total file size of the SKILL.md file (max 5KB)
- Number and names of referenced files
- Whether any references are nested (file A -> file B -> file C)

### Step 2: Evaluate metadata

Check YAML frontmatter: `name` (max 64 chars, lowercase/hyphens, matches the
directory name, no "anthropic"/"claude"). `description` (non-empty, max 1024
chars, states what the skill does AND when to use it, includes concrete
trigger phrases, third person voice).

### Step 3: Evaluate content quality

- **Conciseness**: Flag paragraphs explaining things the model already knows.
  Each paragraph should justify its token cost.
- **Terminology consistency**: Flag mixed synonyms for the same concept.
- **Time-sensitive info**: Flag date-bound instructions; suggest the
  "current method / old patterns" structure instead.
- **Degrees of freedom**: For each instruction block, check the freedom level
  (high/medium/low) matches the task fragility. Flag mismatches -- vague text
  for fragile operations, rigid scripts for subjective judgment.
- **Too many options**: Flag 3+ alternative tools/approaches without a clear
  default. Pick one default; mention alternatives only as escape hatches.
- **Examples**: For output-quality-sensitive tasks, check input/output
  examples exist.

### Step 4: Evaluate structure and architecture

- **Line count**: body under 500 lines; flag if over.
- **Progressive disclosure**: content beyond quick-start belongs in separate
  files referenced from SKILL.md. Flag monolithic files that should split.
- **Reference depth**: references one level deep only. Flag A -> B -> C chains.
- **Long reference files**: files over 100 lines need a table of contents.
- **File naming**: descriptive names, forward slashes only.
- **Workflows**: multi-step tasks need clear sequential steps; complex
  workflows need a copy-paste checklist.
- **Feedback loops**: quality-critical operations need a
  validate -> fix -> repeat loop.

### Step 5: Evaluate AIXCL repository conventions

- **ASCII only**: no smart quotes, em dashes, ellipsis characters, or other
  non-ASCII (CI enforces this on all markdown).
- **LF line endings**: no CRLF.
- **Mirror parity**: the skill exists byte-identical in both
  `.claude/skills/<name>/` and `.opencode/skills/<name>/`
  (verify: `./aixcl checks agents`).
- **Frontmatter house style**: `compatibility` and `metadata.category`/
  `metadata.version` fields present; version bumped when behavior changes.
- **Tool references**: commands referenced must exist in this repository
  (`./aixcl`, `gh`, `git`, `shellcheck`, `podman`). Flag references to tools
  or MCP servers the repo does not have.

### Step 6: Evaluate code and scripts (if present)

Skip if no executable code. Check: explicit error handling (not punting to the
model), no magic numbers, dependencies declared with install commands, clear
execute-vs-read intent, plan-validate-execute for batch or destructive
operations.

### Step 7: Produce the review report

Use the exact template and FAIL/WARN/PASS rating criteria in
[references/report-template.md](references/report-template.md).

### Step 8: Re-review after fixes

If fixes are applied, re-run the relevant evaluation steps (2-6) and update
the report. Mark resolved findings as FIXED.
