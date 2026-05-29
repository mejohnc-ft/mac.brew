---
name: rewst-execution-debugging
description: Diagnose Rewst workflow runs by inspecting execution context, merged published vars, task logs, failures, branch outcomes, and downstream side effects. Use when a workflow produced the wrong result, skipped a branch, failed mid-run, sent to the wrong recipient, or rendered incorrect report data.
---

# Rewst Execution Debugging

Use this skill after a run exists.

## Shared Helper

Inspect an execution with:

```bash
python3 ~/.codex/skills/rewst-workflows/scripts/rewst_workflow.py execution --execution-id <execution-id> --include-context
```

## Workflow

1. Read overall execution status and `numSuccessfulTasks`.
2. Merge execution contexts before reading keys like `email_addresses`.
3. Inspect `taskLogs` by `originalWorkflowTaskName`.
4. For mail issues, count successful `core_sendmail` tasks and inspect their queue result.
5. For report issues, compare rendered output against the execution context that fed the template.

## Debugging Rules

- Do not infer from screenshots when task logs or merged context can answer directly.
- A succeeded workflow can still have wrong branch behavior; inspect the context that drove the branch.
- A correct trigger config does not prove the execution used it; inspect the actual execution context.

## Reference

See [execution-debugging-patterns.md](references/execution-debugging-patterns.md).

