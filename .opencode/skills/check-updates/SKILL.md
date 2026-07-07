---
name: check-updates
description: Audit all versioned platform components and manage the update process following issue-first workflow
version: 1.0
compatibility: OpenCode, Claude Code
metadata:
  category: maintenance
  version: "1.0"
---

# Skill: check-updates

## Purpose

Audit every versioned component in the AIXCL platform and produce an
actionable update report. For each outdated component, open a GitHub issue
and apply the update following the issue-first workflow.

## When to Run

Before a release cycle or after a long gap between releases.

---

## Component Inventory

The platform versions four categories of components. Every line below is a
canonical version source -- do not check anywhere else.

### Category 1 -- Stack Services (services/docker-compose.yml)

Extract all pinned image tags:

```bash
grep "image:" services/docker-compose.yml | grep -v "#" | \
  sed 's/.*image: //' | sort
```

| Service | Compose key | Registry |
|---------|------------|---------|
| Ollama | `ollama/ollama:<tag>` | hub.docker.com |
| Vault | `hashicorp/vault:<tag>` | hub.docker.com |
| PostgreSQL | `library/postgres:<tag>` | hub.docker.com |
| Open WebUI | `ghcr.io/open-webui/open-webui:<tag>` | ghcr.io (GitHub releases) |
| pgAdmin 4 | `dpage/pgadmin4:<tag>` | hub.docker.com |
| Prometheus | `prom/prometheus:<tag>` | GitHub releases |
| Alertmanager | `prom/alertmanager:<tag>` | GitHub releases |
| Grafana | `grafana/grafana:<tag>` | GitHub releases |
| Loki | `grafana/loki:<tag>` | GitHub releases |
| cAdvisor | `ghcr.io/google/cadvisor:<tag>` | GitHub releases |
| Node Exporter | `prom/node-exporter:<tag>` | GitHub releases |
| Postgres Exporter | `prometheuscommunity/postgres-exporter:<tag>` | GitHub releases |
| NVIDIA GPU Exporter | `utkuozdemir/nvidia_gpu_exporter:<tag>` | GitHub releases |

### Category 2 -- Pre-commit Hooks (.pre-commit-config.yaml)

```bash
grep -E "repo:|rev:" .pre-commit-config.yaml | paste - -
```

| Hook | GitHub repo | Rev field |
|------|-------------|-----------|
| pre-commit-hooks | pre-commit/pre-commit-hooks | `rev:` |
| shellcheck-py | shellcheck-py/shellcheck-py | `rev:` |
| yamllint | adrienverge/yamllint | `rev:` |
| gitleaks | gitleaks/gitleaks | `rev:` |

### Category 3 -- GitHub Actions (.github/workflows/*.yml)

```bash
grep -rh "uses:" .github/workflows/ | grep -v "#" | grep "@" | \
  sed 's/.*uses: //' | sort -u
```

| Action | Pinned in |
|--------|-----------|
| actions/checkout | bash-ci.yml, codeql.yml, security.yml, others |
| actions/dependency-review-action | dependency-review.yml |
| docker/setup-buildx-action | bash-ci.yml |
| github/codeql-action/init | codeql.yml |
| github/codeql-action/analyze | codeql.yml |

### Category 4 -- Developer CLI Tools (README.md + CI)

Versions are pinned in two places that must stay in sync:

| Tool | README.md install | CI workflow |
|------|------------------|-------------|
| shellcheck | README.md curl install | security.yml (uses shellcheck-py action) |
| gitleaks | README.md curl install | security.yml `GITLEAKS_VERSION` var |
| git-cliff | README.md curl install | not used in CI |
| yamllint | README.md pip install | documentation-checks.yml pip install |

---

## Step 1 -- Check Latest Versions

Run these commands to look up the latest stable release for each component.
Use GitHub releases (more reliable) wherever available; fall back to Docker Hub.

```bash
# Stack services -- GitHub releases
for repo in \
  "ollama/ollama" \
  "open-webui/open-webui" \
  "google/cadvisor" \
  "grafana/loki" \
  "prometheus/prometheus" \
  "prometheus/alertmanager" \
  "grafana/grafana" \
  "prometheus/node_exporter" \
  "prometheus-community/postgres_exporter" \
  "utkuozdemir/nvidia_gpu_exporter"; do
  latest=$(gh api repos/$repo/releases/latest --jq '.tag_name' 2>/dev/null || echo "N/A")
  echo "$repo: $latest"
done

# Stack services -- Docker Hub (for images without GitHub releases)
for image in "hashicorp/vault" "dpage/pgadmin4" "library/postgres"; do
  latest=$(curl -s "https://hub.docker.com/v2/repositories/$image/tags?page_size=50&ordering=last_updated" | \
    python3 -c "
import sys, json, re
data = json.load(sys.stdin)
tags = [t['name'] for t in data.get('results',[]) if re.match(r'^[0-9]+\.[0-9]+\.[0-9]+$', t['name'])]
print(tags[0] if tags else 'check manually')
" 2>/dev/null)
  echo "$image: $latest"
done

# Pre-commit hooks and CLI tools
for repo in \
  "pre-commit/pre-commit-hooks" \
  "shellcheck-py/shellcheck-py" \
  "adrienverge/yamllint" \
  "gitleaks/gitleaks" \
  "orhun/git-cliff" \
  "koalaman/shellcheck" \
  "actions/checkout" \
  "actions/dependency-review-action" \
  "docker/setup-buildx-action" \
  "github/codeql-action"; do
  latest=$(gh api repos/$repo/releases/latest --jq '.tag_name' 2>/dev/null || echo "N/A")
  echo "$repo: $latest"
done
```

---

## Step 2 -- Build the Update Table

Produce a table with four columns: Component, Category, Pinned, Latest.

Mark each row:

| Symbol | Meaning |
|--------|---------|
| current | Pinned == Latest |
| UPDATE | Newer version available |
| check | Could not determine latest (check manually) |

Example output:

```
| Component          | Category       | Pinned   | Latest   | Status  |
|--------------------|----------------|----------|----------|---------|
| ollama             | stack-service  | 0.30.7   | 0.31.1   | UPDATE  |
| prometheus         | stack-service  | v3.12.0  | v3.12.0  | current |
```

---

## Step 3 -- Triage Updates

Before opening issues, classify each update:

**Routine (open one issue per component):**
- Patch version bumps (x.y.Z -> x.y.Z+1)
- Minor version bumps with no breaking changes noted in release notes

**Review required (open issue, flag for human review):**
- Major version bumps (X.y.z -> X+1.y.z)
- Any bump for a component listed in `docs/architecture/governance/00_invariants.md`
  as a runtime core invariant (currently: Ollama)
- Any bump where the release notes mention breaking API changes or schema migrations

**Skip (do not open an issue):**
- Pre-release tags (alpha, beta, rc, dev)
- Architecture-specific tags (rocm, cuda, distroless suffixes)
- Tags that differ only in suffix from the currently pinned version

---

## Step 4 -- Open Issues (issue-first workflow)

Open one issue per component that needs updating. Batch minor patch bumps
across the same category into a single issue if there are more than three.

```bash
# Example: single component update
gh issue create --repo xencon/aixcl \
  --title "[TASK] Update <component> from <old> to <new>" \
  --body "## Update

- Component: \`<component>\`
- Current: \`<old>\`
- Latest: \`<new>\`
- Release notes: <URL>

## Checklist

- [ ] Image tag updated in \`services/docker-compose.yml\`
- [ ] Version updated in README.md install section (if CLI tool)
- [ ] Version updated in CI workflow (if pinned in .github/workflows/)
- [ ] Version updated in \`.pre-commit-config.yaml\` (if pre-commit hook)
- [ ] Stack starts cleanly after update (\`./aixcl stack start --profile sys\`)
- [ ] \`./aixcl stack status\` shows all services healthy" \
  --assignee <assignee> \
  --label "Task,component:infrastructure,Maintenance"
```

For Ollama (runtime core invariant), add to the issue body:

```
> [!WARNING]
> Ollama is a runtime core invariant. Test inference with at least one
> model before merging. Confirm the OpenAI-compatible API endpoint
> (/v1/chat/completions) responds correctly after the upgrade.
```

---

## Step 5 -- Apply Updates

Create a branch per issue:

```bash
git checkout dev
git checkout -b issue-<N>/update-<component>-<new-version>
```

### Update locations by category

**Stack service (docker-compose.yml):**
```bash
# Replace the image tag -- edit services/docker-compose.yml
# For services with multiple instances (e.g. vault), update all occurrences
grep -n "image:.*<component>" services/docker-compose.yml
# Edit each line, then validate
docker compose -f services/docker-compose.yml config > /dev/null
```

**Pre-commit hook (.pre-commit-config.yaml):**
```bash
# Update the rev: field for the relevant repo entry
# Then run pre-commit to verify
pre-commit autoupdate --repo https://github.com/<owner>/<repo>
# Or edit manually, then:
pre-commit run --all-files
```

**GitHub Action (.github/workflows/*.yml):**
```bash
# Update the uses: line in every workflow that references the action
grep -rn "uses:.*<action>" .github/workflows/
# Edit each file, then validate YAML
yamllint -c .yamllint.yml .github/workflows/
```

**CLI tool (README.md + CI workflow):**
```bash
# Must update both locations atomically:
# 1. README.md -- curl install URL and version comment
# 2. .github/workflows/security.yml GITLEAKS_VERSION (for gitleaks)
#    or documentation-checks.yml pip install line (for yamllint)
grep -n "<tool>" README.md
grep -rn "<tool>" .github/workflows/
```

---

## Step 6 -- Validate and Commit

```bash
# Run pre-commit checks
bash scripts/checks/check-ai-elisions.sh --staged
shellcheck --severity=warning --exclude=SC1091 $(find . -name "*.sh" -not -path "./.git/*")
yamllint -c .yamllint.yml .

# Validate compose
docker compose -f services/docker-compose.yml config > /dev/null

# Stage and commit (GPG -- user must run)
git add <changed files>
# Provide commit message:
# "chore: update <component> from <old> to <new>
#
# Fixes #<issue>"
```

---

## Step 7 -- PR and CI

```bash
git push origin issue-<N>/update-<component>-<new-version>

gh pr create \
  --repo xencon/aixcl \
  --base dev \
  --title "Update <component> from <old> to <new> (#<N>)" \
  --body "$(cat /tmp/update-pr-body.md)" \
  --assignee <assignee> \
  --label "Task,component:infrastructure,Maintenance"
```

Verify PR body with `check-pr-references.sh` before creating.

---

## Dependabot Coverage Note

`.github/dependabot.yml` automatically opens PRs for:
- Docker images in `/services` (weekly, Mondays)
- GitHub Actions in `/.github/workflows` (weekly, Mondays)

This skill covers the gaps Dependabot does not handle:
- Pre-commit hook versions (`.pre-commit-config.yaml`)
- CLI tool versions in `README.md` install instructions
- Tool versions hard-coded in CI workflow `run:` steps (not `uses:`)
- Cross-checking that Dependabot PRs have not stalled or been missed

When Dependabot opens a PR for a component in this inventory, close the
corresponding issue from this skill if one was opened for the same version bump.

---

## Common Mistakes

- Updating docker-compose.yml but not README.md for the same tool version
- Updating pre-commit rev but not the matching CI workflow pin (yamllint, gitleaks)
- Pulling an RC or architecture-specific tag (check for `-rc`, `-rocm`, `-cuda` suffixes)
- Updating Ollama without testing model inference after restart
- Batching too many updates in one PR -- prefer one component per PR so
  regressions are easy to bisect
