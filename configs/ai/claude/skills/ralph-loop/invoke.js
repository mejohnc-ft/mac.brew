#!/usr/bin/env node
/**
 * Ralph Loop Invocation Handler
 *
 * Parses /ralph-loop command and initializes the loop state.
 *
 * Usage:
 *   /ralph-loop "task description" --completion-promise "condition" [options]
 *
 * Options:
 *   --completion-promise "condition"  Required. Condition to check for exit.
 *   --max-iterations N                Max loop iterations (default: 25)
 *   --checkpoint-on-iteration         Git commit after each iteration
 *   --voice-notify                    Voice notification on completion
 *   --agents "name:role,..."          Multi-agent mode
 */

const fs = require('fs');
const path = require('path');

const PAI_DIR = process.env.PAI_DIR || process.env.USERPROFILE + '\\.claude';

/**
 * Parse command line arguments
 */
function parseArgs(argsString) {
  const result = {
    task: '',
    completionPromise: '',
    maxIterations: 25,
    checkpoint: false,
    voiceNotify: false,
    agents: null
  };

  // Extract the task (first quoted string)
  const taskMatch = argsString.match(/^["'](.+?)["']/);
  if (taskMatch) {
    result.task = taskMatch[1];
  }

  // Extract completion promise
  const promiseMatch = argsString.match(/--completion-promise\s+["'](.+?)["']/);
  if (promiseMatch) {
    result.completionPromise = promiseMatch[1];
  }

  // Extract max iterations
  const iterMatch = argsString.match(/--max-iterations\s+(\d+)/);
  if (iterMatch) {
    result.maxIterations = parseInt(iterMatch[1]);
  }

  // Check for checkpoint flag
  result.checkpoint = argsString.includes('--checkpoint-on-iteration');

  // Check for voice notify
  result.voiceNotify = argsString.includes('--voice-notify');

  // Extract agents
  const agentsMatch = argsString.match(/--agents\s+["'](.+?)["']/);
  if (agentsMatch) {
    result.agents = agentsMatch[1].split(',').map(a => {
      const [name, role] = a.trim().split(':');
      return { name: name.trim(), role: role?.trim() || 'general' };
    });
  }

  return result;
}

/**
 * Initialize the ralph loop
 */
function initLoop(options) {
  const stateManager = require('./lib/state-manager.js');

  const state = stateManager.initLoop(
    options.task,
    options.completionPromise,
    {
      maxIterations: options.maxIterations,
      checkpoint: options.checkpoint,
      voiceNotify: options.voiceNotify,
      agents: options.agents
    }
  );

  return state;
}

/**
 * Generate the initial prompt for Claude
 */
function generateInitialPrompt(options, state) {
  const agentSection = options.agents
    ? `\n**Agents:** ${options.agents.map(a => `${a.name} (${a.role})`).join(', ')}`
    : '';

  return `
# RALPH LOOP INITIALIZED

**Loop ID:** ${state.id}
**Task:** ${options.task}
**Completion Promise:** ${options.completionPromise}
**Max Iterations:** ${options.maxIterations}${agentSection}
${options.checkpoint ? '**Checkpoint:** Git commit after each iteration' : ''}

---

## Instructions

You are now in an autonomous loop. Work on the task above until the completion promise is satisfied.

The loop will automatically:
1. Let you work on the task
2. Intercept when you try to stop
3. Check if "${options.completionPromise}" is true
4. If YES: Exit and report success
5. If NO: Continue with another iteration

**Important:**
- Focus on making progress toward the completion condition
- Use todos to track your progress
- Each iteration builds on previous work
- You have ${options.maxIterations} iterations maximum

---

## BEGIN TASK

${options.task}

---
`;
}

// Main execution
if (require.main === module) {
  const argsString = process.argv.slice(2).join(' ');

  if (!argsString || argsString === '--help' || argsString === '-h') {
    console.log(`
Ralph Loop - Autonomous Iteration System

Usage:
  /ralph-loop "task" --completion-promise "condition" [options]

Required:
  "task"                           The task to work on (quoted)
  --completion-promise "condition" Exit condition (quoted)

Options:
  --max-iterations N               Max loops (default: 25)
  --checkpoint-on-iteration        Git commit after each iteration
  --voice-notify                   Voice notification on completion
  --agents "name:role,..."         Multi-agent mode

Examples:
  /ralph-loop "Build auth system" --completion-promise "auth tests pass"
  /ralph-loop "Execute PROJECT.md" --completion-promise "DONE.md exists" --max-iterations 50
  /ralph-loop "Refactor API" --completion-promise "all tests green" --checkpoint-on-iteration
`);
    process.exit(0);
  }

  const options = parseArgs(argsString);

  // Validate required fields
  if (!options.task) {
    console.error('ERROR: Task is required. Use quotes: /ralph-loop "your task here"');
    process.exit(1);
  }

  if (!options.completionPromise) {
    console.error('ERROR: Completion promise is required. Use --completion-promise "condition"');
    process.exit(1);
  }

  // Check for existing loop
  const stateManager = require('./lib/state-manager.js');
  if (stateManager.isLoopActive()) {
    const existing = stateManager.getActiveLoop();
    console.error(`ERROR: A ralph loop is already active (${existing.id})`);
    console.error(`Task: ${existing.task}`);
    console.error(`Iteration: ${existing.current_iteration}/${existing.max_iterations}`);
    console.error('');
    console.error('Use "ralph-loop abort" to cancel it first.');
    process.exit(1);
  }

  // Initialize the loop
  const state = initLoop(options);

  // Output the initial prompt
  console.log(generateInitialPrompt(options, state));
}

module.exports = { parseArgs, initLoop, generateInitialPrompt };
