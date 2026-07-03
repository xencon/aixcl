#!/usr/bin/env bash
# check-image-pins.sh -- verify container image references are pinned
#
# Scans compose files AND shell code under lib/ and scripts/ for container
# image references that use :latest or no tag at all. The compose-only
# sweep missed four unpinned alpine references in shell code (issue #1726);
# this check closes that gap (issue #1728).
#
# Rules:
#   1. compose image: lines must carry a version tag (no :latest, no bare name)
#   2. no :latest anywhere in *.sh / *.yml under lib/, scripts/, services/
#      Exempt: localhost/ images (built locally from source, never pulled)
#      and lines carrying an explicit "pin-waiver:" comment with a reason
#      (e.g. ollama MODEL tags, which are not container images)
#   3. FROM lines in heredoc Dockerfile templates must carry a non-latest tag
#   4. registry-prefixed references (docker.io, ghcr.io, quay.io) in shell
#      code must carry a tag

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$REPO_ROOT"

SELF="scripts/checks/check-image-pins.sh"
fail=0

report() {
    echo "UNPINNED ($1): $2"
    fail=1
}

# 1. Compose files: image: lines with :latest or no tag at all
while IFS= read -r match; do
    report "compose" "$match"
done < <(grep -Hn "image:" services/docker-compose*.yml 2>/dev/null \
    | grep -v "#" \
    | grep -E "image:[[:space:]]+(\S+:latest[[:space:]]*$|\S*/[^:]+[[:space:]]*$|[^/:]+[[:space:]]*$)" || true)

# 2. :latest anywhere in shell or yaml under lib/, scripts/, services/
while IFS= read -r match; do
    report ":latest" "$match"
done < <(grep -rn ":latest" lib/ scripts/ services/ \
    --include="*.sh" --include="*.yml" 2>/dev/null \
    | grep -v "^${SELF}:" \
    | grep -v "localhost/" \
    | grep -v "pin-waiver:" || true)

# 3. FROM lines in heredoc Dockerfile templates without a version tag
while IFS= read -r match; do
    report "FROM" "$match"
done < <(grep -rn "^FROM " lib/ scripts/ --include="*.sh" 2>/dev/null \
    | grep -vE "^[^:]+:[0-9]+:FROM [^ ]+:[A-Za-z0-9][A-Za-z0-9._-]*([[:space:]]|$)" \
    | grep -v "^${SELF}:" || true)

# 4. Registry-prefixed references in shell code without a tag
while IFS= read -r match; do
    report "no tag" "$match"
done < <(grep -rnE "(docker\.io|ghcr\.io|quay\.io)/[A-Za-z0-9._/-]+" \
    lib/ scripts/ --include="*.sh" 2>/dev/null \
    | grep -vE "(docker\.io|ghcr\.io|quay\.io)/[A-Za-z0-9._/-]+:[A-Za-z0-9]" \
    | grep -v "^${SELF}:" || true)

if [ "$fail" -eq 1 ]; then
    echo "FAIL: unpinned container image references found"
    exit 1
fi

echo "All container image references are pinned"
exit 0
