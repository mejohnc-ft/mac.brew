---
name: "commit-push-pr"
description: "Finalize a completed issue branch by committing scoped changes, running qa gate, pushing to origin, and opening or updating a PR against main with issue linkage and validation notes. Use when implementation is done and branch closeout is requested."
---


# Skill: Commit Push PR

> **One-command finish flow for completed issue branches**
>
> Trigger phrase: `/commit-push-pr`
>
> Applies to: Any issue branch in this repo

---

## Overview

Use this skill when an implementation is complete and you want a consistent closeout flow:

1. Commit
2. Push
3. Open PR

This keeps delivery predictable and avoids half-finished branch states.

---

## ALWAYS

### Safety First

- Confirm current branch is an issue/work branch (never `main`)
- Confirm `git status` and understand all pending changes
- Do not include unrelated file changes
- Do not use force push
- Do not amend old commits unless explicitly requested

### Validation

- Run `./scripts/qa-gate.sh --skip=status` before push
- If gate fails, fix or clearly report blockers before proceeding
- Include validation command(s) in PR body

### PR Hygiene

- Open PR against `main`
- Include summary + validation in PR body
- Link issue with `Closes #<issue>`
- Reuse existing open PR if one already exists for the branch

---

## NEVER

- Commit directly to `main`
- Push with `--force` or `--force-with-lease` unless explicitly requested
- Open PR without issue linkage when issue number is known
- Mix multiple unrelated issues into one branch/PR

---

## Workflow

### 1) Check Branch + State

```bash
git branch --show-current
git status --short --branch
```

If on `main`, stop and create/switch to an issue branch first.

### 2) Stage + Commit

```bash
git add <intended-files>
git commit -m "<conventional message>"
```

Preferred commit style examples:

- `feat(api): ...`
- `fix(web): ...`
- `chore(infra): ...`
- `docs(architecture): ...`

### 3) Validate

```bash
./scripts/qa-gate.sh --skip=status
```

### 4) Push Branch

```bash
git push -u origin <branch-name>
```

### 5) Open PR

```bash
gh pr create --base main --head <branch-name> --title "<title>" --body "<body>"
```

PR body minimum:

- What changed
- Validation run
- `Closes #<issue>`

---

## Fast Path Template

```bash
# 1) Commit
git add <files>
git commit -m "<type(scope): message>"

# 2) Verify
./scripts/qa-gate.sh --skip=status

# 3) Push
git push -u origin "$(git branch --show-current)"

# 4) PR
gh pr create --base main --head "$(git branch --show-current)"
```

---

## Optional Branch Naming Convention

- `issue/<number>-<short-slug>`

Examples:

- `issue/1886-proactive-quality-scan`
- `issue/1656-circuit-breaker-docs`
