# Trigger Testing Procedures

## Why not generic testWorkflow

Generic `testWorkflow` can drop trigger context. That is unsafe for:

- cron branch logic
- recipient merge logic
- trigger-name checks
- form defaults

Use `testWorkflowTrigger` instead.

## Verification checklist

Before test:

- trigger enabled
- expected `cron` string
- expected timezone
- expected recipient vars

After test:

- execution `status`
- merged `email_addresses`
- successful `core_sendmail` count
- sendmail queue response

## Common failure shape

If a run only sends to the primary address:

- inspect whether the non-cron/default branch ran
- inspect merged execution context, not only trigger config

## Webhook note

Webhook tests are often better validated by reading the rendered response body or template markers than by using sendmail-oriented checks.

