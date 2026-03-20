
# Skill: Create Pull Request

Executes:
git push -u origin issue-<number>/<description>
gh pr create --title "[<TYPE>] <description> (#<number>)" --body "Fixes #<number>"

Ensures PR references issue and labels match.
Requires 'Verify CI Status' after creation.
