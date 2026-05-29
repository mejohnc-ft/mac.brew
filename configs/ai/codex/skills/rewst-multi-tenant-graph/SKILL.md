---
name: rewst-multi-tenant-graph
description: Inspect, design, and fix Rewst workflows that call Microsoft Graph across child orgs or tenant portfolios. Use when a Rewst workflow needs to run for many orgs, save snapshots into target orgs, fan out Graph-backed collectors, or fails with child-org auth errors such as "Microsoft Graph integration is not installed" even though the owner org works.
---

# Rewst Multi-Tenant Graph

Build child-org Microsoft Graph workflows from the execution model first, not from the endpoint list. In this repo, the repeated failure mode is bulk fanout into child orgs while the workflow still assumes a Graph integration is installed in every target org.

## Workflow

1. Inspect the workflow before editing it.
2. Classify the auth model.
3. Verify target-org persistence separately from Graph auth.
4. Test one child org first.
5. Only then bulk fan out.

## Inspect First

Check these fields on every Graph task:

- `action: microsoft_graph.graph_api_request`
- `input.client_kwargs.use_delegated_admin`
- `run_as_org_id`
- `pack_overrides`

Check these cross-tenant context fields on the workflow:

- `CTX.target_org_id`
- `CTX.target_client_name`
- any save step with `org_id`
- any webhook or fanout input that injects target org context

Use `rg` first:

```bash
rg -n "microsoft_graph\\.graph_api_request|use_delegated_admin|pack_overrides|run_as_org_id|target_org_id" workflows scripts -g '*.json' -g '*.py'
```

## Auth Models

Use one of these models deliberately.

### Model A: Per-org Graph install

Use this only when every child org has its own Microsoft Graph integration installed and maintained.

Signals:

- Graph tasks have empty `pack_overrides`
- fanout executes with `orgId = child org`
- workflow succeeds only where Graph is installed in that org

Failure signature:

- `"Microsoft Graph integration is not installed. Either install it or use integration overrides."`

### Model B: Owner-org Graph config reused across child orgs

Use this when one known-good Microsoft Graph config in the owner org should service many child-org runs.

Signals:

- each Graph task has a `pack_overrides` entry
- `configSelectionMode` is `USE_SELECTED_ID`
- `configFallbackMode` is `FAIL_ACTION`
- `packConfigId` points at the chosen Graph config
- workflow still saves its snapshot into `CTX.target_org_id`

This is the repo's current working pattern for cross-tenant Graph.

## Repo Examples

Read [references/repo-patterns.md](references/repo-patterns.md) before changing a multi-tenant Graph workflow.

The two key examples are:

- broken child-org pattern: `workflows/report-drafts/workflow-cit-mfa-conditional-access-audit.json`
- working override pattern: `workflows/report-drafts/workflow-cit-privileged-guest-account-audit.json`

## Rules

Follow these rules in order.

### 1. Separate auth from persistence

Do not confuse:

- where Graph calls authenticate
- where the final snapshot is written

A workflow can call Graph with an owner-org override and still write the finished snapshot into:

```jinja
{{ CTX.target_org_id | d(ORG.ATTRIBUTES.id) | d('') }}
```

That is the correct cross-tenant shape for report collectors.

### 2. Do not assume `use_delegated_admin` fixes child-org auth

In this repo, the repeated issue is not the boolean alone. The practical blocker is missing `pack_overrides` on fanout workflows that run against child orgs.

Treat `use_delegated_admin` as secondary until the pack configuration path is proven.

### 3. Override every Graph task, not just one

If a workflow uses owner-org Graph config reuse, add the selected Graph override to every Graph task in the path. Partial coverage produces confusing mixed failures.

### 4. Keep target-org saves explicit

Save snapshots and org vars with `CTX.target_org_id` and name them with `CTX.target_client_name` where appropriate. Do not let a cross-tenant collector silently save into the owner org unless that is the explicit design.

### 5. Test one child org before bulk fanout

Always run this order:

1. owner org sanity check
2. one representative child org
3. inspect execution logs
4. only then run bulk fanout

Never treat "queued 53 executions" as success.

## Diagnosis Checklist

When a child-org run fails, inspect these first:

- did the execution run in the child org or owner org
- does every Graph task have `pack_overrides`
- does the override use `USE_SELECTED_ID`
- is the fallback `FAIL_ACTION`
- does `packConfigId` point at the expected Graph config
- is the workflow writing results to `CTX.target_org_id`
- is the error really auth, or an endpoint/resource issue

Classify the failure:

- integration missing in child org
- bad or missing override
- unsupported endpoint
- paging gap
- permission gap inside an otherwise valid Graph config

## Endpoint Sanity

Before chasing auth, check whether the endpoint itself is usable.

Example from this repo:

- `credentialUserRegistrationDetails` is deprecated / unavailable for current use and should not be used as proof that all Graph auth is broken

Unsupported endpoints and auth failures look different. Separate them.

## Bulk Fanout Pattern

When adding a bulk runner:

- send `target_org_id`
- send `target_client_name`
- keep the workflow id stable and explicit
- collect execution ids
- inspect at least one success and one failure before trusting the batch

If the first child-org run fails with the integration-missing error, stop and fix the workflow. Do not keep treating that as a scheduling problem.

## Output Standard

When finishing a multi-tenant Graph change, report:

- which auth model the workflow now uses
- which file or live workflow was changed
- which target org was used for first validation
- whether the snapshot writes into the target org
- whether bulk fanout is now safe
- any remaining endpoint or paging gaps
