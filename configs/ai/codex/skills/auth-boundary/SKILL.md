---
name: "auth-boundary"
description: "Apply centrexAI authentication and authorization boundaries across middleware, routes, and data access. Use when implementing or reviewing MSAL/Entra JWT flow, tenant resolution, RBAC checks, and separation of concerns between RLS, API authorization, and repositories."
---


# Skill: Authorization Boundary

> **Separation of authentication and authorization concerns**
>
> Applies to: Middleware, API routes, database access

---

## Overview

centrexAI has a strict separation between authentication (proving identity), tenant isolation (data separation), and authorization (permission checking). Each layer has specific responsibilities.

---

## Authentication Flow (NEVER Deviate)

```
Web Application:
  User → MSAL → Entra ID → JWT Token → Browser Session

API Request:
  JWT Token → jwtValidator middleware → IdentityContext

Protected Routes:
  jwtValidator → tenantResolver → route handler
```

---

## Authorization Layers

| Layer        | Responsibility                   | NOT Responsible For              |
| ------------ | -------------------------------- | -------------------------------- |
| RLS (DB)     | Tenant isolation only            | Roles, permissions, capabilities |
| RBAC (API)   | Roles, permissions, capabilities | Data access patterns             |
| Repositories | Data access only                 | Permission decisions             |
| API Routes   | Authorization decisions          | Direct DB access                 |

---

## Rules (ALWAYS ENFORCED)

### Authentication

- Web auth MUST use MSAL with Entra ID
- API auth MUST use `jwtValidator` middleware
- JWTs MUST be validated on every request
- Never implement custom auth mechanisms

### Authorization

- Permission checks happen at API route level
- Use RBAC helpers to check capabilities
- Never encode role logic in SQL queries
- Never check permissions in repository functions

### Middleware Chain

```typescript
// Correct: middleware chain for protected routes
app.use('/v1/*', jwtValidator);
app.use('/v1/*', tenantResolver);

// Route handlers receive context
app.get('/v1/resources', async (c) => {
  const identity = c.get('identity');
  const tenant = c.get('requestContext').tenant;

  // Authorization check at route level
  if (!hasCapability(identity, 'read_resources')) {
    throw new HTTPException(403, { message: 'Forbidden' });
  }

  // Then access data
  const data = await repository.list(tenant);
  return c.json(data);
});
```

---

## NEVER

- Bypass `jwtValidator` for protected routes
- Implement custom authentication flows
- Check permissions in repository functions
- Rely on RLS for permission enforcement
- Duplicate authorization logic across layers
- Trust request headers without JWT validation

---

## Patterns

### JWT Validation Middleware

```typescript
// apps/api/src/middleware/jwtValidator.ts
export const jwtValidator = async (c: Context, next: Next) => {
  const authHeader = c.req.header('Authorization');
  if (!authHeader?.startsWith('Bearer ')) {
    throw new HTTPException(401, { message: 'Missing token' });
  }

  const token = authHeader.slice(7);
  const claims = await validateToken(token);

  c.set('identity', {
    externalId: claims.oid,
    email: claims.email,
    name: claims.name,
    entraTenantId: claims.tid,
  });

  await next();
};
```

### Tenant Resolution Middleware

```typescript
// apps/api/src/middleware/tenantResolver.ts
export const tenantResolver = async (c: Context, next: Next) => {
  const identity = c.get('identity');

  // Look up tenant membership
  const tenant = await findTenantForUser(identity.externalId);
  if (!tenant) {
    throw new HTTPException(403, { message: 'No tenant access' });
  }

  c.set('requestContext', { tenant, identity });
  await next();
};
```

### Route Authorization Check

```typescript
// Capability check at route level
app.post('/v1/teammates', async (c) => {
  const { identity, tenant } = c.get('requestContext');

  // Authorization happens here
  if (!hasCapability(identity, tenant, 'create_teammate')) {
    throw new HTTPException(403, {
      message: JSON.stringify(
        createProblemDetail(ErrorCode.FORBIDDEN, 'Missing capability: create_teammate')
      ),
    });
  }

  // Proceed with business logic
  const body = await c.req.json();
  const teammate = await createTeammate(body, tenant);
  return c.json(teammate, 201);
});
```

---

## Hard Stops

If ANY of these occur, HALT and report immediately:

- Auth flow deviates from: `MSAL → Entra ID → JWT → IdentityContext`
- Permission checks are unclear or duplicated across layers
- Security behavior relies on assumed enforcement
- Repository functions include role/permission logic
- Routes skip `jwtValidator` for protected endpoints

---

## Context Types

```typescript
// packages/context/src/types.ts
interface IdentityContext {
  externalId: string; // Entra Object ID
  email: string;
  name: string;
  entraTenantId: string; // Entra tenant ID
}

interface TenantContext {
  id: string; // centrexAI tenant ID
  slug: string;
  hierarchy: string[]; // For sub-tenant support
}

interface RequestContext {
  identity: IdentityContext;
  tenant: TenantContext;
}
```

---

## Related

- `docs/ai/skills/tenant-isolation/SKILL.md` - RLS patterns
- `docs/ai/skills/security/SKILL.md` - Security requirements
- `.claude/rules/auth-boundary.md` - Claude Code auto-loaded version
