---
name: "tenant-isolation"
description: "Enforce strict tenant isolation in tables, queries, and responses with tenant_id design, RLS policies, and tenant-context repository patterns. Use when creating tenant-scoped data models, writing queries, or validating cross-tenant safety."
---


# Skill: Tenant Isolation

> **Ensuring complete data separation between tenants**
>
> Applies to: Database tables, queries, API responses

---

## Overview

centrexAI is a multi-tenant system. Every piece of user data belongs to exactly one tenant, and tenants must never see each other's data. This skill covers the enforcement mechanisms.

---

## Rules (ALWAYS ENFORCED)

### Table Structure

- ALL user-data tables MUST have `tenant_id UUID NOT NULL REFERENCES app.tenants(id) ON DELETE CASCADE`
- ALL user-data tables MUST have RLS enabled: `ALTER TABLE app.tablename ENABLE ROW LEVEL SECURITY`
- RLS policies MUST use `app.can_access_tenant(tenant_id)` for access checks

### Query Patterns

- ALL tenant-scoped read queries MUST use `withTenantContext()`
- ALL tenant-scoped write operations MUST use `withTenantTransaction()`
- NEVER execute raw SQL without tenant context (except explicit platform admin queries)

### Response Handling

- NEVER expose cross-tenant data in API responses
- NEVER log tenant IDs alongside sensitive data
- ALWAYS verify tenant context before returning data

---

## NEVER

- Execute queries without `withTenantContext()` wrapper
- Create tenant-scoped tables without RLS policies
- Return data from one tenant's request that belongs to another
- Assume RLS handles permissions (RLS is for isolation only)
- Put permission/RBAC logic in SQL (belongs in API layer)

---

## Patterns

### Creating Tenant-Scoped Table

```sql
CREATE TABLE IF NOT EXISTS app.my_table (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES app.tenants(id) ON DELETE CASCADE,
    -- other columns
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Enable RLS
ALTER TABLE app.my_table ENABLE ROW LEVEL SECURITY;

-- Create policies
CREATE POLICY my_table_select_policy ON app.my_table
    FOR SELECT USING (app.can_access_tenant(tenant_id));
CREATE POLICY my_table_insert_policy ON app.my_table
    FOR INSERT WITH CHECK (app.can_access_tenant(tenant_id));
CREATE POLICY my_table_update_policy ON app.my_table
    FOR UPDATE USING (app.can_access_tenant(tenant_id))
    WITH CHECK (app.can_access_tenant(tenant_id));
CREATE POLICY my_table_delete_policy ON app.my_table
    FOR DELETE USING (app.can_access_tenant(tenant_id));

-- Index for performance
CREATE INDEX IF NOT EXISTS idx_my_table_tenant_id ON app.my_table(tenant_id);
```

### Querying with Tenant Context

```typescript
import { withTenantContext } from '@core/db';
import type { TenantContext } from '@core/context';

export async function findById(id: string, tenant: TenantContext): Promise<Entity | null> {
  return withTenantContext(tenant, async (client) => {
    const result = await client.query<Entity>(
      `SELECT id, tenant_id, name, created_at, updated_at
       FROM app.my_table
       WHERE id = $1 AND deleted_at IS NULL`,
      [id]
    );
    return result.rows[0] ?? null;
  });
}
```

### Platform Admin (Cross-Tenant) Query

```typescript
// ONLY for platform admin operations - document clearly
// This bypasses RLS intentionally
export async function listAllForAdmin(): Promise<Entity[]> {
  const { query } = await import('../client.js');

  // No withTenantContext - intentionally cross-tenant
  // MUST be called only from platform admin endpoints
  const result = await query<Entity>(`SELECT * FROM app.my_table WHERE deleted_at IS NULL`);
  return result.rows;
}
```

---

## Hard Stops

If ANY of these occur, HALT and report immediately:

- RLS behavior is ambiguous, inconsistent, or cannot be verified
- A query returns data without an explicit tenant boundary
- A migration modifies existing tenant data without a forward-only plan
- A repository encodes permission logic in SQL instead of using RBAC
- Cross-tenant data access occurs without explicit platform admin justification

---

## Testing

### RLS Test Pattern

```typescript
describe('RLS policies', () => {
  it('should not return data for wrong tenant', async () => {
    // Create data as tenant A
    const entityA = await createEntity(tenantA);

    // Query as tenant B
    const result = await withTenantContext(tenantB, async (client) => {
      return client.query('SELECT * FROM app.my_table WHERE id = $1', [entityA.id]);
    });

    expect(result.rows).toHaveLength(0);
  });
});
```

---

## Related

- `docs/ai/skills/database-queries/SKILL.md` - Query patterns
- `docs/ai/skills/auth-boundary/SKILL.md` - Authorization vs isolation
- `.claude/rules/tenant-isolation.md` - Claude Code auto-loaded version
