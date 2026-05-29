---
name: "frontend-react"
description: "Build and modify apps/web React features using auth guards, typed API client calls, React Query patterns, form validation, error boundaries, and shadcn/ui conventions. Use when implementing frontend pages, components, hooks, or web data flows."
---


# Skill: Frontend React

> **Building React components and pages for the centrexAI web application**
>
> Applies to: `apps/web/`

---

## Overview

The centrexAI web application is a React + Vite application using MSAL for authentication, React Query for data fetching, and shadcn/ui for components. This skill covers the patterns for building correct, maintainable frontend code.

---

## ALWAYS

### Authentication & Authorization

- Use `useAuth()` hook from `@/auth` for all auth operations
- Use `ProtectedRoute` component for route guards
- Use `RoleGuard` component for role-based access
- Get access tokens via `getAccessToken()` before API calls
- Pass tokens to API calls via `{ token }` option

### API Integration

- Use `api` client from `@/lib/api.ts` for all HTTP requests
- Handle errors with `ApiError` class (includes `status`, `data`, `message`)
- Use typed responses: `api.get<ResponseType>(endpoint, { token })`
- Never hardcode API URLs — use `VITE_API_BASE_URL` environment variable

### Data Fetching (React Query)

- Use `@tanstack/react-query` for server state management
- Follow queryKey conventions: `['resource', id]` or `['resource', { filter }]`
- Use `useMutation` for all write operations
- Implement optimistic updates for responsive UX
- Invalidate related queries after mutations

### Form Handling

- Use `react-hook-form` for form state management
- Validate with Zod schemas: `standardSchemaResolver(schema)`
- Match form schemas to API request schemas from `@core/contracts`
- Show field-level errors with accessible labels

### Error Handling

- Wrap pages/sections in `ErrorBoundary` component
- Use `ChunkErrorBoundary` for lazy-loaded components
- Show user-friendly errors via `ToastProvider` / Sonner
- Never expose stack traces in production UI
- Log errors to console in development only

### Component Patterns

- Use shadcn/ui components from `@/components/ui/`
- Style variants with `class-variance-authority` (CVA)
- Use `cn()` utility from `@/lib/utils` for class merging
- Follow component composition: `Card > CardHeader > CardTitle` pattern

### Accessibility

- Include `aria-label` or `aria-labelledby` on interactive elements
- Use semantic HTML: `<nav>`, `<main>`, `<article>`, `<section>`
- Add `role="alert"` and `aria-live` for dynamic error messages
- Ensure all buttons have visible labels or `aria-label`
- Support keyboard navigation (focus management)

---

## NEVER

### Security

- Expose API keys or secrets in frontend code
- Log sensitive user data (tokens, PII)
- Trust URL parameters without validation
- Render user HTML without sanitization
- Store tokens in localStorage (use MSAL session)

### Code Quality

- Use `any` types — always use proper TypeScript types
- Use `// @ts-ignore` or `// @ts-expect-error` without justification
- Use `console.log` in production code (use conditional logging)
- Use inline styles — use Tailwind CSS classes
- Throw raw `Error()` — use typed errors

### State Management

- Prop drill beyond 2 levels — use Context or composition
- Store server state in `useState` — use React Query
- Manual cache invalidation — let React Query handle it
- Block renders with synchronous data fetching

### Component Anti-Patterns

- Create component files > 300 lines — split into smaller components
- Mix business logic in UI components
- Direct DOM manipulation — use React refs
- Use class components — use functional components with hooks

---

## Patterns

### API Call with Authentication

```typescript
import { useAuth } from '@/auth';
import { api, ApiError } from '@/lib/api';
import { useQuery } from '@tanstack/react-query';

function useSignals() {
  const { getAccessToken } = useAuth();

  return useQuery({
    queryKey: ['signals'],
    queryFn: async () => {
      const token = await getAccessToken();
      if (!token) throw new Error('Not authenticated');
      return api.get<SignalListResponse>('/v1/signals', { token });
    },
  });
}
```

### Mutation with Optimistic Update

```typescript
import { useMutation, useQueryClient } from '@tanstack/react-query';

function useVote(signalId: string) {
  const { getAccessToken } = useAuth();
  const queryClient = useQueryClient();

  return useMutation({
    mutationFn: async (voteType: VoteType) => {
      const token = await getAccessToken();
      return api.post<SignalResponse>(`/v1/signals/${signalId}/vote`, { voteType }, { token });
    },
    onMutate: async (voteType) => {
      // Cancel outgoing refetches
      await queryClient.cancelQueries({ queryKey: ['signals', signalId] });

      // Snapshot previous value
      const previous = queryClient.getQueryData(['signals', signalId]);

      // Optimistically update
      queryClient.setQueryData(['signals', signalId], (old: SignalResponse) => ({
        ...old,
        myVote: voteType,
      }));

      return { previous };
    },
    onError: (_err, _vars, context) => {
      // Rollback on error
      queryClient.setQueryData(['signals', signalId], context?.previous);
    },
    onSettled: () => {
      // Always refetch
      queryClient.invalidateQueries({ queryKey: ['signals'] });
    },
  });
}
```

### Form with Zod Validation

```typescript
import { useForm } from 'react-hook-form';
import { standardSchemaResolver } from '@hookform/resolvers/standard-schema';
import { CreateSignalRequestSchema, type CreateSignalRequest } from '@core/contracts';

function SignalForm() {
  const form = useForm<CreateSignalRequest>({
    resolver: standardSchemaResolver(CreateSignalRequestSchema),
    defaultValues: {
      originalText: '',
      aiInterpretedText: '',
    },
  });

  const onSubmit = async (data: CreateSignalRequest) => {
    // Submit logic
  };

  return (
    <form onSubmit={form.handleSubmit(onSubmit)}>
      <div>
        <label htmlFor="originalText">Your feedback</label>
        <Textarea
          id="originalText"
          {...form.register('originalText')}
          aria-invalid={form.formState.errors.originalText ? 'true' : 'false'}
        />
        {form.formState.errors.originalText && (
          <span role="alert" className="text-destructive text-sm">
            {form.formState.errors.originalText.message}
          </span>
        )}
      </div>
      <Button type="submit" disabled={form.formState.isSubmitting}>
        Submit
      </Button>
    </form>
  );
}
```

### Error Boundary Usage

```tsx
import { ErrorBoundary } from '@/components/shared/ErrorBoundary';

function SignalsPage() {
  return (
    <ErrorBoundary
      onError={(error) => console.error('[SignalsPage]', error)}
      onReset={() => window.location.reload()}
    >
      <SignalList />
    </ErrorBoundary>
  );
}
```

### Protected Route

```tsx
import { ProtectedRoute } from '@/components/auth/ProtectedRoute';

// In router
<Route
  path="/dashboard"
  element={
    <ProtectedRoute>
      <DashboardPage />
    </ProtectedRoute>
  }
/>;
```

### Component with CVA Variants

```tsx
import { cva, type VariantProps } from 'class-variance-authority';
import { cn } from '@/lib/utils';

const badgeVariants = cva(
  'inline-flex items-center rounded-full px-2.5 py-0.5 text-xs font-semibold',
  {
    variants: {
      variant: {
        default: 'bg-primary text-primary-foreground',
        success: 'bg-green-100 text-green-800',
        warning: 'bg-yellow-100 text-yellow-800',
        destructive: 'bg-destructive text-destructive-foreground',
      },
    },
    defaultVariants: {
      variant: 'default',
    },
  }
);

interface BadgeProps
  extends React.HTMLAttributes<HTMLDivElement>, VariantProps<typeof badgeVariants> {}

export function Badge({ className, variant, ...props }: BadgeProps) {
  return <div className={cn(badgeVariants({ variant }), className)} {...props} />;
}
```

---

## File Organization

```
apps/web/src/
├── auth/                 # Authentication (MSAL, useAuth)
├── components/
│   ├── auth/             # Auth components (ProtectedRoute, RoleGuard)
│   ├── layout/           # Layout components (AppShell, Header, Sidebar)
│   ├── shared/           # Shared components (ErrorBoundary, ToastProvider)
│   ├── ui/               # shadcn/ui primitives
│   └── {feature}/        # Feature-specific components
├── contexts/             # React contexts
├── hooks/                # Custom hooks
├── lib/                  # Utilities (api.ts, utils.ts)
├── pages/                # Page components
│   ├── admin/            # Admin pages
│   ├── signals/          # Signals Hub pages
│   └── teammates/        # Teammate pages
└── router.tsx            # Route definitions
```

---

## Testing

```typescript
import { render, screen } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { describe, it, expect, vi } from 'vitest';

describe('SignalForm', () => {
  it('should display validation error for empty input', async () => {
    const user = userEvent.setup();
    render(<SignalForm />);

    await user.click(screen.getByRole('button', { name: /submit/i }));

    expect(await screen.findByRole('alert')).toHaveTextContent(
      'Feedback is required'
    );
  });

  it('should submit valid form data', async () => {
    const onSubmit = vi.fn();
    const user = userEvent.setup();

    render(<SignalForm onSubmit={onSubmit} />);

    await user.type(screen.getByLabelText(/feedback/i), 'My feedback');
    await user.click(screen.getByRole('button', { name: /submit/i }));

    expect(onSubmit).toHaveBeenCalledWith(
      expect.objectContaining({ originalText: 'My feedback' })
    );
  });
});
```

---

## Hard Stops

If ANY of these occur, HALT and report immediately:

- Auth tokens being stored in localStorage
- API keys exposed in client code
- User input rendered without sanitization
- Component bypasses `ProtectedRoute` for auth
- `any` types used without justification

---

## Related

- `docs/ai/skills/api-routes/SKILL.md` - API endpoints
- `packages/contracts/` - Request/response types
- `apps/web/src/auth/` - Authentication patterns
- `.claude/rules/frontend-react.md` - Claude Code auto-loaded version
