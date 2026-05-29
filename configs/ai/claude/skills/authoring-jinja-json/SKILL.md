---
name: authoring-jinja-json
description: Writes and debugs Jinja templates and JSON payloads used in Rewst and API calls. Use for option generators, mapping fields, safe defaults, and producing validated request bodies for Graph/Halo/3rd-party APIs.
---

# Authoring Jinja + JSON

## Rules
- Default everything at boundaries: |default("") / |default([]) / |default({})
- Never assume field presence; prefer explicit mapping tables
- Generate both: (a) JSON shape, (b) example instance

## Deliverables
- Jinja snippet (with comments for assumptions)
- JSON payload + notes on required/optional fields
- Edge cases: nulls, missing keys, empty lists, unexpected types

## Debug protocol
- Identify the failing expression
- Reproduce with a minimal input object
- Patch with guards and defaults
