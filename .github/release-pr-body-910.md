## Release: Merge dev into main

This PR merges all changes from the `dev` branch into `main` for release.

### Included Changes

#### From PR #909
- **Add PR validation workflow to enforce formatting standards**
- Automated checks for PR title format, assignee, and labels
- Prevents formatting violations in future PRs

#### From PR #907
- **Add documentation checks and maintenance automation**
- Path validation for markdown references
- Generated file detection
- Lean repository policy documentation

#### From PR #906
- **Documentation checks and maintenance automation**
- Scripts for checking stale artifacts
- Cleanup utilities

### Changes Summary

| Category | Files Changed | Purpose |
|----------|--------------|---------|
| CI Workflows | 2 files | PR validation, documentation checks |
| Scripts | 4 files | Path validation, generated file checks, cleanup |
| Documentation | 3 files | Lean repository policy, path fixes |

### Verification

- [x] All CI checks passing on dev branch
- [x] PR validation workflow tested
- [x] Documentation checks validated
- [x] No merge conflicts

### Post-Merge

After this PR is merged:
- `main` will contain PR validation enforcement
- `main` will have documentation automation
- Future PRs will be validated automatically

---

**Note:** This follows the two-branch workflow (Feature → Dev → Main).
