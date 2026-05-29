---
name: designing-rewst-workflows
description: Designs Rewst workflows (intake → validate → execute → verify → ticket notes) for MSP automations. Use when creating or refactoring Rewst forms, option generators, tasks, and reusable subflows.
---

# Designing Rewst Workflows

## Requirements intake
- Identify trigger (form / webhook / schedule / PSA event)
- Define inputs + validations + required approvals
- Define outputs: ticket notes, inventory updates, audit log events

## Deliverables
1) Workflow skeleton (steps + I/O at each step)
2) Rewst task list (atomic steps, idempotent where possible)
3) Error handling + rollback strategy
4) Observability: correlation_id + result codes

## Handoff
Use shared/HANDOFF-CONTRACT.md JSON envelope.
