---
name: "contract-evolution"
description: "Evolve @core/contracts schemas and API contract shapes safely with backward compatibility, versioning strategy, and consumer impact control. Use when adding, changing, or deprecating contract fields, Zod schemas, or API response/request structures."
---


# Skill: Contract Evolution

> **Managing API contract changes safely**
>
> Applies to: `@core/contracts`, API responses, Zod schemas

---

## Overview

Contracts (TypeScript interfaces + Zod schemas) define the agreement between API and consumers. Breaking this agreement causes failures. This skill covers safe evolution of contracts.

---

## High-Conflict Zone

Contracts are a **HIGH-CONFLICT ZONE**. Changes affect:

- API consumers (web app, external integrations)
- Test fixtures and mocks
- Documentation and examples
- Client code across all consumers

---

## Breaking Changes REQUIRE

A breaking change is anything that would cause existing consumers to fail:

1. **A new contract version**, OR
2. **Backward-compatible optional fields**

### What Constitutes a Breaking Change

- Removing a field
- Renaming a field
- Changing a field's type
- Making an optional field required
- Changing enum values
- Changing validation rules to be stricter
- Changing the semantics of a field

### Non-Breaking Changes (Allowed)

- Adding a new optional field
- Adding a new endpoint
- Relaxing validation (wider acceptance)
- Adding new enum values
- Deprecating (but keeping) a field

---

## FORBIDDEN

- Removing or renaming fields without a migration strategy
- Changing semantics of existing fields
- Silent behavioral changes
- Consumers needing simultaneous updates to avoid breakage

---

## Transition Rule

> APIs MUST support old and new contracts concurrently during transitions.

This means:

1. Add new field as optional
2. Update consumers to use new field
3. Mark old field as deprecated
4. After all consumers updated, remove old field in next major version

---

## Patterns

### Adding an Optional Field (Safe)

```typescript
// Before
interface SignalResponse {
  id: string;
  title: string;
  status: SignalStatus;
}

// After - safe change
interface SignalResponse {
  id: string;
  title: string;
  status: SignalStatus;
  priority?: 'low' | 'medium' | 'high'; // NEW: optional
}

// Zod schema
const SignalResponseSchema = z.object({
  id: z.string().uuid(),
  title: z.string(),
  status: SignalStatusSchema,
  priority: z.enum(['low', 'medium', 'high']).optional(), // NEW
});
```

### Deprecation Pattern

```typescript
interface SignalResponse {
  id: string;
  title: string;
  status: SignalStatus;

  /** @deprecated Use `priority` instead. Will be removed in v2. */
  importance?: 'low' | 'medium' | 'high';

  /** New field replacing `importance` */
  priority?: 'low' | 'medium' | 'high';
}
```

### Versioned Endpoints

```typescript
// Version 1 - original
app.get('/v1/signals/:id', handleGetSignalV1);

// Version 2 - breaking changes
app.get('/v2/signals/:id', handleGetSignalV2);

// Both active during transition
```

### Transitional API Response

```typescript
// During transition, return both old and new fields
const response: SignalResponse = {
  id: signal.id,
  title: signal.title,
  status: signal.status,
  // Old field (deprecated)
  importance: signal.priority,
  // New field
  priority: signal.priority,
};
```

---

## Contract File Organization

```
packages/contracts/src/
├── index.ts              # Re-exports all contracts
├── signal.ts             # Signal-related types
├── teammate.ts           # Teammate-related types
├── tenant.ts             # Tenant-related types
├── error.ts              # Error codes and Problem Detail
└── pagination.ts         # Shared pagination types
```

### Export Pattern

```typescript
// packages/contracts/src/signal.ts
import { z } from 'zod';

export const SignalStatusSchema = z.enum(['pending', 'approved', 'rejected', 'implemented']);
export type SignalStatus = z.infer<typeof SignalStatusSchema>;

export const SignalResponseSchema = z.object({
  id: z.string().uuid(),
  title: z.string(),
  status: SignalStatusSchema,
});
export type SignalResponse = z.infer<typeof SignalResponseSchema>;

// packages/contracts/src/index.ts
export * from './signal.js';
export * from './teammate.js';
// ... etc
```

---

## Checklist for Contract Changes

Before modifying any contract:

- [ ] Is this a breaking change? (See definition above)
- [ ] If breaking, is there a versioning or migration strategy?
- [ ] Are all consumers identified and updated?
- [ ] Is the old contract still supported during transition?
- [ ] Are tests updated for both old and new contracts?
- [ ] Is the change documented in the changelog?

---

## Hard Stops

If ANY of these occur, HALT and report immediately:

- Contract change is breaking and lacks versioning strategy
- API behavior no longer matches contract schemas
- Consumers would need simultaneous updates to avoid breakage
- Field semantics changed without version bump
- Required field added without default value

---

## Related

- `packages/contracts/` - Contract definitions
- `docs/ai/skills/api-routes/SKILL.md` - API implementation
- `.claude/rules/contract-evolution.md` - Claude Code auto-loaded version
