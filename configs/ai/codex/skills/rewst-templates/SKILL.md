---
name: rewst-templates
description: Inspect, edit, and validate Rewst HTML templates used by workflows, webhooks, emails, and report pages. Use when changing report layout, logo treatment, hosted or inline assets, tabbed interfaces, body markers, or template publish state without guessing from the browser render alone.
---

# Rewst Templates

Use this skill for template-body work, not general workflow branching or execution debugging.

## Shared Helper

Use the shared Rewst GraphQL helper from:

```bash
python3 ~/.codex/skills/rewst-workflows/scripts/rewst_workflow.py template --template-id <template-id>
```

For direct mutations, prepare a payload file and send it with:

```bash
python3 ~/.codex/skills/rewst-workflows/scripts/rewst_workflow.py request --payload-file /tmp/update_template.json
```

## Workflow

1. Inspect the live template body and `updatedAt`.
2. Change the HTML or CSS in a local payload file.
3. Update the template directly.
4. Verify the live `updatedAt` changed.
5. Confirm body markers such as a hosted image URL or a specific class name.
6. If the user wants a delivery test, stop after publish and tell them before running mail-sending verification.

## Template Rules

- Prefer hosted or inline images over brittle third-party hotlinks.
- Constrain logos with container width plus `img { width: 100%; height: auto; object-fit: contain; }`.
- Keep structure stable when restyling an existing report. Change presentation before changing the data layout.
- When tabs or collapsibles exist already, preserve the original ids and behavior unless the user explicitly wants a new interaction model.

## Reference

See [template-procedures.md](references/template-procedures.md).

