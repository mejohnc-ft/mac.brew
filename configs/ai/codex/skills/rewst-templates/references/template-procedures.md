# Template Procedures

## Inspect a template

```bash
python3 ~/.codex/skills/rewst-workflows/scripts/rewst_workflow.py template --template-id <template-id>
python3 ~/.codex/skills/rewst-workflows/scripts/rewst_workflow.py template --template-id <template-id> --marker '<marker>'
```

Use marker checks for:

- hosted image URLs
- CSS class names
- report titles
- tab ids

## Update a template safely

Use `updateTemplate` directly with the full template body. Prefer keeping:

- `name`
- `language`
- `description`
- `content_type`

stable unless there is a deliberate change.

## Visual validation

After template publish:

- verify `updatedAt`
- verify marker presence
- use a browser only for final rendering checks

## Report-specific guardrails

- Do not break existing table structure just to restyle a report.
- Preserve ids like `tab-workflow`, `tab-org`, and `tab-user` when they drive existing JS.
- If an image breaks the header, fix the container sizing before changing the whole layout.

