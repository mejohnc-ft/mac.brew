# Repo Patterns

Use these concrete repo patterns before editing a workflow.

## 1. Broken Child-Org Graph Pattern

File:

- `workflows/report-drafts/workflow-cit-mfa-conditional-access-audit.json`

Why it fails in bulk child-org fanout:

- Graph tasks use `microsoft_graph.graph_api_request`
- `use_delegated_admin` is `false`
- `pack_overrides` is empty on the Graph tasks
- bulk runs were triggered with `target_org_id`, so child org execution required Graph to be installed in each target org

Observed runtime failure:

- `Microsoft Graph integration is not installed. Either install it or use integration overrides.`

Important detail:

- snapshot persistence in this workflow is already target-org aware via `CTX.target_org_id`
- the persistence path was not the blocker

## 2. Working Cross-Tenant Override Pattern

File:

- `workflows/report-drafts/workflow-cit-privileged-guest-account-audit.json`

What it shows:

- Graph tasks still use `microsoft_graph.graph_api_request`
- `use_delegated_admin` is still `false`
- each Graph task carries a `pack_overrides` block
- override uses:
  - `configSelectionMode: USE_SELECTED_ID`
  - `configFallbackMode: FAIL_ACTION`
  - `packId: 5d6c8db9-ca60-4c4f-ac22-c91f80edd71d`
  - `packConfigId: 019872df-0d95-7fd7-ae4d-27e28ef2448c`

What this means:

- the working child-org pattern in this repo is explicit pack-config reuse
- the workflow can still save the final snapshot into `CTX.target_org_id`

## 3. Target-Org Snapshot Persistence Pattern

Files:

- `workflows/report-drafts/workflow-cit-mfa-conditional-access-audit.json`
- `workflows/report-drafts/workflow-cit-privileged-guest-account-audit.json`
- `workflows/report-drafts/workflow-cit-os-lifecycle-tracker.json`

What to copy:

- use `CTX.target_org_id` when saving org variables
- use `CTX.target_client_name` for report labeling
- keep owner-org orchestration separate from target-org persistence

## 4. Bulk Fanout Trigger Pattern

File:

- `scripts/run_mfa_ca_all_orgs.py`

What it proves:

- bulk `testWorkflow` fanout can pass target-org context cleanly
- a successful trigger only proves dispatch, not runtime viability

Use it to remember:

- queueing dozens of executions is not evidence the workflow is child-org safe
- inspect execution errors before calling the pattern complete
