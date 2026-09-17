# Release templates -- discussion posts and edge cases

## Contents

- Pre-release retrospective discussion template
- Announcement discussion template
- Common mistakes

## Pre-release retrospective (Step 2)

Open a dedicated discussion thread and post agent observations. This step is
advisory -- the human may proceed once formal CI and review checks are
complete, even if one agent has nothing material to add.

```bash
# Repository and category IDs are xencon/aixcl constants; re-derive with
# `gh api graphql` repository/discussionCategories queries if they change
gh api graphql -f query='
mutation {
  createDiscussion(input: {
    repositoryId: "R_kgDOMOfaEA",
    categoryId: "DIC_kwDOMOfaEM4C_SO-",
    title: "Release v1.1.N retrospective",
    body: "Pre-release retrospective for v1.1.N.\n\nBoth agents post observations below: what landed, what was deferred, and any open concerns before the tag goes out."
  }) {
    discussion { url number id }
  }
}'
```

- [ ] This agent has posted its retrospective (what landed, what was deferred, open concerns)
- [ ] The other agent has posted its retrospective, or confirmed nothing material to add
- [ ] Human has reviewed and confirmed readiness to proceed

Each agent post must include the standard agent identification block
(AGENTS.md Section 9.5). Link the thread URL in the release PR body.

## Announcement (Step 5)

Post a release announcement in the Announcements discussion category:

```bash
gh api graphql -f query='
mutation {
  createDiscussion(input: {
    repositoryId: "R_kgDOMOfaEA",
    categoryId: "DIC_kwDOMOfaEM4C_R_w",
    title: "AIXCL v1.1.N -- <headline>",
    body: "<what shipped, what users need to know, migration notes, changelog link>"
  }) {
    discussion { url number }
  }
}'
```

Cover: the headline change, what users must do (if anything), anything
removed or deprecated, and a link to the release page and CHANGELOG. Include
the agent identification block.

## Common Mistakes

- Tagging before the release PR is merged (`release tag` guards this by
  checking the changelog on upstream main -- do not bypass it)
- Editing CHANGELOG.md with non-ASCII punctuation (CI fails the ASCII check)
- Comma-packed references in the PR body -- `create-pr.sh` validates this,
  raw `gh pr create` does not
- Force-push race: if the release branch is force-pushed while the PR is
  open, confirm `gh pr view <N> --json headRefOid` matches `git log
  --oneline -1` before the human merges. A PR merged seconds before an
  amend lands cannot be fixed afterward
- Closing a PR instead of merging it -- check `state=MERGED`, not just
  "the PR is no longer open," before cleaning up branches
- Pre-commit trailing whitespace: the hook already fixed the files; re-run
  `git add` and retry the commit -- never use `--no-verify`
