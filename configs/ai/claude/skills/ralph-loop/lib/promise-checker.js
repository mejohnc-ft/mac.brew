#!/usr/bin/env node
/**
 * Ralph Loop Promise Checker
 * Evaluates completion promises to determine if loop should exit
 */

const fs = require('fs');
const path = require('path');
const { execSync } = require('child_process');

/**
 * Parse a completion promise string into a checkable condition
 *
 * Supported formats:
 * - "file.md exists" -> file existence check
 * - "file.md contains 'pattern'" -> file content check
 * - "npm test passes" -> command exit code check
 * - "git status clean" -> no uncommitted changes
 * - "user confirms" -> requires user input (always false in automated check)
 */
function parsePromise(promiseString) {
  const normalized = promiseString.toLowerCase().trim();

  // File exists check: "file.md exists" or "DONE.md exists"
  const existsMatch = promiseString.match(/^(.+?)\s+exists?$/i);
  if (existsMatch) {
    return { type: 'file_exists', path: existsMatch[1].trim() };
  }

  // File contains check: "file.md contains 'pattern'"
  const containsMatch = promiseString.match(/^(.+?)\s+contains?\s+['"](.+?)['"]$/i);
  if (containsMatch) {
    return { type: 'file_contains', path: containsMatch[1].trim(), pattern: containsMatch[2] };
  }

  // Command passes check: "npm test passes" or "command passes"
  const passesMatch = promiseString.match(/^(.+?)\s+pass(?:es)?$/i);
  if (passesMatch) {
    return { type: 'command_passes', command: passesMatch[1].trim() };
  }

  // Git clean check
  if (normalized.includes('git status clean') || normalized.includes('git clean')) {
    return { type: 'git_clean' };
  }

  // All tests green
  if (normalized.includes('all tests') && (normalized.includes('green') || normalized.includes('pass'))) {
    return { type: 'command_passes', command: 'npm test' };
  }

  // Build succeeds
  if (normalized.includes('build') && (normalized.includes('succeed') || normalized.includes('pass'))) {
    return { type: 'command_passes', command: 'npm run build' };
  }

  // User confirms - always returns false in automated mode
  if (normalized.includes('user') && normalized.includes('confirm')) {
    return { type: 'user_confirms' };
  }

  // Default: treat as file exists
  return { type: 'file_exists', path: promiseString.trim() };
}

/**
 * Check if a completion promise is satisfied
 */
function checkPromise(promiseString, cwd = process.cwd()) {
  const parsed = parsePromise(promiseString);

  try {
    switch (parsed.type) {
      case 'file_exists': {
        const filePath = path.isAbsolute(parsed.path)
          ? parsed.path
          : path.join(cwd, parsed.path);
        const exists = fs.existsSync(filePath);
        return {
          satisfied: exists,
          type: parsed.type,
          details: exists ? `File ${parsed.path} exists` : `File ${parsed.path} not found`
        };
      }

      case 'file_contains': {
        const filePath = path.isAbsolute(parsed.path)
          ? parsed.path
          : path.join(cwd, parsed.path);
        if (!fs.existsSync(filePath)) {
          return {
            satisfied: false,
            type: parsed.type,
            details: `File ${parsed.path} not found`
          };
        }
        const content = fs.readFileSync(filePath, 'utf8');
        const contains = content.includes(parsed.pattern);
        return {
          satisfied: contains,
          type: parsed.type,
          details: contains
            ? `File contains '${parsed.pattern}'`
            : `Pattern '${parsed.pattern}' not found in file`
        };
      }

      case 'command_passes': {
        try {
          execSync(parsed.command, { cwd, stdio: 'pipe', timeout: 300000 });
          return {
            satisfied: true,
            type: parsed.type,
            details: `Command '${parsed.command}' passed`
          };
        } catch (e) {
          return {
            satisfied: false,
            type: parsed.type,
            details: `Command '${parsed.command}' failed: ${e.message}`
          };
        }
      }

      case 'git_clean': {
        try {
          const status = execSync('git status --porcelain', { cwd, encoding: 'utf8' });
          const clean = status.trim() === '';
          return {
            satisfied: clean,
            type: parsed.type,
            details: clean ? 'Git working directory is clean' : 'Uncommitted changes exist'
          };
        } catch (e) {
          return {
            satisfied: false,
            type: parsed.type,
            details: `Git status check failed: ${e.message}`
          };
        }
      }

      case 'user_confirms': {
        // In automated mode, user confirmation is always false
        // The hook will need to prompt the user
        return {
          satisfied: false,
          type: parsed.type,
          details: 'User confirmation required',
          requires_user_input: true
        };
      }

      default:
        return {
          satisfied: false,
          type: 'unknown',
          details: `Unknown promise type: ${parsed.type}`
        };
    }
  } catch (e) {
    return {
      satisfied: false,
      type: parsed.type,
      details: `Error checking promise: ${e.message}`,
      error: e.message
    };
  }
}

// CLI interface
if (require.main === module) {
  const promise = process.argv[2];
  const cwd = process.argv[3] || process.cwd();

  if (!promise) {
    console.log('Usage: promise-checker.js "<promise>" [cwd]');
    console.log('');
    console.log('Examples:');
    console.log('  promise-checker.js "DONE.md exists"');
    console.log('  promise-checker.js "npm test passes"');
    console.log('  promise-checker.js "README.md contains \'v2.0\'"');
    process.exit(1);
  }

  const result = checkPromise(promise, cwd);
  console.log(JSON.stringify(result, null, 2));
  process.exit(result.satisfied ? 0 : 1);
}

module.exports = {
  parsePromise,
  checkPromise
};
