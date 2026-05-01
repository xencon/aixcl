# Pull Request

## Summary
Fixes #<ISSUE_NUMBER>

### Description of Changes
Provide a concise summary of changes.

### Change Checklist
- [ ] Issue referenced in title and description
- [ ] Branch is named correctly
- [ ] Commit messages follow conventional style
- [ ] All tests run and pass

### PR Validation Requirements
The following are enforced by `.github/workflows/pr-validation.yml` and will block merge if not met:
- [ ] **Assignee**: At least one assignee is set (required by CI)
- [ ] **Component Label**: At least one `component:*` label (e.g., `component:cli`, `component:infrastructure`)
- [ ] **Title Format**: `<description> (#<number>)` with NO colons in the description

**Note**: PR validation runs automatically and must pass before merging.

### Testing Notes
Describe how this change was tested:

- Steps to reproduce (if relevant)
- What environments were used

### Verification
To verify this change is complete:

- [ ] Behavior works as expected
- [ ] No regressions observed
- [ ] Tests cover change

### Related Issues
- Closes #<ISSUE_NUMBER>
