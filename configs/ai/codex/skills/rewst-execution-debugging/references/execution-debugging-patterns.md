# Execution Debugging Patterns

## Merge execution contexts

`workflowExecutionContexts(workflowExecutionId: ...)` returns a JSON list. Merge dict items in order before checking:

- `email_addresses`
- `group_by`
- `result_type`
- `cron_*`

## Mail debugging

Inspect all of:

- merged `email_addresses`
- `cron_email_addresses`
- `cron_additional_recipients`
- `core_sendmail` succeeded count
- sendmail queue ids

## Template debugging

If the rendered report looks wrong:

1. confirm the live template body marker
2. inspect execution context inputs
3. inspect the template update task log if the workflow rewrites templates mid-run

## Branch debugging

When the wrong branch appears to have run:

- inspect the branch-driving context key in merged execution context
- inspect the corresponding task scheduling sequence in `taskLogs`
- do not rely on UI labels alone
