## Release: Merge dev into main

This PR merges all changes from the `dev` branch into `main` for release.

### Included Changes

#### From PR #904 (Issue #903)
- **Remove stale files and update terminology to Agentic governance**
- Removed 8 generated/dated files from version control
- Updated 9 documentation files with Agentic terminology
- All CI checks passing

#### Previous Merges (Recent)
- PR #899: Cleanup security audit (merged)
- PR #898: Fix workflow inconsistencies (merged)
- PR #877: Fix devcontainer and volume issues (merged)
- Multiple CI improvements and documentation updates

### Verification

- [x] All CI checks passing on dev branch
- [x] Issue #903 completed (stale files removed, terminology updated)
- [x] PR #904 merged into dev
- [x] Agent lint check passing
- [x] No merge conflicts expected

### Changes Summary

| Category | Files Changed |
|----------|---------------|
| Documentation | 9 files updated (Agentic terminology) |
| Removed | 8 stale/generated files |
| CI/CD | Multiple workflow improvements |

### Post-Merge

After this PR is merged:
- `main` will contain the latest stable code
- `dev` remains available for continued development
- Future features should branch from `dev`

---

**Note:** This follows the two-branch workflow (Feature → Dev → Main).
