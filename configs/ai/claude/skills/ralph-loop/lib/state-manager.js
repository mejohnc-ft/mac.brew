#!/usr/bin/env node
/**
 * Ralph Loop State Manager
 * Manages loop state, iteration tracking, and persistence
 */

const fs = require('fs');
const path = require('path');
const crypto = require('crypto');

const PAI_DIR = process.env.PAI_DIR || process.env.USERPROFILE + '\\.claude';
const STATE_DIR = path.join(PAI_DIR, 'ralph-loop');
const ACTIVE_FILE = path.join(STATE_DIR, 'active.json');
const HISTORY_DIR = path.join(STATE_DIR, 'history');

// Ensure directories exist
if (!fs.existsSync(STATE_DIR)) fs.mkdirSync(STATE_DIR, { recursive: true });
if (!fs.existsSync(HISTORY_DIR)) fs.mkdirSync(HISTORY_DIR, { recursive: true });

/**
 * Generate a unique loop ID
 */
function generateId() {
  return 'ralph-' + crypto.randomBytes(4).toString('hex');
}

/**
 * Initialize a new ralph loop
 */
function initLoop(task, completionPromise, options = {}) {
  const state = {
    id: generateId(),
    task: task,
    completion_promise: completionPromise,
    started_at: new Date().toISOString(),
    current_iteration: 0,
    max_iterations: options.maxIterations || 25,
    checkpoint_enabled: options.checkpoint || false,
    voice_notify: options.voiceNotify || false,
    agents: options.agents || null,
    cwd: process.cwd(),
    history: []
  };

  fs.writeFileSync(ACTIVE_FILE, JSON.stringify(state, null, 2));
  return state;
}

/**
 * Get current active loop state
 */
function getActiveLoop() {
  if (!fs.existsSync(ACTIVE_FILE)) return null;
  try {
    return JSON.parse(fs.readFileSync(ACTIVE_FILE, 'utf8'));
  } catch (e) {
    return null;
  }
}

/**
 * Check if a loop is currently active
 */
function isLoopActive() {
  return fs.existsSync(ACTIVE_FILE);
}

/**
 * Increment iteration counter and log progress
 */
function incrementIteration(summary = '') {
  const state = getActiveLoop();
  if (!state) return null;

  state.current_iteration++;
  state.last_iteration_at = new Date().toISOString();
  state.history.push({
    iteration: state.current_iteration,
    timestamp: new Date().toISOString(),
    summary: summary
  });

  fs.writeFileSync(ACTIVE_FILE, JSON.stringify(state, null, 2));
  return state;
}

/**
 * Complete and archive the loop
 */
function completeLoop(finalSummary = '') {
  const state = getActiveLoop();
  if (!state) return null;

  state.completed_at = new Date().toISOString();
  state.final_summary = finalSummary;
  state.status = 'completed';

  // Archive to history
  const archivePath = path.join(HISTORY_DIR, `${state.id}.json`);
  fs.writeFileSync(archivePath, JSON.stringify(state, null, 2));

  // Remove active file
  fs.unlinkSync(ACTIVE_FILE);

  return state;
}

/**
 * Abort the loop (max iterations reached or user cancel)
 */
function abortLoop(reason = 'max_iterations') {
  const state = getActiveLoop();
  if (!state) return null;

  state.aborted_at = new Date().toISOString();
  state.abort_reason = reason;
  state.status = 'aborted';

  // Archive to history
  const archivePath = path.join(HISTORY_DIR, `${state.id}.json`);
  fs.writeFileSync(archivePath, JSON.stringify(state, null, 2));

  // Remove active file
  fs.unlinkSync(ACTIVE_FILE);

  return state;
}

/**
 * Update loop with arbitrary fields
 */
function updateLoop(updates) {
  const state = getActiveLoop();
  if (!state) return null;

  Object.assign(state, updates);
  fs.writeFileSync(ACTIVE_FILE, JSON.stringify(state, null, 2));
  return state;
}

/**
 * Get loop history
 */
function getHistory(limit = 10) {
  const files = fs.readdirSync(HISTORY_DIR)
    .filter(f => f.endsWith('.json'))
    .map(f => {
      const content = JSON.parse(fs.readFileSync(path.join(HISTORY_DIR, f), 'utf8'));
      return content;
    })
    .sort((a, b) => new Date(b.started_at) - new Date(a.started_at))
    .slice(0, limit);

  return files;
}

// CLI interface
if (require.main === module) {
  const args = process.argv.slice(2);
  const command = args[0];

  switch (command) {
    case 'init':
      const task = args[1];
      const promise = args[2];
      const maxIter = parseInt(args[3]) || 25;
      const state = initLoop(task, promise, { maxIterations: maxIter });
      console.log(JSON.stringify(state, null, 2));
      break;

    case 'get':
      console.log(JSON.stringify(getActiveLoop(), null, 2));
      break;

    case 'active':
      console.log(isLoopActive() ? 'true' : 'false');
      break;

    case 'increment':
      const summary = args[1] || '';
      console.log(JSON.stringify(incrementIteration(summary), null, 2));
      break;

    case 'complete':
      const finalSum = args[1] || '';
      console.log(JSON.stringify(completeLoop(finalSum), null, 2));
      break;

    case 'abort':
      const reason = args[1] || 'manual';
      console.log(JSON.stringify(abortLoop(reason), null, 2));
      break;

    case 'history':
      console.log(JSON.stringify(getHistory(parseInt(args[1]) || 10), null, 2));
      break;

    default:
      console.log('Usage: state-manager.js <command> [args]');
      console.log('Commands: init, get, active, increment, complete, abort, history');
  }
}

module.exports = {
  initLoop,
  getActiveLoop,
  isLoopActive,
  incrementIteration,
  completeLoop,
  abortLoop,
  updateLoop,
  getHistory
};
