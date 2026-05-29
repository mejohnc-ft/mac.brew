---
name: "database-queries"
description: "Write and update typed repository queries in packages/db/src/repositories using tenant-safe context helpers, parameterized SQL, app schema references, and audit-aware mutation patterns. Use when implementing data access logic or reviewing query safety."
---


# Skill: Database Queries

> **Writing safe, typed database queries and repository functions**
>
> Applies to: `packages/db/src/repositories/`

---

## Overview

All database access goes through repository functions that use context helpers to ensure tenant isolation and type safety. This skill covers the patterns for writing correct queries.

---

## ALWAYS

### Context Helpers

- Use `withTenantContext()` for all tenant-scoped read queries
- Use `withTenantTransaction()` for tenant-scoped multi-statement writes
- Use `withFullContext()` when both tenant and user identity are needed
- Use `withFullTransaction()` for authenticated write operations

### Query Safety

- Use parameterized queries (`$1`, `$2`, ...) — NEVER string interpolation
- Use `app.` schema prefix in all SQL (`FROM app.signals`)
- Return typed results: `Promise<Entity | null>` or `Promise<Entity[]>`
- In `packages/db/src/repositories/**`, bare `query()` calls must include an RLS-safety rationale comment

### Naming

- Follow snake_case for column names in SQL
- Use camelCase for TypeScript interfaces
- Map database rows to domain entities in repository functions

---

## NEVER

- Execute raw SQL without tenant context (except platform admin)
- Use string interpolation for query values: `` `WHERE id = '${id}'` ``
- Create queries that return cross-tenant data without platform admin check
- Put permission/RBAC logic in SQL (belongs in API layer)
- Modify data without emitting audit events
- Use `any` types for query results
- Add bare `query()` to tenant-scoped code without one of:
  - `withTenantContext()` / `withTenantTransaction()`
  - SECURITY DEFINER function call
  - Explicit rationale comment (for example: "Platform-wide data - no tenant context required")

---

## Context Helper Reference

```typescript
import {
  withTenantContext,
  withTenantTransaction,
  withFullContext,
  withFullTransaction,
} from '@core/db';
import type { TenantContext, IdentityContext } from '@core/context';
```

### Read Operations

```typescript
// Simple read - no transaction needed
const entity = await withTenantContext(tenant, async (client) => {
  return repository.findById(client, id);
});
```

### Write Operations

```typescript
// Write with transaction for atomicity
const created = await withTenantTransaction(tenant, async (client) => {
  const entity = await repository.create(client, data);
  await auditRepository.log(client, event);
  return entity;
});
```

### Operations with User Identity

```typescript
// When you need the user's identity (for created_by, etc.)
const result = await withFullContext(tenant, identity, async (client) => {
  return repository.createWithOwner(client, data, identity.externalId);
});
```

---

## Repository Function Patterns

### Find by ID

```typescript
export async function findById(id: string, tenant: TenantContext): Promise<Entity | null> {
  return withTenantContext(tenant, async (client) => {
    const result = await client.query<EntityRow>(
      `SELECT id, tenant_id, name, status, created_at, updated_at
       FROM app.my_entities
       WHERE id = $1 AND deleted_at IS NULL`,
      [id]
    );
    return result.rows[0] ? mapRowToEntity(result.rows[0]) : null;
  });
}
```

### List with Filters

```typescript
export async function list(tenant: TenantContext, options?: ListOptions): Promise<Entity[]> {
  return withTenantContext(tenant, async (client) => {
    const conditions: string[] = ['deleted_at IS NULL'];
    const params: unknown[] = [];
    let paramIndex = 1;

    if (options?.status) {
      conditions.push(`status = $${paramIndex++}`);
      params.push(options.status);
    }

    if (options?.createdBy) {
      conditions.push(`created_by = $${paramIndex++}`);
      params.push(options.createdBy);
    }

    const whereClause = `WHERE ${conditions.join(' AND ')}`;
    const limit = options?.limit ?? 100;
    params.push(limit);

    const result = await client.query<EntityRow>(
      `SELECT id, tenant_id, name, status, created_at, updated_at
       FROM app.my_entities
       ${whereClause}
       ORDER BY created_at DESC
       LIMIT $${paramIndex}`,
      params
    );

    return result.rows.map(mapRowToEntity);
  });
}
```

### Create

```typescript
export async function create(
  data: CreateEntityInput,
  tenant: TenantContext,
  createdBy?: string
): Promise<Entity> {
  return withTenantContext(tenant, async (client) => {
    const result = await client.query<EntityRow>(
      `INSERT INTO app.my_entities (tenant_id, name, status, created_by)
       VALUES ($1, $2, $3, $4)
       RETURNING id, tenant_id, name, status, created_at, updated_at`,
      [tenant.id, data.name, data.status ?? 'active', createdBy ?? null]
    );

    const row = result.rows[0];
    if (!row) {
      throw new Error('Failed to create entity');
    }

    return mapRowToEntity(row);
  });
}
```

### Update

```typescript
export async function update(
  id: string,
  data: UpdateEntityInput,
  tenant: TenantContext,
  updatedBy?: string
): Promise<Entity | null> {
  return withTenantContext(tenant, async (client) => {
    const result = await client.query<EntityRow>(
      `UPDATE app.my_entities
       SET name = COALESCE($2, name),
           status = COALESCE($3, status),
           updated_at = NOW(),
           updated_by = $4
       WHERE id = $1 AND deleted_at IS NULL
       RETURNING id, tenant_id, name, status, created_at, updated_at`,
      [id, data.name ?? null, data.status ?? null, updatedBy ?? null]
    );

    return result.rows[0] ? mapRowToEntity(result.rows[0]) : null;
  });
}
```

### Soft Delete

```typescript
export async function softDelete(
  id: string,
  tenant: TenantContext,
  deletedBy?: string
): Promise<boolean> {
  return withTenantContext(tenant, async (client) => {
    const result = await client.query(
      `UPDATE app.my_entities
       SET deleted_at = NOW(), deleted_by = $2, updated_at = NOW()
       WHERE id = $1 AND deleted_at IS NULL`,
      [id, deletedBy ?? null]
    );
    return (result.rowCount ?? 0) > 0;
  });
}
```

---

## Row to Entity Mapping

```typescript
// Type for database row (snake_case)
interface EntityRow {
  id: string;
  tenant_id: string;
  name: string;
  status: string;
  created_at: Date;
  updated_at: Date;
}

// Type for domain entity (camelCase)
interface Entity {
  id: string;
  tenantId: string;
  name: string;
  status: string;
  createdAt: Date;
  updatedAt: Date;
}

// Mapping function
function mapRowToEntity(row: EntityRow): Entity {
  return {
    id: row.id,
    tenantId: row.tenant_id,
    name: row.name,
    status: row.status,
    createdAt: row.created_at,
    updatedAt: row.updated_at,
  };
}
```

---

## Platform Admin Queries (Cross-Tenant)

For platform admin operations that intentionally bypass RLS:

```typescript
// ONLY for platform admin operations
// Document clearly why cross-tenant access is needed
export async function listAllForAdmin(): Promise<Entity[]> {
  const { query } = await import('../client.js');

  // No withTenantContext - intentionally cross-tenant
  // MUST be called only from platform admin endpoints
  const result = await query<EntityRow>(`SELECT * FROM app.my_entities WHERE deleted_at IS NULL`);

  return result.rows.map(mapRowToEntity);
}
```

Accepted bare `query()` cases:

- SECURITY DEFINER function calls (pre-auth/platform bootstrap paths)
- Platform admin operations that are intentionally cross-tenant
- Schema/catalog introspection

For all other bare `query()` usage, add a nearby rationale comment explaining why tenant context is not required.

---

## Hard Stops

If ANY of these occur, HALT and report immediately:

- Query could return cross-tenant data without platform admin justification
- Repository encodes permission logic (roles, capabilities) in SQL
- Query uses string interpolation for values
- Missing tenant context wrapper on tenant-scoped query

---

## Related

- `docs/ai/skills/tenant-isolation/SKILL.md` - RLS patterns
- `docs/ai/skills/database-migrations/SKILL.md` - Schema changes
- `packages/db/src/repositories/` - Existing patterns
- `.claude/rules/database.md` - Claude Code auto-loaded version
