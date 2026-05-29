---
name: orchestrating-msp-automation
description: Coordinates MSP automation work across Rewst, Jinja/JSON, Microsoft Copilot/Graph, and Azure AI Foundry. Use for multi-step plans, cross-domain decisions, or when routing to the right specialist matters.
allowed-tools: Read, Grep, Glob
---

# Orchestrating MSP Automation

## Operating loop
1) Read shared context:
   - .claude/skills/shared/PROJECT-CONTEXT.md
   - .claude/skills/shared/HANDOFF-CONTRACT.md
2) Classify request into one primary domain:
   - Rewst workflow design
   - Jinja/JSON authoring
   - M365 Copilot/Graph integration
   - Azure AI Foundry agent/tooling
   - Security/governance
   - Testing/evals
   - Principal-level architecture/standardization
3) Produce a short execution plan (5–10 bullets) and assign:
   - Primary skill
   - Required reviewers (security + QA by default)
4) Enforce the handoff contract JSON envelope.
5) If decision-making is requested, run DECISION-PROTOCOL.md.

## Output format
- Start with: selected primary domain + why
- Then: plan
- Then: artifacts (code blocks)
- Then: test plan + risks
