---
name: rewst-child-tenant-context
description: Fix and review Rewst workflows that must run in selected child tenant context, especially Microsoft 365 mailbox, calendar, group, Exchange Online, and Graph operations that fail in child orgs with wrong-context, 401/404, or missing-integration errors. Use before editing any Rewst child-org M365 workflow.
---

# Rewst Child Tenant Context

Use this skill before changing any Rewst workflow that acts on a selected child tenant.

## First Rule

Copy the auth model from a known working workflow for the same M365 surface, not from a superficially similar API call.

For mailbox operations that Exchange Online can do, prefer the Exchange Online action used by working Calendar Delegation and shared mailbox workflows:

- action id: `059cce7f-1aba-478c-97ae-3687345c2e26`
- input shape: `json.CmdletInput.CmdletName` plus `json.CmdletInput.Parameters`
- child context: set `runAsOrgId` to the selected org expression
- pack overrides: required when the selected child org does not have Exchange Online installed directly

Selected org expression:

```jinja
{{- CTX.org_id.value if CTX.org_id.value is defined else CTX.org_id|d(ORG.ATTRIBUTES.id, true) -}}
```

Selected mailbox identity expression:

```jinja
{%- set selected = (CTX.target_user.value if CTX.target_user.value is defined else (CTX.target_user if CTX.target_user is defined and CTX.target_user else (CTX.selected_user.value if CTX.selected_user.value is defined else CTX.selected_user))) -%}
{%- if selected is string and selected|length > 0 and selected[0] == '{' -%}{%- set selected = selected|json -%}{%- endif -%}
{%- if selected is mapping -%}{{ selected.mail|d(selected.userPrincipalName|d(selected.id, true), true) }}{%- else -%}{{ selected }}{%- endif -%}
```

## Child Tenant Failure Classes

Classify the run before editing:

- `404 Resource does not exist`: task is likely running against the parent tenant while using a child object id.
- `Microsoft Graph integration is not installed`: Graph task is running in the child org without a selected owner-org Graph pack override.
- `Microsoft Exchange Online integration is not installed`: EXO task is running in the child org without a selected owner-org Exchange Online pack override.
- `401 Unauthorized` from Graph after overrides are present: the Graph route reached Graph but the delegated/admin permission is not enough for that endpoint in that child tenant. Do not keep toggling context settings; use a proven Exchange Online cmdlet if one exists.
- Workflow status `succeeded` with failed task log: Rewst can end through failure-note routing. Inspect task logs, not just execution status.

## Graph Pattern

Use Graph only when the endpoint is proven to work for child tenants.

For Graph action `microsoft_graph.graph_api_request`:

- set `input.client_kwargs.use_delegated_admin` to `true`
- set `runAsOrgId` to the selected org expression
- add the known Graph `packOverrides` when reusing the owner org Graph config:

```json
[
  {
    "packId": "5d6c8db9-ca60-4c4f-ac22-c91f80edd71d",
    "packConfigId": "019872df-0d95-7fd7-ae4d-27e28ef2448c",
    "configFallbackMode": "FAIL_ACTION",
    "configSelectionMode": "USE_SELECTED_ID",
    "searchInput": null
  }
]
```

If Graph still returns `401 Unauthorized`, stop using Graph for that task unless the user explicitly wants a consent/permissions project.

## Exchange Online OOO Pattern

For Out of Office in child tenants, use Exchange Online cmdlets instead of Graph `mailboxSettings`.

When the child org does not have EXO installed directly, add the known EXO `packOverrides` to every Exchange Online task in the path:

```json
[
  {
    "packId": "9b8a9f4f-3924-442f-b204-bc8908bc1435",
    "packConfigId": "0198852c-6365-7936-a00c-81df88733ab6",
    "configFallbackMode": "FAIL_ACTION",
    "configSelectionMode": "USE_SELECTED_ID",
    "searchInput": null
  }
]
```

Get current OOO:

```json
{
  "CmdletName": "Get-MailboxAutoReplyConfiguration",
  "Parameters": {
    "Identity": "<selected mailbox identity>"
  }
}
```

Set or schedule OOO:

```json
{
  "CmdletName": "Set-MailboxAutoReplyConfiguration",
  "Parameters": {
    "Identity": "<selected mailbox identity>",
    "AutoReplyState": "Enabled | Disabled | Scheduled",
    "ExternalAudience": "All | Known | None",
    "InternalMessage": "<message>",
    "ExternalMessage": "<message>",
    "StartTime": "<start datetime when scheduled>",
    "EndTime": "<end datetime when scheduled>"
  }
}
```

Use `remove_empty: true` and return `none` for parameters that should not be sent, such as messages or times when disabling.

## Scheduling Pattern

For start/end waits, use the native core delay action:

- action id: `bbfabe03-d3a1-43bf-b73b-9044f0a47409`
- input: `expires_at`
- working datetime format:

```jinja
{{ CTX.some_datetime|d('', true)|string ~ '.000000+0000' }}
```

Scheduled OOO end must do real work before the end note:

```text
delay_until_ooo_end_note -> Set-MailboxAutoReplyConfiguration Disabled -> update_psa_ticket_ooo_end -> END
```

Do not route the end delay directly to the ticket note; that only records success and does not remove OOO.

## Validation Checklist

Before saying it is fixed:

1. Inspect the failed execution task logs and merged contexts.
2. Read the live workflow with `packOverrides`, `actionId`, `runAsOrgId`, and task inputs included.
3. Compare against a known working workflow for the same surface.
4. Verify every M365 task in the path has the correct child-context shape.
5. Verify failure routes post one ticket note and then end.
6. Do not run a live OOO/calendar/mailbox test unless the user accepts that it will change a real mailbox and ticket.
