#!/usr/bin/env bash
# Release process mechanics for AIXCL
# Encodes the two-remote model permanently: branches push to origin (fork),
# PRs and tags go to upstream (canonical). GPG commits and merge decisions
# stay with the human operator -- each subcommand stops at those points and
# prints the exact next command.
#
#   prep    verify preconditions, draft changelog, create issue + branch
#   tag     tag the merged release on upstream main and verify publication
#   finish  sync main back into dev, close issues, clean up branches
#   status  show where the current release cycle stands

# Canonical repository (override for forks of the fork)
RELEASE_UPSTREAM_REPO="${AIXCL_UPSTREAM_REPO:-xencon/aixcl}"

_release_usage() {
    echo "Usage: $0 release {prep|tag|finish|status}"
    echo "  prep     Preconditions, changelog draft, release issue and branch (stops at GPG commit)"
    echo "  tag      Tag merged release on upstream main, verify GitHub release published"
    echo "  finish   Sync main into dev, close issues, delete release branch, sync fork"
    echo "  status   Show current release cycle state"
}

_release_require_gh() {
    if ! command -v gh > /dev/null 2>&1; then
        echo "[ ] Error: gh CLI is required for release commands"
        return 1
    fi
}

# Compute current and next version from upstream tags
_release_versions() {
    git fetch --tags upstream > /dev/null 2>&1 || git fetch --tags origin > /dev/null 2>&1 || true
    RELEASE_CURRENT=$(git tag --sort=-v:refname | head -1)
    local patch="${RELEASE_CURRENT#v1.1.}"
    if [[ -z "$RELEASE_CURRENT" ]] || [[ ! "$patch" =~ ^[0-9]+$ ]]; then
        echo "[ ] Error: could not determine current version from tags (got '$RELEASE_CURRENT')"
        return 1
    fi
    RELEASE_NEXT="v1.1.$((patch + 1))"
}

_release_assignee() {
    gh api user --jq '.login' 2>/dev/null || echo "${GITHUB_USER:-}"
}

_release_prep() {
    _release_require_gh || return 1
    _release_versions || return 1

    echo "Release prep: ${RELEASE_CURRENT} -> ${RELEASE_NEXT}"
    echo ""

    # Precondition: no open PRs targeting dev
    local open_prs
    open_prs=$(gh pr list --repo "$RELEASE_UPSTREAM_REPO" --base dev --state open \
        --json number,title --jq '.[] | "  #\(.number) \(.title)"')
    if [ -n "$open_prs" ]; then
        echo "[ ] Error: open PRs still target dev -- merge or close them first:"
        echo "$open_prs"
        return 1
    fi
    echo "[x] No open PRs targeting dev"

    # Precondition: changelog does not already contain the next version
    if grep -q "^## \[${RELEASE_NEXT}\]" "${SCRIPT_DIR}/CHANGELOG.md"; then
        echo "[ ] Error: CHANGELOG.md already has an entry for ${RELEASE_NEXT}"
        echo "   A prep may already be in flight -- see: $0 release status"
        return 1
    fi

    # Sync dev from upstream
    git checkout dev > /dev/null 2>&1
    git pull upstream dev --ff-only > /dev/null 2>&1 || {
        echo "[ ] Error: could not fast-forward dev from upstream"
        return 1
    }
    echo "[x] dev synced from upstream"

    # Draft changelog entry
    local today draft_file
    today=$(date +%Y-%m-%d)
    draft_file=$(mktemp /tmp/aixcl-changelog-draft-XXXXXX.md)
    if command -v git-cliff > /dev/null 2>&1 || git cliff --help > /dev/null 2>&1; then
        git cliff --unreleased --tag "$RELEASE_NEXT" 2>/dev/null > "$draft_file" || true
    fi
    if [ ! -s "$draft_file" ]; then
        cat > "$draft_file" << EOF
## [${RELEASE_NEXT}] - ${today}

### Summary

<!-- TODO: one sentence describing the release -->

### Changed

- [x] **Change**: Description. Closes #N.
EOF
    fi

    # Insert the draft under the [Unreleased] heading
    awk -v draft="$draft_file" '
        /^## \[Unreleased\]/ {
            print
            print ""
            while ((getline line < draft) > 0) print line
            next
        }
        { print }
    ' "${SCRIPT_DIR}/CHANGELOG.md" > "${SCRIPT_DIR}/CHANGELOG.md.tmp" \
        && mv "${SCRIPT_DIR}/CHANGELOG.md.tmp" "${SCRIPT_DIR}/CHANGELOG.md"
    rm -f "$draft_file"
    echo "[x] Changelog draft inserted for ${RELEASE_NEXT} (review and edit the Summary)"

    # Create the release issue
    local assignee issue_url issue_num
    assignee=$(_release_assignee)
    issue_url=$(gh issue create --repo "$RELEASE_UPSTREAM_REPO" \
        --title "[TASK] Release ${RELEASE_NEXT}" \
        --body "$(printf '## Task Summary\n\nCut release %s.\n\n### Deliverables\n\n- [ ] CHANGELOG.md updated\n- [ ] PR merged to main (post-merge)\n- [ ] Tag %s pushed to upstream (post-merge)\n- [ ] GitHub release published (post-merge)\n- [ ] dev synced with main (post-merge)\n\n## Human in the Loop\n\nThe agent is responsible for completing all deliverables. The human is responsible for completing the verification checklist.' "$RELEASE_NEXT" "$RELEASE_NEXT")" \
        --assignee "$assignee" \
        --label "Task,component:infrastructure,Maintenance")
    issue_num="${issue_url##*/}"
    echo "[x] Release issue created: $issue_url"

    # Create the release branch and stage the changelog
    local branch="issue-${issue_num}/release-${RELEASE_NEXT//./-}"
    git checkout -b "$branch" > /dev/null 2>&1
    git add "${SCRIPT_DIR}/CHANGELOG.md"
    echo "[x] Branch created and CHANGELOG.md staged: $branch"

    echo ""
    echo "Next steps (human):"
    echo "  1. Review and edit the ${RELEASE_NEXT} entry in CHANGELOG.md (then re-run: git add CHANGELOG.md)"
    echo "  2. Commit (GPG):"
    echo "       git commit -m \"chore: update changelog for ${RELEASE_NEXT}\" -m \"Fixes #${issue_num}\""
    echo "  3. Push and open the release PR:"
    echo "       git push origin ${branch}"
    echo "       ./scripts/utils/create-pr.sh \"Release ${RELEASE_NEXT} (#${issue_num})\" \"Fixes #${issue_num}\" \"component:infrastructure\" \"${assignee}\" main"
    echo "  4. After the PR merges: $0 release tag"
}

_release_tag() {
    _release_require_gh || return 1
    _release_versions || return 1

    # After the release PR merges, the changelog on upstream main carries the
    # next version while the tag does not exist yet.
    if git rev-parse -q --verify "refs/tags/${RELEASE_NEXT}" > /dev/null; then
        echo "[ ] Error: tag ${RELEASE_NEXT} already exists"
        return 1
    fi

    git checkout main > /dev/null 2>&1
    git pull upstream main --ff-only > /dev/null 2>&1 || {
        echo "[ ] Error: could not fast-forward main from upstream"
        return 1
    }

    if ! grep -q "^## \[${RELEASE_NEXT}\]" "${SCRIPT_DIR}/CHANGELOG.md"; then
        echo "[ ] Error: CHANGELOG.md on main has no ${RELEASE_NEXT} entry"
        echo "   Has the release PR been merged?"
        return 1
    fi
    echo "[x] main is at the ${RELEASE_NEXT} release merge"

    git tag "$RELEASE_NEXT" -m "Release ${RELEASE_NEXT}"
    git push upstream "$RELEASE_NEXT"
    echo "[x] Tag ${RELEASE_NEXT} pushed to upstream"

    echo "Waiting for release workflow to publish..."
    local waited=0
    while [ "$waited" -lt 300 ]; do
        if gh release view "$RELEASE_NEXT" --repo "$RELEASE_UPSTREAM_REPO" \
            --json isDraft --jq 'select(.isDraft == false)' > /dev/null 2>&1; then
            echo "[x] Release published: https://github.com/${RELEASE_UPSTREAM_REPO}/releases/tag/${RELEASE_NEXT}"
            echo ""
            echo "Next: $0 release finish"
            return 0
        fi
        sleep 15
        waited=$((waited + 15))
    done
    echo "[ ] Release not visible after ${waited}s -- check: gh run list --repo ${RELEASE_UPSTREAM_REPO}"
    return 1
}

_release_finish() {
    _release_require_gh || return 1

    # The most recent tag is the release being finished
    git fetch --tags upstream > /dev/null 2>&1 || true
    local version assignee
    version=$(git tag --sort=-v:refname | head -1)
    assignee=$(_release_assignee)

    # Phase 1: create the sync PR if none exists
    local sync_pr
    sync_pr=$(gh pr list --repo "$RELEASE_UPSTREAM_REPO" --base dev --head main --state open \
        --json number --jq '.[0].number' 2>/dev/null)
    if [ -z "$sync_pr" ]; then
        # Is dev already up to date with main?
        git fetch upstream main dev > /dev/null 2>&1 || true
        if [ -z "$(git rev-list upstream/dev..upstream/main 2>/dev/null)" ]; then
            echo "[x] dev already contains main -- no sync PR needed"
        else
            local issue_url issue_num
            issue_url=$(gh issue create --repo "$RELEASE_UPSTREAM_REPO" \
                --title "[TASK] Sync main into dev after ${version} release" \
                --body "Reconcile release history after ${version} tag." \
                --assignee "$assignee" \
                --label "Task,component:infrastructure,Maintenance")
            issue_num="${issue_url##*/}"
            gh pr create --repo "$RELEASE_UPSTREAM_REPO" --base dev --head main \
                --title "Sync main into dev after ${version} release (#${issue_num})" \
                --body "Reconcile release history. Fixes #${issue_num}" \
                --assignee "$assignee" \
                --label "Task,component:infrastructure,Maintenance"
            echo "[x] Sync PR created -- merge it, then re-run: $0 release finish"
            return 0
        fi
    else
        echo "[ ] Sync PR #${sync_pr} is still open -- merge it, then re-run: $0 release finish"
        return 1
    fi

    # Phase 2: cleanup after the sync PR has merged
    git checkout dev > /dev/null 2>&1
    git pull upstream dev --ff-only > /dev/null 2>&1 && git push origin dev > /dev/null 2>&1
    git checkout main > /dev/null 2>&1
    git pull upstream main --ff-only > /dev/null 2>&1 && git push origin main > /dev/null 2>&1
    echo "[x] Fork dev and main synced with upstream"

    # Delete merged release branches (local and fork)
    local branch
    for branch in $(git branch --format='%(refname:short)' | grep -E "^issue-[0-9]+/release-" || true); do
        git branch -D "$branch" > /dev/null 2>&1 || true
        git push origin --delete "$branch" > /dev/null 2>&1 || true
        echo "[x] Deleted release branch: $branch"
    done

    # Close any lingering release/sync issues (merge usually auto-closes them)
    local open_release_issues
    open_release_issues=$(gh issue list --repo "$RELEASE_UPSTREAM_REPO" --state open \
        --json number,title --jq '.[] | select(.title | test("Release v|Sync main into dev")) | .number')
    for n in $open_release_issues; do
        gh issue close "$n" --repo "$RELEASE_UPSTREAM_REPO" \
            --comment "Completed for ${version}." > /dev/null 2>&1 || true
        echo "[x] Closed issue #$n"
    done

    echo ""
    echo "[x] Release ${version} cycle complete"
}

_release_status() {
    _release_require_gh || return 1
    _release_versions || return 1

    echo "Release Status"
    echo "=============="
    echo "Latest tag:    ${RELEASE_CURRENT}"
    echo "Next version:  ${RELEASE_NEXT}"

    if grep -q "^## \[${RELEASE_NEXT}\]" "${SCRIPT_DIR}/CHANGELOG.md" 2>/dev/null; then
        echo "Changelog:     ${RELEASE_NEXT} entry present"
    else
        echo "Changelog:     no ${RELEASE_NEXT} entry (run: $0 release prep)"
    fi

    local rel_branch
    rel_branch=$(git branch --format='%(refname:short)' | grep -E "^issue-[0-9]+/release-" | head -1 || true)
    echo "Branch:        ${rel_branch:-none}"

    local rel_pr sync_pr
    rel_pr=$(gh pr list --repo "$RELEASE_UPSTREAM_REPO" --base main --state open \
        --json number,title --jq '.[] | select(.title | test("^Release ")) | "#\(.number) \(.title)"' 2>/dev/null)
    echo "Release PR:    ${rel_pr:-none open}"

    sync_pr=$(gh pr list --repo "$RELEASE_UPSTREAM_REPO" --base dev --head main --state open \
        --json number --jq '.[0].number' 2>/dev/null)
    if [ -n "$sync_pr" ]; then
        echo "Sync PR:       #${sync_pr} open"
    else
        echo "Sync PR:       none open"
    fi

    git fetch upstream main dev > /dev/null 2>&1 || true
    local behind
    behind=$(git rev-list upstream/dev..upstream/main 2>/dev/null | wc -l | tr -d ' ')
    echo "dev vs main:   ${behind} commit(s) in main not in dev"
}

function release_cmd() {
    if [[ $# -lt 1 ]]; then
        _release_usage
        return 1
    fi

    local action="$1"
    shift

    case "$action" in
        prep)   _release_prep ;;
        tag)    _release_tag ;;
        finish) _release_finish ;;
        status) _release_status ;;
        *)
            echo "Error: Unknown release action '$action'"
            _release_usage
            return 1
            ;;
    esac
}
