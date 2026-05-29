---
name: rewst-session-auth
description: Use when Rewst workflow, template, or page tooling fails because the terminal lacks a valid authenticated browser session. Captures the current Chrome `appSession` cookie for `rewst.io`, exports it for terminal helpers, verifies GraphQL auth, and can write the cookie to a file or `/private/tmp/workflow_query_result.json` for the existing Rewst skills.
---

# Rewst Session Auth

Use this skill when Rewst API helpers or publish scripts fail due to missing auth, stale cookies, or a shell that cannot see the active browser session.

This skill does not replace `rewst-workflows` or `rewst-execution-debugging`. It feeds them a valid session.

## Quick Start

Verify the current browser session:

```bash
python3 "$HOME/.codex/skills/rewst-session-auth/scripts/export_rewst_session.py" check
```

Export the cookie into shell form:

```bash
eval "$(python3 "$HOME/.codex/skills/rewst-session-auth/scripts/export_rewst_session.py" export-env)"
```

Write a reusable cookie file for the existing Rewst skills:

```bash
python3 "$HOME/.codex/skills/rewst-session-auth/scripts/export_rewst_session.py" write-cookie-file \
  --path /private/tmp/rewst-cookie.txt
export REWST_COOKIE_FILE=/private/tmp/rewst-cookie.txt
```

Write the compatibility file used by older Rewst tooling:

```bash
python3 "$HOME/.codex/skills/rewst-session-auth/scripts/export_rewst_session.py" write-workflow-json
```

## When To Use It

- `rewst_workflow.py` says it cannot resolve a session cookie
- a page publish script works in one shell but not another
- `browser_cookie3` is available but the Rewst helper does not see the session
- you want a stable terminal auth path without pasting cookies manually

## Workflow

1. Run `check` to confirm Chrome has a readable `rewst.io` `appSession`.
2. If the session is valid, either:
   - `export-env` for the current shell, or
   - `write-cookie-file` for reusable automation, or
   - `write-workflow-json` for compatibility with existing Rewst helpers.
3. Run the normal Rewst tooling after the session is exported.
4. If `check` fails, log into Rewst in Chrome and retry.

## Notes

- This skill uses the current Chrome browser session via `browser_cookie3`.
- It is the same auth primitive most local Rewst tooling already depends on.
- If a separate tool such as a VS Code extension stores the same cookie more ergonomically, that is still the same underlying session model.

## Existing Skills

After exporting auth, use the existing skills:

- `rewst-workflows`
- `rewst-execution-debugging`
- `rewst-trigger-testing`
- `rewst-templates`
