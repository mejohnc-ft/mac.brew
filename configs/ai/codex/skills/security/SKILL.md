---
name: "security"
description: "Apply centrexAI security requirements across API, database, and frontend including input validation, RLS isolation, RBAC enforcement, error sanitization, audit events, and package boundary rules. Use when implementing or reviewing security-sensitive code paths."
---


# Skill: Security

> **Security requirements for all centrexAI code**
>
> Applies to: All packages, API routes, frontend

---

## Overview

Security is non-negotiable. Every feature must follow these requirements to protect tenant data and maintain system integrity.

---

## Every Feature MUST

1. **Validate all inputs** with Zod schemas
2. **Enforce RLS** (tenant isolation) at database layer
3. **Enforce RBAC** (permissions) at API layer
4. **Sanitize output** — no raw error details to clients
5. **Emit audit events** for all mutations
6. **Use typed errors** — `HTTPException` + `ErrorCode`

---

## NEVER

### API Security

- Expose stack traces in API responses
- Log secrets, tokens, or PII
- Trust user input without validation
- Return raw database errors to clients
- Skip authentication for protected routes

### Code Quality

- Use `any` types (always use proper TypeScript types)
- Use `// @ts-ignore` or `// @ts-expect-error` without justification
- Throw raw `Error()` in API routes (use HTTPException)
- Import AI SDKs directly (use `@core/ai` abstraction)

### Package Boundaries

- `packages/` importing from `apps/`
- Circular dependencies between packages
- Direct database access from apps (use `@core/db`)

---

## Patterns

### Input Validation with Zod

```typescript
import { z } from 'zod';

const CreateResourceSchema = z.object({
  name: z.string().min(1).max(100),
  description: z.string().max(1000).optional(),
  type: z.enum(['active', 'inactive']),
});

app.post('/v1/resources', async (c) => {
  const body = await c.req.json();
  const validated = CreateResourceSchema.parse(body); // Throws on invalid

  // Use validated data
  const resource = await createResource(validated, tenant);
  return c.json(resource, 201);
});
```

### RFC 7807 Error Responses

```typescript
import { ErrorCode, createProblemDetail } from '@core/contracts';
import { HTTPException } from 'hono/http-exception';

// NOT_FOUND
throw new HTTPException(404, {
  message: JSON.stringify(createProblemDetail(ErrorCode.NOT_FOUND, 'Resource not found')),
});

// VALIDATION_ERROR
throw new HTTPException(400, {
  message: JSON.stringify(
    createProblemDetail(ErrorCode.VALIDATION_ERROR, 'Invalid input', {
      errors: validationErrors,
    })
  ),
});

// FORBIDDEN
throw new HTTPException(403, {
  message: JSON.stringify(createProblemDetail(ErrorCode.FORBIDDEN, 'Insufficient permissions')),
});
```

### Audit Event Emission

```typescript
import { emitAuditEvent } from '@core/db';

// After successful mutation
const resource = await createResource(data, tenant);

await emitAuditEvent(client, {
  tenantId: tenant.id,
  actorId: identity.externalId,
  action: 'resource.created',
  resourceType: 'resource',
  resourceId: resource.id,
  details: { name: data.name },
});
```

### Safe Error Handling

```typescript
app.onError((err, c) => {
  // Log full error for debugging (server-side only)
  console.error('[API Error]', err);

  // Return sanitized response
  if (err instanceof HTTPException) {
    return c.json(JSON.parse(err.message), err.status);
  }

  // Generic error for unexpected failures
  return c.json(createProblemDetail(ErrorCode.INTERNAL_ERROR, 'An unexpected error occurred'), 500);
});
```

---

## Package Boundaries

### Correct Imports

```typescript
// From apps/api - import from packages
import { withTenantContext } from '@core/db';
import { createProblemDetail, ErrorCode } from '@core/contracts';
import type { TenantContext } from '@core/context';
import { AIProvider } from '@core/ai';

// Internal package dependencies use workspace protocol
// In package.json:
"dependencies": {
  "@core/context": "workspace:*",
  "@core/contracts": "workspace:*"
}
```

### Forbidden Imports

```typescript
// NEVER: packages importing from apps
import { something } from '@centrexai/api'; // WRONG

// NEVER: direct AI SDK imports
import { AzureOpenAI } from '@azure/openai'; // WRONG
import Anthropic from '@anthropic-ai/sdk'; // WRONG

// CORRECT: use @core/ai abstraction
import { createProvider } from '@core/ai';
```

---

## Zod Validation for Different Types

### String Validation

```typescript
z.string().min(1).max(255); // Required string with length
z.string().email(); // Email format
z.string().uuid(); // UUID format
z.string().url(); // URL format
z.string().regex(/^[a-z-]+$/); // Pattern match
```

### Number Validation

```typescript
z.number().int().positive(); // Positive integer
z.number().min(0).max(100); // Range
z.coerce.number(); // Parse string to number
```

### Arrays and Objects

```typescript
z.array(z.string()).min(1).max(10); // Array with length
z.object({ key: z.string() }).strict(); // Reject unknown keys
z.record(z.string(), z.number()); // Record type
```

---

## Hard Stops

If ANY of these occur, HALT and report immediately:

- Stack traces exposed in production API responses
- Secrets or PII being logged
- User input processed without validation
- API routes skipping authentication
- Direct AI SDK imports bypassing `@core/ai`

---

## Related

- `docs/ai/skills/auth-boundary/SKILL.md` - Authentication/authorization
- `docs/ai/skills/tenant-isolation/SKILL.md` - Tenant data protection
- `packages/contracts/src/error.ts` - Error codes and helpers
- `.claude/rules/security.md` - Claude Code auto-loaded version
