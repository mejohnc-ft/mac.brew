# Workflow Procedures

## Safe defaults

- Treat the API as authoritative for workflow, trigger, template, and execution state.
- Use the browser for navigation, visual report checks, and UI-only actions.
- Before any email test, inspect the active trigger recipient vars first.

## Inspect

Use:

```bash
python3 ~/.codex/skills/rewst-workflows/scripts/rewst_workflow.py workflow --workflow-id <workflow-id>
python3 ~/.codex/skills/rewst-workflows/scripts/rewst_workflow.py trigger --workflow-id <workflow-id>
python3 ~/.codex/skills/rewst-workflows/scripts/rewst_workflow.py template --template-id <template-id>
```

Focus on:

- workflow `updatedAt`
- trigger `vars`
- trigger `parameters`
- template `updatedAt`
- template body markers

## Edit and publish an existing workflow

Preferred pattern:

1. Query the current workflow into a JSON payload.
2. Modify only the fields that need to change.
3. Send `updateWorkflow` with `createPatch: false` for a real publish.
4. Re-read the workflow and verify `updatedAt` changed.

Minimal mutation shape:

```json
{
  "query": "mutation($workflow: WorkflowInput!, $comment: String, $createPatch: Boolean){ updateWorkflow(workflow:$workflow, comment:$comment, createPatch:$createPatch){ id updatedAt name } }",
  "variables": {
    "workflow": {},
    "comment": "Describe the live change",
    "createPatch": false
  }
}
```

Run it with:

```bash
python3 ~/.codex/skills/rewst-workflows/scripts/rewst_workflow.py request --payload-file /tmp/update_workflow.json
```

## Update a template directly

Minimal mutation shape:

```json
{
  "query": "mutation($template: TemplateInput!, $templateId: ID!){ updateTemplate(template:$template, templateId:$templateId){ id updatedAt name } }",
  "variables": {
    "templateId": "<template-id>",
    "template": {
      "name": "[ROC] Time Savings Report",
      "language": "html",
      "description": "Time Saving Report HTML",
      "content_type": "message",
      "body": "<!DOCTYPE html>..."
    }
  }
}
```

## Test the live cron or form path

When trigger vars matter, run:

```bash
python3 ~/.codex/skills/rewst-workflows/scripts/rewst_workflow.py test-trigger \
  --workflow-id <workflow-id> \
  --trigger-id <trigger-id> \
  --org-id <org-id> \
  --org-name "<org-name>" \
  --wait
```

This uses `testWorkflowTrigger` with the live trigger definition, not generic `testWorkflow`.

After the run, verify:

- execution `status`
- merged `email_addresses`
- sendmail task count
- sendmail result messages

## New workflow creation

When you need a new workflow:

- Prefer `shallowCloneWorkflow` if the new workflow is based on an existing pattern.
- Use `createWorkflow` only when no good base exists.
- After creation, inspect the new workflow id, trigger state, and initial tasks before more edits.

## Publish-before-test rule

If the user says to publish before testing:

1. Publish
2. Verify live `updatedAt`
3. Tell the user it is published
4. Only then run the test

