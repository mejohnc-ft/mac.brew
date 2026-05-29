---
name: rewst-trigger-testing
description: Test Rewst workflows through the correct trigger path so cron, form, and webhook vars behave like the live automation. Use when verifying recipient fanout, cron windows, trigger-branch logic, form defaults, webhook rendering, or any behavior that generic workflow tests can misrepresent.
---

# Rewst Trigger Testing

Use this skill when trigger context matters.

## Shared Helper

Use the shared helper:

```bash
python3 ~/.codex/skills/rewst-workflows/scripts/rewst_workflow.py test-trigger \
  --workflow-id <workflow-id> \
  --trigger-id <trigger-id> \
  --org-id <org-id> \
  --org-name "<org-name>" \
  --wait
```

## Workflow

1. Inspect the live trigger first.
2. Confirm the exact primary and additional recipients before any mail test.
3. Use `test-trigger`, not generic `testWorkflow`, when cron or form vars drive behavior.
4. Wait for the execution and inspect:
   - merged `email_addresses`
   - `cron_email_addresses`
   - `cron_additional_recipients`
   - number of successful `core_sendmail` tasks
5. Report what the execution resolved, not what the trigger looked like beforehand.

## Safety

- If a test can spam real inboxes, say that explicitly before sending.
- For cron tests, verify the schedule and the reporting window separately from the email fanout.
- If the user says “publish before test,” do not start the run until the live `updatedAt` confirms publish.

## Reference

See [trigger-testing-procedures.md](references/trigger-testing-procedures.md).

