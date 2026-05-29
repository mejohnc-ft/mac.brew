#!/usr/bin/env node
/**
 * Ralph Loop Control Script
 *
 * Manage active and historical ralph loops.
 *
 * Usage:
 *   ralph-loop status     - Show current loop status
 *   ralph-loop abort      - Abort active loop
 *   ralph-loop history    - Show loop history
 *   ralph-loop check      - Check completion promise manually
 */

const fs = require('fs');
const path = require('path');

const PAI_DIR = process.env.PAI_DIR || process.env.USERPROFILE + '\\.claude';
const stateManager = require('./lib/state-manager.js');
const promiseChecker = require('./lib/promise-checker.js');

function status() {
  const state = stateManager.getActiveLoop();

  if (!state) {
    console.log('No active ralph loop.');
    return;
  }

  console.log(`
RALPH LOOP STATUS
=================
ID:          ${state.id}
Task:        ${state.task}
Promise:     ${state.completion_promise}
Iteration:   ${state.current_iteration}/${state.max_iterations}
Started:     ${state.started_at}
Last Run:    ${state.last_iteration_at || 'N/A'}
Checkpoint:  ${state.checkpoint_enabled ? 'Enabled' : 'Disabled'}

History (last 5):
${state.history.slice(-5).map(h =>
    `  [${h.iteration}] ${h.timestamp}: ${h.summary.substring(0, 60)}...`
  ).join('\n') || '  (no iterations yet)'}
`);

  // Check current promise status
  const result = promiseChecker.checkPromise(state.completion_promise, state.cwd);
  console.log(`
PROMISE CHECK
=============
Status: ${result.satisfied ? 'SATISFIED' : 'NOT SATISFIED'}
Details: ${result.details}
`);
}

function abort(reason = 'manual') {
  const state = stateManager.getActiveLoop();

  if (!state) {
    console.log('No active ralph loop to abort.');
    return;
  }

  const aborted = stateManager.abortLoop(reason);
  console.log(`
RALPH LOOP ABORTED
==================
ID:         ${aborted.id}
Task:       ${aborted.task}
Iterations: ${aborted.current_iteration}
Reason:     ${reason}

Loop has been archived to history.
`);
}

function history(limit = 10) {
  const loops = stateManager.getHistory(limit);

  if (loops.length === 0) {
    console.log('No loop history found.');
    return;
  }

  console.log(`
RALPH LOOP HISTORY (Last ${limit})
${'='.repeat(35)}
`);

  loops.forEach(loop => {
    const status = loop.status === 'completed' ? 'SUCCESS' : 'ABORTED';
    console.log(`[${status}] ${loop.id}`);
    console.log(`  Task: ${loop.task.substring(0, 60)}...`);
    console.log(`  Promise: ${loop.completion_promise}`);
    console.log(`  Iterations: ${loop.current_iteration}`);
    console.log(`  Started: ${loop.started_at}`);
    console.log(`  Ended: ${loop.completed_at || loop.aborted_at}`);
    console.log('');
  });
}

function check() {
  const state = stateManager.getActiveLoop();

  if (!state) {
    console.log('No active ralph loop.');
    return;
  }

  const result = promiseChecker.checkPromise(state.completion_promise, state.cwd);

  console.log(`
PROMISE CHECK
=============
Promise: ${state.completion_promise}
Type:    ${result.type}
Status:  ${result.satisfied ? 'SATISFIED' : 'NOT SATISFIED'}
Details: ${result.details}
`);

  if (result.satisfied) {
    console.log('The loop will exit on next stop event.');
  } else {
    console.log('The loop will continue on next stop event.');
  }
}

// Main
const command = process.argv[2];

switch (command) {
  case 'status':
  case 's':
    status();
    break;

  case 'abort':
  case 'a':
    abort(process.argv[3] || 'manual');
    break;

  case 'history':
  case 'h':
    history(parseInt(process.argv[3]) || 10);
    break;

  case 'check':
  case 'c':
    check();
    break;

  default:
    console.log(`
Ralph Loop Control
==================

Commands:
  status, s       Show current loop status
  abort, a        Abort active loop
  history, h [N]  Show last N loops (default: 10)
  check, c        Check completion promise

Examples:
  node control.js status
  node control.js abort "user requested"
  node control.js history 5
  node control.js check
`);
}
