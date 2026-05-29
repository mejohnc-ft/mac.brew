# PROJECT CONTEXT — MSP Automations (Rewst + M365 + Azure AI)

## Mission
Build repeatable, client-safe automations for an MSP using Rewst workflows, Jinja/JSON templating, and Microsoft/Azure integrations.

## Non-negotiables
- Tenant separation: never mix identifiers, secrets, or logs across clients.
- Secrets: never hardcode; always reference vault/secure variables.
- Human-in-the-loop for destructive actions (disable user, wipe device, license removal, shipping charges, etc.).

## Primary systems
- Rewst: forms, option generators, tasks, workflows, reusable subflows
- Microsoft: Entra ID, Intune, Graph API, Copilot Studio (if applicable)
- PSA: HaloPSA (ticket creation/updates)
- Azure AI Foundry: agents, tools/MCP, identity + consent patterns

## Output standards
- Provide artifacts as:
  1) Rewst workflow outline (steps + inputs/outputs)
  2) Jinja templates (linted, safe defaults)
  3) JSON payloads (schema shape + example)
  4) Test plan (happy path + edge cases + rollback)

## Naming conventions
- Workflows: MSP.<Domain>.<Capability>.<Verb>
- Variables: snake_case; env vars UPPER_SNAKE_CASE
- Rewst fields: align to SharePoint/PSA canonical names where relevant

## Environments
- DEV: sandbox tenant + Rewst dev org
- STAGE: pilot client or isolated test group
- PROD: client tenants (must be explicitly stated)

## Logging & evidence
Every automation must emit:
- correlation_id
- tenant/client identifier
- input summary (redacted)
- action summary
- result + next step
