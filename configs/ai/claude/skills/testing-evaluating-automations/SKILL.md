---
name: testing-evaluating-automations
description: Creates test plans and evaluations for Rewst automations, Jinja/JSON mappings, and agent escalation flows. Use to define acceptance criteria, edge cases, rollback checks, and regression suites.
---

# Testing & Evaluating Automations

## Minimum test set per workflow
- Happy path
- Missing/invalid inputs
- Partial failure (API 4xx/5xx)
- Idempotency / retries
- Rollback or safe stop

## Deliverables
- Acceptance criteria (binary checks)
- Test vectors (sample inputs)
- Expected outputs (ticket note content + result codes)
