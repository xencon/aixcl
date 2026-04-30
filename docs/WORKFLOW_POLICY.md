# AIXCL Branch Workflow Policy
## Two-Branch Development Strategy

### Branch Purpose

| Branch | Purpose | When to Use |
|--------|---------|-------------|
| **dev** | Active development, feature integration | Create feature branches from here |
| **main** | Production-ready code, releases | Only merge tested features from dev |

### Correct Workflow (REQUIRED)

```
Feature Branch → Dev → Main
      ↑            ↑       ↑
   create        PR      PR
   from         merge   merge
   dev          (test)  (final test)
```

#### Step-by-Step Process

1. **Create feature branch FROM dev:**
   ```bash
   git checkout dev
   git pull origin dev
   git checkout -b issue-<number>/<description>
   ```

2. **Develop and quick test:**
   - Make changes
   - Test locally/quickly
   - Commit with conventional format

3. **Create PR to dev:**
   ```bash
   git push -u origin issue-<number>/<description>
   gh pr create --base dev --title "Description (#<issue>)"
   ```

4. **Merge to dev after review:**
   - Requires CODEOWNERS review
   - All checks must pass
   - Use regular merge (preserves history)

5. **Create PR from dev to main:**
   ```bash
   gh pr create --base main --head dev --title "Release description"
   ```

6. **Final testing on PR to main:**
   - More comprehensive testing
   - All checks must pass
   - Requires 1 review + CODEOWNERS

7. **Merge to main:**
   - Use squash merge for clean history
   - Tag releases from main

### Branch Rules

#### Main Branch (Protected)
- ❌ NO direct pushes
- ✅ PR from dev only
- ✅ Requires 1 approving review
- ✅ Requires CODEOWNERS review (@sbadakhc)
- ✅ All status checks must pass
- ✅ Use **squash merge**

#### Dev Branch (Protected)
- ❌ NO direct pushes
- ✅ PR from feature branches only
- ✅ Requires CODEOWNERS review
- ✅ All status checks must pass
- ✅ Use **regular merge** (preserves feature history)

### ❌ INCORRECT Workflows

**DON'T: Merge feature directly to main**
```
feature → main  ❌ WRONG
```

**DON'T: Create feature from main**
```
main → feature → dev  ❌ WRONG
```

**DON'T: Sync main back to dev via PR**
```
main → dev  ❌ WRONG (dev should feed main, not vice versa)
```

### Emergency Procedures

If bypass is absolutely necessary:
1. Document reason: `[EMERGENCY] Brief explanation`
2. Create retrospective issue
3. Return to PR workflow immediately

### Historical Context

**v1.0.0 Release Issues:**
- Initial releases merged features directly to main
- Created circular sync problems
- Workflow policy established post-v1.0.0 to prevent recurrence

**Corrected as of:** Workflow policy update

### Enforcement

Branch protection active:
- Ruleset: main (active) - PR required
- Ruleset: dev (active) - PR required
- CODEOWNERS: @sbadakhc

---

**Last updated:** 2026-04-30
**Version:** 2.0 (corrected two-branch workflow)
