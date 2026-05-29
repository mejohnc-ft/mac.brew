---
name: "database-migrations"
description: "Create safe, idempotent PostgreSQL migrations in packages/db/migrations with app schema qualification, tenant_id and RLS requirements, and rollback-aware change patterns. Use when introducing schema changes, indexes, policies, constraints, or triggers."
---


# Skill: Database Migrations

> **Creating safe, idempotent database migrations**
>
> Applies to: `packages/db/migrations/`

---

## Overview

Migrations modify the database schema. They must be forward-only, idempotent, and safe for parallel tenant execution. Mistakes are costly and hard to reverse.

---

## ALWAYS

### File Naming

- Run `./scripts/next-migration-number.sh` to get the next available number
- Use format: `NNN_description.sql` (e.g., `067_add_signals_priority.sql`)
- Use descriptive names that explain the change

### Schema Usage

- Use `app.` schema prefix for ALL table references
- `CREATE TABLE app.tablename` (not `CREATE TABLE tablename`)
- `REFERENCES app.tenants(id)` (not `REFERENCES tenants(id)`)
- `FROM app.signals` (not `FROM signals`)

### Idempotency

- Use `IF NOT EXISTS` for CREATE TABLE and CREATE INDEX
- Use `ADD COLUMN IF NOT EXISTS` pattern for ALTER TABLE
- Use DO blocks for constraints that don't support IF NOT EXISTS
- Migrations must be safe to run multiple times

### Tenant Tables

- Include `tenant_id UUID NOT NULL REFERENCES app.tenants(id) ON DELETE CASCADE`
- Enable RLS: `ALTER TABLE app.tablename ENABLE ROW LEVEL SECURITY`
- Create all four policies: SELECT, INSERT, UPDATE, DELETE
- Use `app.can_access_tenant(tenant_id)` in policies

### Triggers

- Create `update_updated_at` trigger for tables with `updated_at` column

### Indexes

- Create index on `tenant_id` for all tenant-scoped tables
- Use `CREATE INDEX IF NOT EXISTS`

---

## NEVER

- Modify existing migration files (create a new migration instead)
- Use DROP TABLE or DROP COLUMN without explicit human approval
- Create tenant-scoped tables without RLS policies
- Use unqualified table names
- Skip the `IF NOT EXISTS` pattern
- Use string interpolation in SQL

---

## Migration File Template

```sql
-- Migration: [Description of what this migration does]
-- Part of ISSUE-NNN: [Feature/Epic name]

-- Create table
CREATE TABLE IF NOT EXISTS app.tablename (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES app.tenants(id) ON DELETE CASCADE,
    name VARCHAR(255) NOT NULL,
    description TEXT,
    status VARCHAR(50) NOT NULL DEFAULT 'active',
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by UUID REFERENCES app.users(id),
    updated_by UUID REFERENCES app.users(id),
    deleted_at TIMESTAMPTZ,
    deleted_by UUID REFERENCES app.users(id)
);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_tablename_tenant_id ON app.tablename(tenant_id);
CREATE INDEX IF NOT EXISTS idx_tablename_status ON app.tablename(status) WHERE deleted_at IS NULL;

-- Row Level Security
ALTER TABLE app.tablename ENABLE ROW LEVEL SECURITY;

CREATE POLICY tablename_select_policy ON app.tablename
    FOR SELECT USING (app.can_access_tenant(tenant_id));
CREATE POLICY tablename_insert_policy ON app.tablename
    FOR INSERT WITH CHECK (app.can_access_tenant(tenant_id));
CREATE POLICY tablename_update_policy ON app.tablename
    FOR UPDATE USING (app.can_access_tenant(tenant_id))
    WITH CHECK (app.can_access_tenant(tenant_id));
CREATE POLICY tablename_delete_policy ON app.tablename
    FOR DELETE USING (app.can_access_tenant(tenant_id));

-- Update trigger
CREATE TRIGGER update_tablename_updated_at
    BEFORE UPDATE ON app.tablename
    FOR EACH ROW EXECUTE FUNCTION app.update_updated_at();
```

---

## Idempotent Patterns

### Adding Column

```sql
ALTER TABLE app.signals ADD COLUMN IF NOT EXISTS priority VARCHAR(20);
```

### Adding Constraint

```sql
DO $$ BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'signals_priority_check'
  ) THEN
    ALTER TABLE app.signals ADD CONSTRAINT signals_priority_check
      CHECK (priority IN ('low', 'medium', 'high'));
  END IF;
END $$;
```

### Adding Foreign Key

```sql
DO $$ BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'fk_signals_category'
  ) THEN
    ALTER TABLE app.signals ADD CONSTRAINT fk_signals_category
      FOREIGN KEY (category_id) REFERENCES app.categories(id);
  END IF;
END $$;
```

### Adding Enum Value

```sql
DO $$ BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_enum WHERE enumlabel = 'new_value'
      AND enumtypid = 'app.my_enum'::regtype
  ) THEN
    ALTER TYPE app.my_enum ADD VALUE 'new_value';
  END IF;
END $$;
```

---

## Pre-Commit Checklist

Before committing a migration:

```bash
# 1. Check all table references use app. schema
grep -n "FROM \|INTO \|TABLE \|REFERENCES " packages/db/migrations/YOUR_MIGRATION.sql

# 2. Verify IF NOT EXISTS on all CREATE statements
grep -n "CREATE " packages/db/migrations/YOUR_MIGRATION.sql

# 3. Check for duplicate table names across migrations
grep -r "CREATE TABLE.*tablename" packages/db/migrations/

# 4. Test migration locally
pnpm --filter @core/db migrate
```

---

## Common Mistakes

### Wrong: Unqualified Table Name

```sql
CREATE TABLE signals (...);  -- WRONG
CREATE TABLE app.signals (...);  -- CORRECT
```

### Wrong: Missing IF NOT EXISTS

```sql
CREATE INDEX idx_foo ON app.bar(baz);  -- WRONG
CREATE INDEX IF NOT EXISTS idx_foo ON app.bar(baz);  -- CORRECT
```

### Wrong: Missing RLS for Tenant Table

```sql
CREATE TABLE app.user_data (
  tenant_id UUID NOT NULL REFERENCES app.tenants(id),
  ...
);
-- WRONG: Missing ENABLE ROW LEVEL SECURITY
-- WRONG: Missing policies
```

---

## Hard Stops

If ANY of these occur, HALT and report immediately:

- Migration modifies existing tenant data without forward-only plan
- Migration creates tenant-scoped table without RLS
- Migration uses DROP without explicit approval
- Migration number conflicts with existing file
- Migration uses unqualified table names

---

## Related

- `packages/db/migrations/` - Migration files
- `scripts/next-migration-number.sh` - Get next number
- `.claude/learnings/qa-patterns.md` - Migration failure patterns
- `.claude/rules/migrations.md` - Claude Code auto-loaded version
