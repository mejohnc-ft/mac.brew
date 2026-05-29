---
name: "ralph-loop-issues"
description: "Drive remaining issue queues through chunked dispatch cycles with explicit completion promises and conflict-aware sequencing using existing dispatch tooling. Use this when you want autonomous, bounded issue execution over many cycles."
---


# Skill: Ralph Loop Issues

> **Chunked multi-issue execution loop (Ralph Loop style)**
>
> Trigger phrase: `$ralph-loop-issues`
>
> Applies to: Open issue queues with explicit labels, explicit issue lists, or RFC issue subsets

---

## Overview

Use this skill to process issue backlogs in fixed-size chunks (waves) without dropping context each cycle.

This is the intended workflow:

1. Select a bounded issue set (`--label` or `--issues`)
2. Build or source a dispatch manifest for the batch
3. Run `/dispatch`-style execution per batch
4. Track completion state with a deterministic marker
5. Continue automatically via a Ralph Loop completion predicate

---

## ALWAYS

### Inputs

- `--label <label>` OR `--issues <csv>` must be provided.
- `--chunk-size` controls batch width (default: 4).
- `--max-parallel` controls in-wave parallelism (default: 4).
- `--skip-low-confidence` is **false** by default; ask before continuing if unresolved zone inference is `none`.

### Runtime Contract

- Work only on `main`-descended issue branches.
- Keep each batch scoped and report status for each issue.
- Use only existing orchestration primitives:
  - `.claude/commands/plan-work.md` for slicing and conflict checks
  - `.claude/commands/dispatch.md` for wave execution
  - `scripts/dispatch.sh` for manifest execution
- Do not merge or rebase across unfinished waves.

### Deterministic completion with Ralph Loop

When running long batches, initialize the loop with a completion predicate that flips only when:

- target issue state file exists (`.dispatch/runs/<run-id>.done`) **or**
- target selector has no remaining open issues.

Example:

```bash
/Users/jchristensen/.claude/skills/ralph-loop/invoke.js \
  "Process dev-teammate backlog in 4-issue chunks" \
  --completion-promise "/Users/jchristensen/Git/centrexai-core/.dispatch/runs/dev-teammate.done exists" \
  --checkpoint-on-iteration
```

### Batch Loop

1. Resolve the target set once at the start of the cycle (label or issue list).
2. For each chunk:
   1. Run `/plan-work` first with the same selector if needed for planning.
   2. Run `/dispatch --dry-run` to validate zoning/dependency conflict handling.
   3. Run `/dispatch` for that chunk.
   4. Mark result in `.dispatch/runs/<run-id>.md`.
3. Update the run marker and continue until all chunks are processed.

### Reporting

After each chunk, report:

- chunk id / issue numbers
- zone mix and conflict decisions
- QA/gate/dispatch outcome
- PR URLs and merge blockers

---

## NEVER

- Never mix unrelated issue sets in one chunk (must stay in one selector family).
- Never skip failed safety checks (dispatch launch preflight, QA gate in workers, or CI monitor failures).
- Never continue past a hard blocker that needs architecture/product decisions.
- Never assume zone inference confidence is always valid when source lacks explicit `zone:*` labels.

---

## Practical Workflow Example

```bash
# 1) Gather target set
gh issue list --state open --label "dev-teammate" --json number,title,labels,body

# 2) Chunk and execute (4 issues at a time, 2 parallel within wave)
#   - manual planning + dry-run each chunk
#   - then dispatch the chunk manifest / issue list

# 3) Finalize marker for loop continuation
touch .dispatch/runs/dev-teammate.done
```

---

## Guardrails

- If chunking or inferred zone conflicts are ambiguous, pause and ask for user confirmation.
- If any issue has `dispatch:active`/in-flight branch state, skip and re-enqueue in a later chunk.
- Preserve branch hygiene; clean stale local/remote branches after merges.

