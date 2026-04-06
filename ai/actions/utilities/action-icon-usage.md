---
name: Icon Usage Guidelines
description: Guidelines for using icons, emojis, and special characters in the AIXCL repository
category: style
tool: none
requires:
  - Understanding of ASCII vs Unicode
---

# Action: Icon Usage Guidelines

Guidelines for using icons, emojis, and special characters in the AIXCL repository.

## Rule: Use ASCII Only

**AIXCL uses plain ASCII text to avoid encoding issues across platforms.**

## DO: Use These

- **Markdown checkboxes**: `- [ ]` and `- [x]`
- **Standard ASCII**: A-Z, a-z, 0-9, punctuation
- **Markdown syntax**: `**bold**`, `*italic*`, `` `code` ``
- **Standard arrows**: `->`, `<-`, `<--`, `-->`

## DON'T: Use These

- **Unicode checkmarks**: ✓, ✔, ✕ (use `- [x]` instead)
- **Emoji**: 👍, 🔥, ⚠️ (not allowed in technical docs)
- **Smart quotes**: “ ” ‘ ’ (use `"` and `'`)
- **Em dash**: — (use `--` or `---`)
- **En dash**: – (use `-`)
- **Ellipsis**: … (use `...`)
- **Special arrows**: →, ←, ⇒ (use `->`, `<-`)

## Why This Matters

1. **Cross-platform compatibility** - Different OS/terminals render Unicode differently
2. **Git diff clarity** - Unicode can appear garbled in diffs
3. **Searchability** - ASCII is easier to grep/search
4. **Simplicity** - No ambiguity about character encoding

## Examples

**Good:**
```markdown
- [x] Complete task 1
- [ ] Complete task 2

**Note:** This is important.

Use `--flag` for options.
```

**Bad:**
```markdown
✓ Complete task 1
○ Complete task 2

⚠️ Warning: This is important.

Use —flag for options.
```

## Verification

Before committing:
- [ ] No Unicode checkmarks
- [ ] No emoji in technical documentation
- [ ] Standard ASCII quotes only
- [ ] Plain hyphens for dashes

## Tools

**Check for Unicode in a file:**
```bash
# Find non-ASCII characters
grep -n '[^\x00-\x7F]' filename.md

# Find specific Unicode ranges
grep -n '[\u2018\u2019\u201c\u201d]' filename.md
```

**Convert to ASCII:**
```bash
# Replace smart quotes with straight quotes
sed -i "s/[\u2018\u2019]/'/g" filename.md
sed -i 's/[\u201c\u201d]/"/g' filename.md
```
