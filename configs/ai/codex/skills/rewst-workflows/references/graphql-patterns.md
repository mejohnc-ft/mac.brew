# GraphQL Patterns

## Show a workflow and triggers

```graphql
query($id: ID!) {
  workflow(where:{id:$id}) {
    id
    name
    updatedAt
    description
    triggers {
      id
      name
      enabled
      parameters
      vars
      triggerType { name }
    }
  }
}
```

## Show a template

```graphql
query($id: ID!) {
  template(where:{id:$id}) {
    id
    name
    updatedAt
    body
  }
}
```

## Start a trigger-aware test

```graphql
mutation($triggerInstance: OrgTriggerInstanceInput!, $workflowId: ID) {
  testWorkflowTrigger(triggerInstance:$triggerInstance, workflowId:$workflowId) {
    executionId
  }
}
```

## Inspect an execution

```graphql
query($id: ID!) {
  workflowExecution(where:{id:$id}) {
    id
    status
    numSuccessfulTasks
    processedCompletionAt
    taskLogs {
      originalWorkflowTaskName
      status
      taskExecutionId
      message
      result
    }
  }
  workflowExecutionContexts(workflowExecutionId:$id)
}
```

## Merge execution contexts

`workflowExecutionContexts` returns a JSON list, not a single object. Merge dict items in order before reading keys like `email_addresses`.

## Email verification pattern

For email workflows, check all of:

- `cron_email_addresses`
- `cron_additional_recipients`
- merged `email_addresses`
- number of `core_sendmail` successes

