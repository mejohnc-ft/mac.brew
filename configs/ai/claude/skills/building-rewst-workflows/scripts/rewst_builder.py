#!/usr/bin/env python3
"""Rewst Workflow Builder — programmatically create/update workflows via GraphQL.

Usage:
    python3 rewst_builder.py inspect <workflow-id>
    python3 rewst_builder.py actions <search-term>
    python3 rewst_builder.py triggers
    python3 rewst_builder.py build <workflow-id> --payload <json-file>
    python3 rewst_builder.py connect <workflow-id> --payload <json-file>
    python3 rewst_builder.py add-trigger <workflow-id> --type webhook --name "My Trigger"
"""

import argparse
import json
import sys
import uuid
from pathlib import Path

try:
    import browser_cookie3
    import requests
except ImportError:
    print("pip install browser_cookie3 requests", file=sys.stderr)
    sys.exit(1)

ORG_ID = "01983d3f-ecb7-7b80-9d05-726dbe1a90d0"
API_URL = "https://api.rewst.io/graphql"
NOOP_ACTION = "cf6cc66e-a149-4f06-82f5-59f4d72ba93e"
TRIGGER_TYPES = {
    "webhook": "e9dca0d3-f93f-47ea-88fc-df2c9aee037b",
    "cron": "4e7593af-7d63-49f4-9508-b448460b8f77",
    "form": "24772a85-c3eb-4d94-b7f4-0677ac289ffa",
}


def get_session():
    jar = browser_cookie3.chrome(domain_name="rewst.io")
    headers = {"Content-Type": "application/json", "x-rewst-org-id": ORG_ID}
    return jar, headers


def gql(jar, headers, query, variables=None):
    r = requests.post(API_URL, json={"query": query, "variables": variables or {}}, headers=headers, cookies=jar, timeout=30)
    d = r.json()
    if "errors" in d:
        print(f"ERROR: {d['errors'][0]['message']}", file=sys.stderr)
        return None
    return d.get("data")


def make_task(task_id, name, action_id, x, y, publish_as="", mode="FOLLOW_ALL", inputs=None):
    return {
        "id": task_id or str(uuid.uuid4()),
        "name": name,
        "actionId": action_id,
        "publishResultAs": publish_as,
        "transitionMode": mode,
        "timeout": 300,
        "input": inputs or {},
        "next": [],
        "metadata": {"position": {"x": x, "y": y}},
    }


def make_transition(target_ids, label, when=""):
    if isinstance(target_ids, str):
        target_ids = [target_ids]
    return {
        "id": str(uuid.uuid4()),
        "label": label,
        "when": when,
        "do": target_ids,
        "publish": [],
    }


def cmd_inspect(args):
    jar, headers = get_session()
    data = gql(jar, headers, '''{ workflow(where:{id:"%s"}) {
        id name description
        tasks { id name actionId action { name ref category } publishResultAs transitionMode
            input next { id label when do } metadata }
        triggers { id name enabled triggerType { name } parameters }
    } }''' % args.workflow_id)
    if not data:
        return
    wf = data["workflow"]
    print(f"\n{'='*60}")
    print(f"  {wf['name']} ({wf['id']})")
    print(f"  {wf.get('description','')}")
    print(f"{'='*60}")
    print(f"\nTasks ({len(wf['tasks'])}):")
    for t in wf["tasks"]:
        a = t.get("action", {}) or {}
        pos = (t.get("metadata", {}) or {}).get("position", {})
        nexts = t.get("next", []) or []
        mode = t.get("transitionMode", "")
        print(f"  [{t['name']}] action={a.get('ref', '?')} pub={t.get('publishResultAs','')} mode={mode}")
        print(f"    pos=({pos.get('x','?')},{pos.get('y','?')}) | {len(nexts)} transitions")
        for n in nexts:
            do = n.get("do", [])
            print(f"    → {n.get('label','')} do={len(do)} targets when={n.get('when','')[:50]}")
    print(f"\nTriggers ({len(wf.get('triggers', []))}):")
    for tr in wf.get("triggers", []):
        print(f"  {tr['name']} [{tr['triggerType']['name']}] enabled={tr['enabled']}")


def cmd_actions(args):
    jar, headers = get_session()
    data = gql(jar, headers, '{ actions(search:{ref:{_ilike:"%%%s%%"}}, limit:30) { id name ref category } }' % args.search)
    if not data:
        return
    print(f"\nActions matching '{args.search}':")
    for a in data["actions"]:
        print(f"  {a['id']}: {a['name']} [{a['ref']}] ({a.get('category','')})")


def cmd_triggers(args):
    jar, headers = get_session()
    data = gql(jar, headers, "{ triggerTypes { id name } }")
    if not data:
        return
    for tt in data["triggerTypes"]:
        print(f"  {tt['id']}: {tt['name']}")


def cmd_build(args):
    """Build tasks from a JSON payload file. Step 1 of 2."""
    jar, headers = get_session()
    payload = json.loads(Path(args.payload).read_text())
    tasks = payload.get("tasks", [])
    # Ensure all tasks have empty next for step 1
    for t in tasks:
        t["next"] = []
    wf = {"id": args.workflow_id, "tasks": tasks}
    if payload.get("name"):
        wf["name"] = payload["name"]
    if payload.get("description"):
        wf["description"] = payload["description"]
    data = gql(jar, headers,
        "mutation($wf: WorkflowInput!) { updateWorkflow(workflow: $wf, overwrite: true) { id name tasks { id name action { ref } } } }",
        {"wf": wf})
    if not data:
        return
    wf_r = data["updateWorkflow"]
    print(f"Tasks created in {wf_r['name']}:")
    for t in wf_r["tasks"]:
        a = t.get("action", {}) or {}
        print(f"  {t['id']}: {t['name']} [{a.get('ref','?')}]")
    print(f"\nNext: run 'connect {args.workflow_id}' to wire transitions")


def cmd_connect(args):
    """Wire transitions from a JSON payload. Step 2 of 2."""
    jar, headers = get_session()
    # Get current tasks with all fields
    data = gql(jar, headers, '{ workflow(where:{id:"%s"}) { tasks { id name actionId publishResultAs transitionMode timeout input next { id label when do publish } } } }' % args.workflow_id)
    if not data:
        return
    current_tasks = data["workflow"]["tasks"]
    task_map = {t["name"]: t["id"] for t in current_tasks}

    # Load transition spec
    payload = json.loads(Path(args.payload).read_text())
    transitions = payload.get("transitions", {})  # {task_name: [{target_name, label, when}]}

    for task in current_tasks:
        if task["name"] in transitions:
            task["next"] = []
            for tr in transitions[task["name"]]:
                target_id = task_map.get(tr["target"])
                if not target_id:
                    print(f"WARNING: target '{tr['target']}' not found", file=sys.stderr)
                    continue
                task["next"].append(make_transition(target_id, tr.get("label", ""), tr.get("when", "")))

    wf = {"id": args.workflow_id, "tasks": current_tasks}
    data = gql(jar, headers,
        "mutation($wf: WorkflowInput!) { updateWorkflow(workflow: $wf) { id tasks { name next { label do when } } } }",
        {"wf": wf})
    if not data:
        return
    print("Transitions wired:")
    for t in data["updateWorkflow"]["tasks"]:
        for n in (t.get("next") or []):
            print(f"  {t['name']} → {n['label']} (do={len(n.get('do',[]))} targets)")


def cmd_add_trigger(args):
    jar, headers = get_session()
    trigger_type_id = TRIGGER_TYPES.get(args.type)
    if not trigger_type_id:
        print(f"Unknown trigger type: {args.type}. Options: {list(TRIGGER_TYPES.keys())}")
        return
    data = gql(jar, headers,
        "mutation($t: TriggerCreateInput!) { createTrigger(trigger: $t) { id name enabled triggerType { name } } }",
        {"t": {"name": args.name, "triggerTypeId": trigger_type_id, "enabled": True, "isActivatedForOwner": True, "workflowId": args.workflow_id}})
    if data:
        tr = data["createTrigger"]
        print(f"Trigger created: {tr['name']} [{tr['triggerType']['name']}] id={tr['id']}")


def main():
    parser = argparse.ArgumentParser(description="Rewst Workflow Builder")
    sub = parser.add_subparsers(dest="command")

    p = sub.add_parser("inspect", help="Inspect a workflow")
    p.add_argument("workflow_id")

    p = sub.add_parser("actions", help="Search for integration actions")
    p.add_argument("search", help="Search term (e.g. 'halo_psa', 'microsoft_graph')")

    sub.add_parser("triggers", help="List trigger types")

    p = sub.add_parser("build", help="Create/update tasks (step 1)")
    p.add_argument("workflow_id")
    p.add_argument("--payload", required=True, help="JSON file with tasks array")

    p = sub.add_parser("connect", help="Wire transitions (step 2)")
    p.add_argument("workflow_id")
    p.add_argument("--payload", required=True, help="JSON file with transitions map")

    p = sub.add_parser("add-trigger", help="Add a trigger")
    p.add_argument("workflow_id")
    p.add_argument("--type", required=True, choices=list(TRIGGER_TYPES.keys()))
    p.add_argument("--name", required=True)

    args = parser.parse_args()
    if not args.command:
        parser.print_help()
        return

    {"inspect": cmd_inspect, "actions": cmd_actions, "triggers": cmd_triggers,
     "build": cmd_build, "connect": cmd_connect, "add-trigger": cmd_add_trigger}[args.command](args)


if __name__ == "__main__":
    main()
