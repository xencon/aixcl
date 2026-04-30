## Summary

Add automated checks to prevent documentation drift and stale file accumulation, implementing a lean repository philosophy.

Fixes #906

## Changes

### New GitHub Workflow
- `.github/workflows/documentation-checks.yml` - Runs on PR/push to dev/main
  - Markdown link validation
  - Path existence verification  
  - Generated file detection
  - YAML syntax validation
  - Docker Compose file validation

### New Scripts
- `scripts/checks/check-paths.sh` - Validates markdown references and file paths
- `scripts/checks/check-generated-files.sh` - Detects committed generated files
- `scripts/utils/cleanup-stale-artifacts.sh` - Automated cleanup of stale files

### Documentation Updates
- `AGENTS.md` - Added Lean Repository Policy section
- `docs/reference/consistency-gap-report-2026.md` - Updated to DELETE not archive

## Lean Repository Policy

The repository now follows a lean philosophy:
- **Delete, Don't Archive** - Outdated reports are deleted, not archived
- **Fresh Information Only** - Operations reports < 30 days old
- **Generated Files Stay Generated** - No committed test outputs or logs
- **Historical data in Git history** - Not in working tree

## Verification

- [x] All scripts executable
- [x] check-paths.sh validates markdown references
- [x] check-generated-files.sh detects stale files
- [x] cleanup script supports --dry-run
- [x] CI workflow syntax validated
- [x] Lean repository policy documented in AGENTS.md
