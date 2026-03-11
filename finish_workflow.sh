#!/usr/bin/env bash

# This script automates the ai/governance/workflow-governance.md rules for completing this task.
# It creates the issue, branch, commit, pushes, and creates the PR.

echo "Creating the Task Issue via GitHub CLI..."
ISSUE_URL=$(gh issue create \
  --title "[TASK] Extract LLM Council to standalone repository" \
  --body "## Description
Extract the LLM Council feature into a new, standalone repository at xencon/llm-council.
Remove all council service integrations, CLI commands, and configurations from the aixcl repo.

## Context/Additional Information
Completed via AI extraction. All aixcl configurations updated and council directories removed." \
  --assignee "@me")

# Extract the issue number from the returned URL
ISSUE_NUM=$(echo "$ISSUE_URL" | grep -o '[0-9]*$')

if [ -z "$ISSUE_NUM" ]; then
    echo "Error: Could not determine the generated issue number from the output."
    echo "Are you authenticated with 'gh auth login'?"
    exit 1
fi

echo "Created Issue #$ISSUE_NUM"
echo ""

BRANCH_NAME="issue-$ISSUE_NUM/extract-llm-council"

echo "Creating and checking out branch: $BRANCH_NAME"
git checkout -b "$BRANCH_NAME"

echo "Adding and committing changes..."
git add .
git commit -m "task: extract LLM Council to standalone repository

Fixes #$ISSUE_NUM"

echo "Pushing branch to origin..."
git push -u origin "$BRANCH_NAME"

echo "Creating Pull Request..."
gh pr create \
  --title "[TASK] Extract LLM Council to standalone repository (#$ISSUE_NUM)" \
  --body "## Summary
Extracted LLM Council to a standalone repository at xencon/llm-council.

## Changes
- Removed council service from docker-compose.yml
- Removed council references from common.sh and profile.sh
- Removed council subcommands and status checks from the aixcl CLI
- Cleaned up README.md and removed council-specific tests

Fixes #$ISSUE_NUM" \
  --assignee "@me"

echo ""
echo "Workflow completed successfully!"
