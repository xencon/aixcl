# Update reference -- component inventory, lookups, and update locations

## Contents

- Component inventory (four categories)
- Version lookup commands
- Update locations by category
- Issue body template

## Component inventory

Every line below is a canonical version source -- do not check anywhere else.

### Category 1 -- Stack services (services/docker-compose.yml)

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

### Category 2 -- Pre-commit hooks (.pre-commit-config.yaml)

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

### Category 4 -- Developer CLI tools (README.md + CI)

Versions are pinned in two places that must stay in sync:

| Tool | README.md install | CI workflow |
|------|------------------|-------------|
| shellcheck | README.md curl install | security.yml (uses shellcheck-py action) |
| gitleaks | README.md curl install | security.yml `GITLEAKS_VERSION` var |
| git-cliff | README.md curl install | not used in CI |
| yamllint | README.md pip install | documentation-checks.yml pip install |

## Version lookup commands

Use GitHub releases (more reliable) wherever available; fall back to Docker
Hub.

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

## Update locations by category

**Stack service (docker-compose.yml):**
```bash
# For services with multiple instances (e.g. vault), update all occurrences
grep -n "image:.*<component>" services/docker-compose.yml
# Edit each line, then validate
docker compose -f services/docker-compose.yml config > /dev/null
```

**Pre-commit hook (.pre-commit-config.yaml):**
```bash
# Update the rev: field for the relevant repo entry, then verify
pre-commit autoupdate --repo https://github.com/<owner>/<repo>
# Or edit manually, then:
pre-commit run --all-files
```

**GitHub Action (.github/workflows/*.yml):**
```bash
# Update the uses: line in every workflow that references the action
grep -rn "uses:.*<action>" .github/workflows/
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

## Issue body template

```bash
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
