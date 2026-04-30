# AIXCL Branch Workflow Policy
## Strict Compliance Guidelines

### Effective Immediately: All Changes via PR

#### Main Branch
- ❌ NO direct pushes allowed
- ✅ ALL changes must go through Pull Request
- ✅ Requires 1 approving review
- ✅ Requires CODEOWNERS review (@sbadakhc)
- ✅ All status checks must pass
- ✅ Use squash merge for clean history

#### Dev Branch  
- ❌ NO direct pushes allowed
- ✅ ALL changes must go through Pull Request
- ✅ Requires CODEOWNERS review
- ✅ All status checks must pass
- ✅ Can use regular merge (preserves dev history)

### Emergency Procedures

If bypass is absolutely necessary:
1. Document reason in commit message: "[EMERGENCY] Brief explanation"
2. Create retrospective issue explaining the bypass
3. Return to PR workflow immediately after

### Sync Workflow (Main <-> Dev)

To sync main changes to dev:
```bash
# Create PR from main to dev
gh pr create --base dev --head main --title "Sync main into dev"
# Merge via PR (not direct push)
```

To promote dev to main:
```bash
# Create PR from dev to main
gh pr create --base main --head dev --title "Release X.Y.Z"
# Merge via PR with squash
```

### Current Status Acknowledgment

As of v1.0.0 release:
- Main and dev branches were directly pushed for release
- This was an exception due to release timing
- Going forward: ZERO exceptions without documented emergency justification

### Enforcement

Branch protection rules are active:
- Ruleset: main (active)
- Ruleset: dev (active)
- CODEOWNERS: @sbadakhc
- Required reviews: 1 (main), CODEOWNERS (both)

Last updated: 2026-04-30
