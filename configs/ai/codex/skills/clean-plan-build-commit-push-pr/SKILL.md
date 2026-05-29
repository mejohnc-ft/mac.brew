---
name: "clean-plan-build-commit-push-pr"
description: "Run end-to-end sequential issue delivery: clean merged branches, pick the next issue, implement, validate, commit, push, and open PR while handling safe merge-state conflicts. Use when the user requests autopilot multi-issue execution with minimal prompts."
---


# Skill: Clean Plan Build Commit Push PR

> **Sequential issue autopilot with PR conflict watchdog**
>
> Trigger phrase: `/clean-plan-build-commit-push-pr`
>
> Applies to: issue-by-issue delivery in this repo until blocked

---

## Overview

Use this skill when the user wants continuous execution across multiple issues with minimal prompts.

Loop:

1. Clean up merged branches
2. Select/start next issue on a fresh branch
3. Plan + implement + verify
4. Commit + push + open PR
5. Resolve PR merge-state conflicts when safe
6. Continue to next issue until blocked

---

## Required Inputs

Provide at least one of:

- explicit issue number (example: `1884`)
- issue selection rule (example: `oldest open with label:dev-teammate`)

If both are missing, ask one short blocking question.

---

## ALWAYS

### Safety

- Work only on issue branches, never directly on `main`
- Start fresh branches from `origin/main`
- Keep commits scoped to one issue
- Run `./scripts/qa-gate.sh --skip=status` before push
- Use `/commit-push-pr` flow for finalization
- Always clean local and remote branches after each cycle when their PR is merged to `main`
- Never overwrite or delete branches with unmerged work

### Continuation Rule

- After opening a PR, immediately move to the next issue unless a blocker is hit
- Do not wait for an extra user prompt between issues unless required by a Hard Stop

### Reporting

- After each issue, report:
- issue number
- branch name
- commit hash
- PR URL
- gate result
- whether continuation is proceeding or blocked

---

## NEVER

- Force-push unless explicitly requested
- Delete remote branches unless merge-to-main is confirmed on GitHub
- Mix unrelated issues in one PR
- Ignore failed gates
- Continue past unresolved merge conflicts that require product/architecture decisions

---

## Workflow

### 1) Pre-Loop Branch Cleanup

Run safe cleanup before starting next issue.

```bash
git fetch --all --prune
git checkout main
git pull --ff-only origin main
git branch --merged origin/main | rg -v '^\*|main$' | xargs -r git branch -d
```

Then clean remote issue branches only when GitHub confirms merged PRs to `main`:

```bash
git for-each-ref --format='%(refname:short)' refs/remotes/origin/issue/ \
  | sed 's|^origin/||' \
  | while read -r b; do
  if gh pr list --state merged --base main --head "$b" --json number --jq 'length > 0' | rg -q true; then
    git push origin --delete "$b"
  fi
done
```

If no merged PR is found for a branch, do not delete it.

### 2) Pick Next Issue

If user provided a number, use it.
Otherwise resolve using the user-provided rule (for example label + sort order).

Example query:

```bash
gh issue list --state open --limit 100 --search "label:dev-teammate sort:created-asc"
```

### 3) Start Fresh Branch

```bash
issue="<number>"
slug="<short-kebab-slug>"
git checkout -b "issue/${issue}-${slug}" origin/main
```

### 4) Plan + Build

- Read issue details, AGENTS rules, and relevant module AGENTS
- Create a brief plan for broad work
- Implement end-to-end
- Run targeted tests + required checks
- Run final gate:

```bash
./scripts/qa-gate.sh --skip=status
```

### 5) Commit Push PR

Use `/commit-push-pr` flow:

```bash
git add <scoped-files>
git commit -m "<type(scope): message>"
git push -u origin "$(git branch --show-current)"
gh pr create --base main --head "$(git branch --show-current)"
```

PR body must include validation commands and `Closes #<issue>`.

### 6) PR Conflict Watchdog (Subagent Behavior)

Immediately inspect PR merge state:

```bash
gh pr view --json number,url,mergeStateStatus,isDraft,headRefName,baseRefName
```

Handle states:

- `CLEAN`: continue to next issue
- `BEHIND`: rebase on `origin/main`, rerun gate, push, re-check
- `DIRTY`: attempt conflict resolution locally; if resolved, rerun gate + push + re-check
- `BLOCKED`/`DRAFT`: report status and continue only if user asked to keep going regardless
- `UNKNOWN` or repeated failures: stop and report blocker

Rebase flow:

```bash
git fetch origin
git checkout <branch>
git rebase origin/main
./scripts/qa-gate.sh --skip=status
git push
```

### 7) Continue Until Blocked

Repeat from Step 1 for the next issue until one of these occurs:

- missing/ambiguous next-issue selection rule
- gate failures not fixable within current turn
- conflict resolution requires product/architecture decision
- required credentials/permissions unavailable

When blocked, stop with one concise blocker report and the exact next decision needed.
