# CI Checks and Compliance

## Pre-Commit Checklist
Before committing any changes, verify locally:

### Shell Scripts
- Run ShellCheck: `shellcheck --severity=warning --exclude=SC1091 <file.sh>`
- Run syntax check: `bash -n <file.sh>`
- Common failures: SC2034 (unused variables), SC2120 (function args), SC2086 (unquoted variables)

### Markdown Files
- No non-ASCII punctuation: no smart quotes, em dashes (--), en dashes (-), ellipsis (...), non-breaking spaces
- Use plain ASCII equivalents: `--` for dashes, `...` for ellipsis, straight quotes
- No CRLF line endings (use LF only)
- No broken relative links (`./` or `../` paths must resolve)

### YAML Files
- Run: `yamllint -c .yamllint.yml <file.yml>`
- Line length limit: 160 characters

### Docker Compose Files
- Run: `docker compose -f services/docker-compose.yml config > /dev/null`

## PR Requirements (ALL must be set at creation time)
```bash
gh pr create \
  --title "<description> (#<number>)" \
  --body-file /tmp/pr-body.md \
  --assignee <username> \
  --label "component:<name>"
```
- Title: ends with `(#<number>)`, no colons
- Assignee: required, set at creation (not after)
- Label: at least one `component:*` label, set at creation (not after)
- NEVER use two-step creation -- webhook fires on `opened` event, labels/assignee must be present

## CI Workflows Summary

| Workflow | Trigger | Key Checks |
|----------|---------|------------|
| pr-validation.yml | PR open/edit | Title format, assignee, component label |
| bash-ci.yml | PR + push | check-env, CRLF, ASCII markdown |
| quick-tests.yml | Push to dev (.sh files) | Security tests, bash -n, ./aixcl help |
| security.yml | PR + push | ShellCheck (warning+, no SC1091), dependency review |
| documentation-checks.yml | PR + push | check-paths.sh, check-generated-files.sh, yamllint, compose validate |
| codeql.yml | PR + push | GitHub Actions workflow security (actions language only) |

## Running Checks Locally
```bash
# Full pre-PR check
bash scripts/checks/check-paths.sh
bash scripts/checks/check-generated-files.sh
shellcheck --severity=warning --exclude=SC1091 $(find . -name "*.sh" -not -path "./.git/*")
yamllint -c .yamllint.yml .
./aixcl utils check-env
```
