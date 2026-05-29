# Rewst Workflow API Gotchas

Hard-won lessons from building workflows programmatically.

## Authentication

- Use `browser_cookie3.chrome(domain_name="rewst.io")` to get the FULL cookie jar, not just the appSession cookie value
- Pass cookies via `requests.post(..., cookies=jar)` — using `Cookie: appSession=...` header alone gives partial permissions
- ALWAYS include `x-rewst-org-id` header — without it, most queries return "Not Authorized"
- The session supports reads of any workflow but writes require the full cookie jar
- Name/description updates work with simpler auth than task mutations — don't assume partial success means full access

## Task Creation

- `actionId` is NOT NULL in the database — every task MUST have a real action ID
- Task IDs MUST be valid UUIDs — short strings like "validate" cause `invalid input syntax for type uuid`
- The `tasks` array in `updateWorkflow` REPLACES all tasks — always send the complete array
- `metadata.position` controls canvas layout — without it, tasks stack at (0,0)
- `transitionMode` values: `FOLLOW_ALL` (default, all transitions fire) or `FOLLOW_FIRST` (first matching condition wins — use for routers)

## Transitions — The Critical Part

- **Use `do` field, NOT `to` field** — `to` stores but doesn't render on canvas
- `do` is `[String]` — an array of task IDs that this transition activates
- `publish` field MUST be present (even as `[]`) or the transition silently drops
- `from` and `to` fields are NULL in working transitions (Incident Buddy confirms this)
- When building with existing task IDs, you MUST re-read the full task data before adding transitions
- Partial task updates (just sending `next` without other fields) cause `Cannot convert undefined or null to object`

## Two-Step Build Pattern

You CANNOT create tasks and wire `do`-field transitions in one shot because:
1. The `do` field references task IDs that may not exist yet
2. The server validates `do` targets against the task table

**Step 1:** Create all tasks with `next: []`, use `overwrite: true`
**Step 2:** Query the tasks back, add transitions to `next`, update again (without `overwrite`)

## Trigger Creation

- `createTrigger` is a separate mutation from `updateWorkflow`
- Webhook trigger type ID: `e9dca0d3-f93f-47ea-88fc-df2c9aee037b`
- Always set `isActivatedForOwner: true` or the trigger won't fire for the owning org
- Triggers survive task rebuilds — they persist across `overwrite: true` updates

## Canvas Rendering

- Tasks without `metadata.position` render at (0,0) and overlap
- Transitions without `do` targets show as disconnected tasks (no lines)
- The `targetHandles` field affects which port the line connects to but isn't required for basic rendering
- `orientation` defaults work fine — don't need to set it

## Common Errors

| Error | Cause | Fix |
|-------|-------|-----|
| `Cannot read properties of undefined (reading 'map')` | Task missing `next` field | Add `next: []` to every task |
| `Cannot read properties of undefined (reading 'filter')` | Transition using `to` instead of `do` | Use `do: [task_id]` with `publish: []` |
| `Cannot convert undefined or null to object` | Partial task object missing required fields | Include all fields: actionId, input, timeout, etc. |
| `invalid input syntax for type uuid` | Task ID is not a UUID | Use `str(uuid.uuid4())` |
| `violates foreign key constraint "workflow_tasks_action_id_fkey"` | actionId doesn't exist in the actions table | Search for the real action ID first |
| `Not Authorized` | Missing cookie jar or org header | Use full `browser_cookie3` jar + `x-rewst-org-id` header |
