# MSP AUTOMATION PATTERNS (curated)

## Pattern: Safe defaults in Jinja
- Always |default(...) at field boundaries
- Guard null lists: |default([])
- Never assume Graph fields exist; map and validate

## Pattern: Rewst workflow structure
- Intake -> Validate -> Enrich -> Execute -> Verify -> Ticket note -> Metrics

## Pattern: Tenant-safe identifiers
- Require explicit tenant_id/client_code input
- Prefix logs and resource names with client_code

## Pattern: Approval gates
- Define "approval_required" boolean + approver group
- Emit "pending approval" status and stop safely
