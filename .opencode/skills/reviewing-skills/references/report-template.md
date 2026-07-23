# Review report template and rating criteria

## Report template

Use this exact template:

```markdown
# Skill Review: `{skill-name}`

## Summary

{One sentence: overall quality assessment}

| Category        | Rating                     |
| --------------- | -------------------------- |
| Metadata        | {PASS / WARN / FAIL}       |
| Content quality | {PASS / WARN / FAIL}       |
| Structure       | {PASS / WARN / FAIL}       |
| Code & scripts  | {PASS / WARN / FAIL / N/A} |

## Findings

### {FAIL / WARN}: {Short title}

**What**: {Describe the issue}
**Where**: {File and line/section}
**Why it matters**: {Impact on Claude's behavior}
**Fix**: {Specific actionable fix}

{Repeat for each finding, ordered FAIL first, then WARN}

## What's working well

- {Bullet points for things done right -- keep brief}
```

## Rating criteria

- **FAIL**: Violates a hard rule (invalid name, missing description trigger, nested references 2+ deep, backslash paths, over 500 lines with no splitting, bigger than 5KB file size).
- **WARN**: Suboptimal but functional (verbose explanations, missing examples, inconsistent terminology, no feedback loop for quality-critical tasks).
- **PASS**: Meets or exceeds best practices.

## Rendering the report

The template above stays plain ASCII text -- this file and every skill file
are emoji-free by convention. When you actually present the report live,
render each Category's Rating as a colored indicator alongside the text
(green for PASS, yellow for WARN, red for FAIL) for readability; the color
exists only in what you render to the user, never in a committed file.
