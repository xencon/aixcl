---
description: Automates the AIXCL release process end-to-end
agent: agent-context
---

# /release Command

Automates the AIXCL release process from version detection to GitHub Release publication.

## Usage

Run this slash command:
```
/release
```

Or specify version:
```
/release v1.0.0
/release v1.0.0-rc7
/release --dry-run
```

## What It Does

### Phase 1: Version Detection
1. Detects current version from latest git tag
2. Validates semantic versioning format
3. Suggests next version based on CHANGELOG
4. Prompts user for confirmation

### Phase 2: Pre-Release Validation
1. Checks working tree is clean
2. Verifies all CI checks passing
3. Validates CHANGELOG.md has [Unreleased] section
4. Ensures no existing tag for version

### Phase 3: Release Notes Generation
1. Loads template from `ai/templates/release/release_notes.md`
2. Parses CHANGELOG.md [Unreleased] section
3. Auto-populates template sections
4. Presents draft for user review

### Phase 4: CHANGELOG Update
1. Moves [Unreleased] to [vX.Y.Z] - YYYY-MM-DD
2. Adds new [Unreleased] section
3. Commits: `docs: Update CHANGELOG for vX.Y.Z`
4. Pushes to main

### Phase 5: Git Tag Creation
1. Creates annotated tag: `git tag -a vX.Y.Z -m "Release vX.Y.Z"`
2. Pushes tag: `git push origin vX.Y.Z`

### Phase 6: GitHub Release
1. Creates release using `.github/RELEASE_TEMPLATE.md`
2. Populates from CHANGELOG section
3. Publishes release

### Phase 7: Verification
1. Verifies tag exists on remote
2. Verifies release published
3. Verifies CHANGELOG updated
4. Generates workflow report

## State Detection

When `/release` is called without arguments:

```bash
# Latest tag
git describe --tags --abbrev=0

# Unreleased changes
git log $(git describe --tags --abbrev=0)..HEAD --oneline

# CHANGELOG status
grep -A 50 "^## \\[Unreleased\\]" CHANGELOG.md | head -20

# Working tree status
git status --short

# CI status
gh pr checks
```

## Version Detection

| Current | Suggestion | Command |
|---------|-----------|---------|
| v1.0.0-rc6 | v1.0.0-rc7 | `/release` (auto) |
| v1.0.0-rc7 | v1.0.0 | `/release` (auto) |
| v0.9.0 | v0.10.0 or v1.0.0 | Prompt user |

## Dry Run Mode

Preview without making changes:
```
/release --dry-run
```

Shows:
- Version that would be released
- CHANGELOG changes preview
- Commands that would execute
- No actual changes made

## Safety Checks

The command will **halt** if:
- Working tree has uncommitted changes
- CI checks are failing
- Tag already exists
- Not on main branch
- CHANGELOG has no [Unreleased] section

## Examples

### Standard Release
```
/release v1.0.0
```
Creates release v1.0.0 with full workflow.

### Release Candidate
```
/release v1.0.0-rc7
```
Creates RC7, leaves room for RC8 if needed.

### Dry Run
```
/release --dry-run
```
Preview what would happen without executing.

### Interactive Mode
```
/release
```
Detects current state, suggests version, prompts for confirmation.

## Workflow Report

Upon completion, generates visual report:

```
════════════════════════════════════════════════════════════════
  Release v1.0.0 Complete! 🎉
════════════════════════════════════════════════════════════════

Release Steps Completed

| Step | Action | Result |
|------|--------|--------|
| 1. Version Detection | git describe | ✅ v1.0.0 |
| 2. Validation | CI checks | ✅ All passing |
| 3. Notes Generation | Template | ✅ Populated |
| 4. CHANGELOG Update | Commit | ✅ fbdc8dd |
| 5. Tag Creation | git tag | ✅ v1.0.0 |
| 6. GitHub Release | gh release | ✅ Published |
| 7. Verification | Check | ✅ All verified |

Release Details
- Version: v1.0.0
- Tag: https://github.com/xencon/aixcl/releases/tag/v1.0.0
- Release: https://github.com/xencon/aixcl/releases/v1.0.0
- CHANGELOG: Updated

The release is complete and ready for users!
```

## Error Recovery

If any step fails:

**Before tag creation:**
- Reset CHANGELOG: `git checkout CHANGELOG.md`
- Fix issue, re-run `/release`

**After tag creation (before GitHub Release):**
- Delete local tag: `git tag -d vX.Y.Z`
- Delete remote tag: `git push origin :refs/tags/vX.Y.Z`
- Fix issue, re-run `/release`

**After GitHub Release:**
- Edit release on GitHub
- Or delete and recreate (advanced)

## Related

- `/workflow` - Issue-First development workflow
- `/verify` - Check CI status
- `/report` - Workflow progress report
- Templates: `ai/templates/release/release_notes.md`
- Templates: `.github/RELEASE_TEMPLATE.md`
