---
name: building-rewst-workflows
description: Build and update Rewst workflows programmatically via the GraphQL API. Creates real connected workflows with actual integration actions, Jinja transitions, webhook triggers, and canvas-positioned tasks. Use when creating new workflows, modifying existing ones, adding tasks/transitions, or wiring up triggers.
---

# Building Rewst Workflows

Build complete, connected Rewst workflows through the GraphQL API. No browser UI needed for task creation, transition wiring, or trigger setup.

## Authentication

Rewst uses cookie-based auth from the Chrome browser session. NEVER ask the user for credentials.

```python
import browser_cookie3, requests

jar = browser_cookie3.chrome(domain_name="rewst.io")
url = "https://api.rewst.io/graphql"
headers = {
    "Content-Type": "application/json",
    "x-rewst-org-id": "01983d3f-ecb7-7b80-9d05-726dbe1a90d0",
}

def gql(query, variables=None):
    r = requests.post(url, json={"query": query, "variables": variables or {}}, headers=headers, cookies=jar, timeout=30)
    d = r.json()
    if "errors" in d:
        raise Exception(d["errors"][0]["message"])
    return d["data"]
```

If the cookie is stale, run:
```bash
python3 "$HOME/.codex/skills/rewst-session-auth/scripts/export_rewst_session.py" check
```

**Org ID:** `01983d3f-ecb7-7b80-9d05-726dbe1a90d0` — ALWAYS pass as `x-rewst-org-id` header.

## CRITICAL Rules

### 1. Use REAL integration actions, not noops

Before building, search for the actual integration action IDs:

```python
# Find actions by integration
actions = gql('{ actions(search:{ref:{_ilike:"%halo_psa%"}}, limit:50) { id name ref category } }')

# Common action refs:
# halo_psa.list_tickets, halo_psa.get_ticket, halo_psa.add_or_update_tickets
# halo_psa.add_or_update_actions, halo_psa.list_agents
# microsoft_graph.graph_api_request
# core.noop (ONLY for routing/validation/transform tasks)
```

`core.noop` ID: `cf6cc66e-a149-4f06-82f5-59f4d72ba93e` — use ONLY for routing, validation, and data transform tasks. Every operational task MUST use a real integration action.

### 2. Transitions use the `do` field, NOT `to`

This is the #1 gotcha. Rewst transitions route via `do` (array of task IDs), not `to`.

```python
# WRONG — renders in API but NOT visible on canvas:
{"to": target_task_id, "label": "next"}

# CORRECT — renders as connected lines on canvas:
{"do": [target_task_id], "label": "next", "publish": []}
```

The `do` field is `[String]` — an array of task IDs (no-hyphen UUID format works, standard UUID also works).

### 3. Transitions MUST include `publish` field

Even if empty, the `publish: []` field is required or the transition silently fails.

```python
def transition(target_ids, label, when=""):
    """Create a properly-formed Rewst transition."""
    return {
        "id": str(uuid.uuid4()),
        "label": label,
        "when": when,
        "do": target_ids if isinstance(target_ids, list) else [target_ids],
        "publish": [],
    }
```

### 4. Tasks MUST include ALL required fields

Partial task objects cause `Cannot convert undefined or null to object` errors. Every task needs:

```python
def task(id, name, action_id, x, y, publish_as="", mode="FOLLOW_ALL", inputs=None):
    return {
        "id": id,  # UUID (auto-generated if new)
        "name": name,
        "actionId": action_id,  # MUST be a valid action UUID
        "publishResultAs": publish_as,
        "transitionMode": mode,  # FOLLOW_ALL or FOLLOW_FIRST
        "timeout": 300,
        "input": inputs or {},
        "next": [],  # Transitions added after task creation
        "metadata": {"position": {"x": x, "y": y}},
    }
```

### 5. Two-step build process

Rewst's API will error if you update tasks and include `do`-field transitions in the same mutation when the task doesn't already exist (it validates `do` targets against existing task IDs). Build in two steps:

**Step 1:** Create all tasks with `next: []` (no transitions), using `overwrite: true`:
```python
wf = {"id": workflow_id, "tasks": all_tasks_with_empty_next}
gql("mutation($wf: WorkflowInput!) { updateWorkflow(workflow: $wf, overwrite: true) { id tasks { id name } } }", {"wf": wf})
```

**Step 2:** Re-read the task IDs and update with transitions:
```python
# Get current task data with all fields
tasks = gql('{ workflow(where:{id:"' + wf_id + '"}) { tasks { id name actionId publishResultAs transitionMode timeout input next { id label when do publish } } } }')

# Add transitions using do field
for task in tasks:
    if task["name"] == "Router":
        task["next"] = [transition(target_id, "label", "{{ condition }}")]

gql("mutation($wf: WorkflowInput!) { updateWorkflow(workflow: $wf) { id tasks { name next { label do } } } }", {"wf": {"id": wf_id, "tasks": tasks}})
```

### 6. Canvas layout

Position tasks for readability. Use this grid:

```
Trigger/Entry:     x=400, y=0
Router:            x=400, y=0
Lane tasks:        x=80+(lane*160), y=200  (spread horizontally)
Convergence:       x=400, y=400
End:               x=400, y=550
```

For fan-out patterns (router → N lanes → convergence):
```
         [Router]          y=0
    /   |   |   |   \
[T1] [T2] [T3] [T4] [T5]  y=200
    \   |   |   |   /
      [Convergence]        y=400
```

### 7. Trigger creation

```python
# Webhook trigger
trigger = gql("""mutation($t: TriggerCreateInput!) { 
  createTrigger(trigger: $t) { id name enabled } 
}""", {"t": {
    "name": "Webhook Trigger",
    "triggerTypeId": "e9dca0d3-f93f-47ea-88fc-df2c9aee037b",  # Webhook type
    "enabled": True,
    "isActivatedForOwner": True,
    "workflowId": workflow_id,
}})
```

Common trigger type IDs:
| Type | ID |
|------|----|
| Webhook | `e9dca0d3-f93f-47ea-88fc-df2c9aee037b` |
| Cron Job | `4e7593af-7d63-49f4-9508-b448460b8f77` |
| Form Submission | `24772a85-c3eb-4d94-b7f4-0677ac289ffa` |

## Common Integration Action IDs

Search for these at build time — IDs may vary by org:

```python
# Halo PSA
halo_psa.list_tickets       # List/search tickets
halo_psa.get_ticket          # Get single ticket with details
halo_psa.add_or_update_tickets  # Create or update tickets
halo_psa.add_or_update_actions  # Add notes, log time
halo_psa.list_agents         # List/search agents

# Microsoft Graph
microsoft_graph.graph_api_request  # Generic Graph API call

# Rewst Core
core.noop                    # No-op (routing/transform only)

# Anthropic
anthropic.create_messages    # Claude AI call
```

## Querying Workflows

```python
# Get workflow with full task and transition data
workflow = gql('''{ workflow(where:{id:"WORKFLOW_ID"}) { 
  id name description
  tasks { id name actionId action { name ref } publishResultAs transitionMode 
    input next { id to from label when do publish } metadata }
  triggers { id name enabled triggerType { name } parameters }
} }''')
```

## Workflow Update Patterns

### Adding a task to an existing workflow
1. Query current tasks
2. Append new task to the array
3. Add transitions from/to the new task
4. Submit full task array via `updateWorkflow`

### Changing an action on a task
1. Query current tasks
2. Find the task, change `actionId`
3. Submit full task array (you MUST include all tasks, not just the changed one)

### The `updateWorkflow` mutation does NOT support partial updates for tasks
If you send a `tasks` array, it REPLACES all tasks. Always query first, modify, then send the complete array.

## Reference: Incident Buddy Pattern

The proven workflow architecture for multi-lane routing:

```
[Webhook Trigger]
       ↓
[Route Action] (noop, FOLLOW_FIRST)
  ├─ {{ CTX.action == 'queue' }}    → [Lookup Agent] → [Get Queue] → [Response]
  ├─ {{ CTX.action == 'get_ticket' }} → [Get Ticket] → [Response]
  ├─ {{ CTX.action == 'log_time' }}   → [Halo Add Actions] → [Response]
  └─ {{ CTX.action == 'search' }}     → [List Tickets] → [Response]
       ↓ (all lanes converge)
[Format Response] (noop)
```

Key pattern details:
- Router task uses `transitionMode: "FOLLOW_FIRST"` — only the first matching condition fires
- Each lane has its own Halo PSA action (NOT noop placeholders)
- All lanes converge to a shared Format Response task
- Transitions use `do: [task_id]` with Jinja `when` conditions
