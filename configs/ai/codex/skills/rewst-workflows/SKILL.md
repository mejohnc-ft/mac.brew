---
name: rewst-workflows
description: Create, inspect, edit, publish, and test Rewst workflows, templates, triggers, and execution results through Rewst's GraphQL API and live trigger paths. Use when working on Rewst workflow automation, report templates, cron or form trigger behavior, publish-state verification, or execution-level debugging where browser UI alone is too ambiguous.
---

# Rewst Workflows

Use this as the umbrella skill for end-to-end Rewst workflow lifecycle work. Use the API as the source of truth. Use the browser only when a UI-only path is required or when visual validation matters.

## Quick Start

Run the helper:

```bash
python3 ~/.codex/skills/rewst-workflows/scripts/rewst_workflow.py workflow --workflow-id <workflow-id>
python3 ~/.codex/skills/rewst-workflows/scripts/rewst_workflow.py trigger --workflow-id <workflow-id>
python3 ~/.codex/skills/rewst-workflows/scripts/rewst_workflow.py execution --execution-id <execution-id> --include-context
```

For arbitrary queries or mutations:

```bash
python3 ~/.codex/skills/rewst-workflows/scripts/rewst_workflow.py request --payload-file /tmp/payload.json
```

## Skill Library

Prefer the narrower skills when the request is clearly specific:

- `$rewst-templates` for HTML report body, brand asset, and template marker work.
- `$rewst-trigger-testing` for cron, form, and webhook trigger-aware testing.
- `$rewst-execution-debugging` for post-run diagnosis, context merging, and task log inspection.

Use `$rewst-workflows` when the work crosses multiple stages, such as inspect + edit + publish + test.

## Authentication

The helper resolves the Rewst session cookie in this order:

1. `REWST_COOKIE`
2. `REWST_COOKIE_FILE`
3. `/private/tmp/workflow_query_result.json`

When the cookie is stored inside JSON or request logs, the helper extracts the `Cookie` header or raw `appSession=...` token automatically.

## Operating Sequence

Follow this order unless there is a clear reason not to:

1. Inspect the live workflow, trigger, and template state.
2. Decide whether the task is draft-only or a real publish.
3. Make API updates using explicit payload files.
4. Verify the live `updatedAt` values moved after publish.
5. Test the published version through the correct trigger path.
6. Inspect the resulting execution, merged context, and task logs.

## Common Tasks

### Inspect current state

- Use `workflow` to confirm the live workflow `updatedAt`, name, and trigger list.
- Use `trigger` to confirm cron vars, recipient lists, timezone, form ids, and enabled state.
- Use `template` to confirm the live report body or search for a marker string.

### Edit a current workflow

- Query the current workflow into a local JSON payload first.
- Preserve task ids, transition ids, action ids, and trigger ids unless you intentionally change them.
- Prefer editing payload files in `/private/tmp` or the workspace, then sending the mutation with `request`.
- For workflow updates that should become live immediately, use `createPatch: false`.

See [workflow-procedures.md](references/workflow-procedures.md) for the exact mutation pattern.

### Publish

- Do not assume a patch means the workflow is live.
- Verify publish by reading the live workflow again and checking `updatedAt`.
- If the user asks for “published before test,” stop after publish verification and tell them before running anything.

### Test

- If behavior depends on cron vars, form vars, or trigger recipients, use `test-trigger`.
- Do not use generic `testWorkflow` for cron verification unless you know that path preserves trigger context.
- For mail-sending tests, inspect resolved `email_addresses` and sendmail task count after the run.
- Ask before sending mail if there is any chance of spamming real inboxes.

### New workflow creation

- Prefer cloning an existing workflow when the new workflow is a variation of a proven one.
- Use `createWorkflow` only when a clean workflow is required.
- After creation, immediately inspect the saved workflow and triggers before making more edits.

## References

- Process and mutation examples: [workflow-procedures.md](references/workflow-procedures.md)
- Query shapes and execution checks: [graphql-patterns.md](references/graphql-patterns.md)
