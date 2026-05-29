---
name: "api-routes"
description: "Build and update Hono API routes in apps/api/src/routes with correct middleware order, auth and tenant context, Zod validation, authorization checks, error handling, and response semantics. Use when adding or modifying API endpoints or route-level request handling."
---


# Skill: API Routes

> **Building Hono API routes with proper middleware, validation, and error handling**
>
> Applies to: `apps/api/src/routes/`

---

## Overview

API routes handle HTTP requests, enforce authorization, validate input, call business logic, and return responses. This skill covers the patterns for building correct, secure routes.

---

## ALWAYS

### Middleware Chain

```typescript
// Correct middleware order
app.use('/v1/*', jwtValidator); // Authentication
app.use('/v1/*', tenantResolver); // Tenant context

// Route handlers receive validated context
app.get('/v1/resources', async (c) => {
  const ctx = c.get('requestContext')!;
  // ctx.identity - authenticated user
  // ctx.tenant - resolved tenant
  // ctx.permissions - user's permissions
});
```

### Input Validation

- Validate ALL request bodies with Zod schemas from `@core/contracts`
- Validate query parameters with Zod schemas
- Validate path parameters when necessary
- Return 400 with validation errors on failure

### Authorization Checks

- Check permissions at route level, not in repositories
- Use `ctx.permissions.includes('capability')` for checks
- Use `requireTenantAdmin` middleware for admin-only routes
- Return 403 Forbidden when unauthorized

### Error Responses

- Use `HTTPException` from Hono for all errors
- Follow RFC 7807 Problem Detail format
- Never expose stack traces or internal details
- Log errors server-side only

### Response Patterns

- Return 200 for successful GET/PATCH
- Return 201 for successful POST (create)
- Return 204 for successful DELETE
- Include `Location` header for created resources

---

## NEVER

- Skip authentication middleware on protected routes
- Check permissions in repository functions
- Expose raw database errors to clients
- Return inconsistent error formats
- Use raw `throw new Error()` (use HTTPException)
- Import from `apps/` in routes (use `@core/*`)

---

## Route File Structure

```typescript
/**
 * Resource routes for [feature name].
 *
 * [Brief description of what this router handles]
 */

import { Hono } from 'hono';
import { HTTPException } from 'hono/http-exception';
import { createResourceSchema, ResourceResponse } from '@core/contracts';
import { createResource, findResourceById, listResources } from '@core/db';
import type { AppVariables } from '../types.js';
import { requireAuth, requireTenantAdmin, logCustomAuditEvent } from '../middleware/index.js';

const resources = new Hono<{ Variables: AppVariables }>();

// Require auth for all routes
resources.use('*', requireAuth);

// Route implementations...

export { resources };
```

---

## Patterns

### Create Resource (POST)

```typescript
/**
 * POST /v1/resources
 * Create a new resource.
 */
resources.post('/', async (c) => {
  const ctx = c.get('requestContext')!;
  const body = await c.req.json();

  // Validate input
  const parsed = createResourceSchema.safeParse(body);
  if (!parsed.success) {
    throw new HTTPException(400, {
      message: `Validation error: ${parsed.error.issues.map((e) => e.message).join(', ')}`,
    });
  }

  try {
    // Create resource
    const resource = await createResource(
      {
        tenantId: ctx.tenant.id,
        name: parsed.data.name,
        createdBy: ctx.identity.sub,
      },
      ctx.tenant
    );

    // Emit audit event
    await logCustomAuditEvent(c, {
      action: 'resource.created',
      resourceType: 'resource',
      resourceId: resource.id,
      status: 'success',
    });

    // Return response with Location header
    c.header('Location', `/v1/resources/${resource.id}`);
    return c.json(toResourceResponse(resource), 201);
  } catch (error) {
    console.error('[resources] Create error:', error);
    throw new HTTPException(500, { message: 'Failed to create resource' });
  }
});
```

### Get Resource (GET)

```typescript
/**
 * GET /v1/resources/:id
 * Get a single resource by ID.
 */
resources.get('/:id', async (c) => {
  const ctx = c.get('requestContext')!;
  const resourceId = c.req.param('id');

  const resource = await findResourceById(resourceId, ctx.tenant);
  if (!resource) {
    throw new HTTPException(404, { message: 'Resource not found' });
  }

  return c.json(toResourceResponse(resource));
});
```

### List Resources (GET)

```typescript
/**
 * GET /v1/resources
 * List resources with pagination and filters.
 */
resources.get('/', async (c) => {
  const ctx = c.get('requestContext')!;
  const query = c.req.query();

  const parsed = listResourcesQuerySchema.safeParse(query);
  if (!parsed.success) {
    throw new HTTPException(400, {
      message: `Validation error: ${parsed.error.issues.map((e) => e.message).join(', ')}`,
    });
  }

  const resources = await listResources(ctx.tenant, {
    status: parsed.data.status,
    limit: parsed.data.limit,
    cursor: parsed.data.cursor,
  });

  const items = resources.map(toResourceResponse);

  return c.json({
    items,
    pagination: {
      cursor: resources.length >= parsed.data.limit ? lastCursor : null,
      hasMore: resources.length >= parsed.data.limit,
    },
  });
});
```

### Update Resource (PATCH)

```typescript
/**
 * PATCH /v1/resources/:id
 * Update a resource.
 */
resources.patch('/:id', async (c) => {
  const ctx = c.get('requestContext')!;
  const resourceId = c.req.param('id');
  const body = await c.req.json();

  const parsed = updateResourceSchema.safeParse(body);
  if (!parsed.success) {
    throw new HTTPException(400, {
      message: `Validation error: ${parsed.error.issues.map((e) => e.message).join(', ')}`,
    });
  }

  const updated = await updateResource(resourceId, parsed.data, ctx.tenant, ctx.identity.sub);

  if (!updated) {
    throw new HTTPException(404, { message: 'Resource not found' });
  }

  return c.json(toResourceResponse(updated));
});
```

### Delete Resource (DELETE)

```typescript
/**
 * DELETE /v1/resources/:id
 * Soft-delete a resource.
 */
resources.delete('/:id', async (c) => {
  const ctx = c.get('requestContext')!;
  const resourceId = c.req.param('id');

  // Authorization check
  if (!ctx.permissions.includes('resource:delete')) {
    throw new HTTPException(403, {
      message: 'Forbidden: Missing permission to delete resources',
    });
  }

  const deleted = await softDeleteResource(resourceId, ctx.tenant, ctx.identity.sub);
  if (!deleted) {
    throw new HTTPException(404, { message: 'Resource not found' });
  }

  return c.body(null, 204);
});
```

### Admin-Only Route

```typescript
/**
 * PATCH /v1/resources/:id/status
 * Update resource status (admin only).
 */
resources.patch('/:id/status', requireTenantAdmin, async (c) => {
  const ctx = c.get('requestContext')!;
  // requireTenantAdmin already checked admin permission

  // ... implementation
});
```

---

## Entity to Response Conversion

Always convert database entities to response types:

```typescript
function toResourceResponse(entity: ResourceEntity): ResourceResponse {
  return {
    id: entity.id,
    tenantId: entity.tenant_id,
    name: entity.name,
    status: entity.status,
    createdAt: entity.created_at.toISOString(),
    updatedAt: entity.updated_at.toISOString(),
  };
}
```

---

## Validation Patterns

### Request Body

```typescript
const parsed = createResourceSchema.safeParse(body);
if (!parsed.success) {
  throw new HTTPException(400, {
    message: `Validation error: ${parsed.error.issues.map((e) => e.message).join(', ')}`,
  });
}
// Use parsed.data
```

### Query Parameters

```typescript
const query = c.req.query();
const parsed = listQuerySchema.safeParse(query);
if (!parsed.success) {
  throw new HTTPException(400, {
    message: `Validation error: ${parsed.error.issues.map((e) => e.message).join(', ')}`,
  });
}
```

### Path Parameters

```typescript
const resourceId = c.req.param('id');
// Validate UUID format if needed
if (!isValidUUID(resourceId)) {
  throw new HTTPException(400, { message: 'Invalid resource ID format' });
}
```

---

## Error Handling

```typescript
try {
  // Operation that might fail
} catch (error) {
  // Log full error server-side
  console.error('[resources] Operation failed:', {
    error: error instanceof Error ? error.message : String(error),
    tenantId: ctx.tenant.id,
    userId: ctx.identity.sub,
  });

  // Re-throw HTTPException as-is
  if (error instanceof HTTPException) {
    throw error;
  }

  // Generic error for unexpected failures
  throw new HTTPException(500, {
    message: 'An unexpected error occurred',
  });
}
```

---

## Hard Stops

If ANY of these occur, HALT and report immediately:

- Protected route skips `jwtValidator` middleware
- Authorization check happens in repository instead of route
- Raw database errors exposed to clients
- Stack traces included in API responses
- Inconsistent error format across routes

---

## Related

- `docs/ai/skills/security/SKILL.md` - Error handling, validation
- `docs/ai/skills/contract-evolution/SKILL.md` - Response schemas
- `apps/api/src/routes/` - Existing route examples
- `packages/contracts/` - Request/response schemas
