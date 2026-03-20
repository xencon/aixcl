
# Skill: Verify CI Status

Executes:
gh run list --limit 5 --branch <current-branch>
gh pr view --json statusCheckRollup

Ensures all status checks are SUCCESS before finalizing.
