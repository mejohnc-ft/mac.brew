# HANDOFF CONTRACT (JSON envelope)

All specialist skills hand off using this envelope:

```json
{
  "intent": "one sentence goal",
  "context": {
    "client_scope": "DEV|STAGE|PROD + tenant/client identifier",
    "systems": ["Rewst","Graph","HaloPSA","AzureAI"],
    "constraints": ["tenant separation", "approval required for X"]
  },
  "inputs": [
    {"name":"...", "type":"...", "source":"form|ticket|api", "required":true}
  ],
  "assumptions": ["..."],
  "artifacts": [
    {"type":"jinja|json|workflow|runbook", "path_or_block":"..."}
  ],
  "risks": [
    {"risk":"...", "mitigation":"..."}
  ],
  "next_actions": [
    "step 1", "step 2"
  ]
}
```
