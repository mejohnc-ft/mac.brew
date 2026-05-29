---
name: building-azure-ai-foundry-agents
description: Designs Azure AI Foundry agent architectures and tool/MCP integration patterns for MSP automations. Use when defining agent roles, tool boundaries, identity/consent flows, and edge↔cloud cooperation.
---

# Building Azure AI Foundry Agents

## Deliverables
- Agent role spec (inputs, tools, guardrails, outputs)
- Tool catalog (what the agent may do; explicit denies)
- Identity + consent model (who can authorize what)
- Failure modes: safe stop, escalate with evidence

## Coordination
- Requires security review for any cross-tenant or external tool access.
- Requires QA review with at least 3 eval cases.
