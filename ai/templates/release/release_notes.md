---
name: "Release Notes"
about: "Template for creating a new release"
title: "[RELEASE] vX.Y.Z"
labels: ["release"]
assignees: ["<assignee>"]
---

# Release vX.Y.Z

## Summary

Brief description of this release - what it includes, key highlights, and why it matters.

### Target Date
YYYY-MM-DD

### Previous Release
vX.Y.Z-(N-1) (or specify)

---

## Security

List security-related changes, CVE fixes, hardening improvements:
- [ ] Security fix 1
- [ ] Security fix 2

## Added

List new features, services, or capabilities:
- [ ] New feature 1
- [ ] New feature 2

## Changed

List modifications to existing functionality:
- [ ] Change 1
- [ ] Change 2

## Deprecated

List features marked for deprecation (will be removed in future):
- [ ] Deprecated feature 1

## Removed

List removed features or services:
- [ ] Removed feature 1

## Fixed

List bug fixes and issue resolutions:
- [ ] Fix 1 (Fixes #<issue-number>)
- [ ] Fix 2 (Fixes #<issue-number>)

## Documentation

List documentation updates:
- [ ] Doc update 1
- [ ] Doc update 2

---

## Related Issues

- Closes #<issue-number>
- Closes #<issue-number>

## Verification Checklist

- [ ] All CI checks passing
- [ ] Security scan completed
- [ ] Performance benchmarks run
- [ ] Breaking changes documented
- [ ] Migration guide provided (if applicable)
- [ ] CHANGELOG.md updated
- [ ] Version bumped in relevant files
- [ ] Git tag created: `git tag -a vX.Y.Z -m "Release vX.Y.Z"`
- [ ] Release notes published to GitHub

## Deployment Notes

Any special instructions for deploying this release:
- Migration steps
- Configuration changes
- Breaking changes requiring user action

## Known Issues

List any known issues not yet resolved:
- Issue 1 (tracked in #<issue-number>)
- Issue 2 (tracked in #<issue-number>)

---

## Template Usage Notes

1. Replace X.Y.Z with actual version number
2. Remove unused sections (if no items in Deprecated, remove that section)
3. Follow [Keep a Changelog](https://keepachangelog.com/) format
4. Reference all related issues
5. Update CHANGELOG.md with same content after release
6. Create GitHub Release with these notes
