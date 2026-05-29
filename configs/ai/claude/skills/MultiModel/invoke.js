#!/usr/bin/env node
/**
 * MultiModel Provider Dispatcher
 *
 * Dispatches tasks to external AI providers (Gemini, Codex, Copilot, Zhipu, MiniMax).
 * Supports parallel orchestration, pipeline execution, and consensus voting.
 *
 * Usage:
 *   node invoke.js dispatch --provider <name> --model <model> "prompt"
 *   node invoke.js parallel --agents "role1:provider1,role2:provider2" "prompt"
 *   node invoke.js pipeline --stages "role1:provider1,role2:provider2" "prompt"
 *   node invoke.js consensus --voters "provider1,provider2" --threshold 0.75 "question"
 *   node invoke.js list-providers
 */

const { spawn } = require('child_process');
const path = require('path');
const fs = require('fs');
const os = require('os');

// Default provider configurations
const DEFAULT_PROVIDERS = {
  claude: {
    type: 'cli',
    cli: 'claude',
    buildArgs: (prompt, model) => ['--print', '-m', model || 'opus', prompt],
    defaultModel: 'opus',
    enabled: true
  },
  gemini: {
    type: 'cli',
    cli: 'gemini',
    buildArgs: (prompt, model) => ['--model', model || 'gemini-2.5-pro', prompt],
    defaultModel: 'gemini-2.5-pro',
    envVar: 'GOOGLE_API_KEY',
    enabled: true
  },
  codex: {
    type: 'cli',
    cli: 'codex',
    buildArgs: (prompt, model) => ['-m', model || 'gpt-4o', prompt],
    defaultModel: 'gpt-4o',
    enabled: true
  },
  copilot: {
    type: 'cli',
    cli: 'gh',
    buildArgs: (prompt) => ['copilot', 'suggest', '-t', 'code', prompt],
    defaultModel: 'copilot',
    enabled: true
  },
  zhipu: {
    type: 'api',
    baseUrl: 'https://open.bigmodel.cn/api/paas/v4',
    envVar: 'ZHIPU_API_KEY',
    defaultModel: 'glm-4.7',
    enabled: true
  },
  minimax: {
    type: 'api',
    baseUrl: 'https://api.minimax.chat/v1',
    envVar: 'MINIMAX_API_KEY',
    defaultModel: 'm2.1',
    enabled: true
  }
};

/**
 * Load settings from ~/.claude/settings.json
 */
function loadSettings() {
  const settingsPath = path.join(os.homedir(), '.claude', 'settings.json');
  try {
    if (fs.existsSync(settingsPath)) {
      const content = fs.readFileSync(settingsPath, 'utf-8');
      return JSON.parse(content);
    }
  } catch (err) {
    console.error(`Warning: Could not load settings: ${err.message}`);
  }
  return {};
}

/**
 * Merge settings with default provider configurations
 */
function getProviders() {
  const settings = loadSettings();
  const providers = { ...DEFAULT_PROVIDERS };

  if (settings.providers) {
    for (const [name, config] of Object.entries(settings.providers)) {
      if (providers[name]) {
        providers[name] = { ...providers[name], ...config };
      } else {
        // Add new provider from settings
        providers[name] = config;
      }
    }
  }

  return providers;
}

/**
 * Dispatch to CLI-based provider
 */
async function dispatchToCLI(provider, model, prompt) {
  const providers = getProviders();
  const config = providers[provider];

  if (!config) {
    throw new Error(`Unknown provider: ${provider}. Use 'list-providers' to see available providers.`);
  }

  if (!config.enabled) {
    throw new Error(`Provider '${provider}' is disabled in settings.`);
  }

  if (config.type === 'api') {
    return dispatchToAPI(provider, model, prompt);
  }

  return new Promise((resolve, reject) => {
    const effectiveModel = model || config.defaultModel;
    const args = config.buildArgs ? config.buildArgs(prompt, effectiveModel) : [prompt];

    console.error(`[${provider}] Invoking: ${config.cli} ${args.join(' ').substring(0, 100)}...`);

    const proc = spawn(config.cli, args, {
      stdio: ['pipe', 'pipe', 'pipe'],
      shell: process.platform === 'win32'
    });

    let stdout = '';
    let stderr = '';

    proc.stdout.on('data', data => {
      stdout += data.toString();
    });

    proc.stderr.on('data', data => {
      stderr += data.toString();
    });

    proc.on('error', err => {
      reject(new Error(`Failed to start ${config.cli}: ${err.message}`));
    });

    proc.on('close', code => {
      if (code === 0) {
        resolve(stdout.trim());
      } else {
        reject(new Error(`${provider} exited with code ${code}: ${stderr || stdout}`));
      }
    });

    // Set timeout (5 minutes)
    setTimeout(() => {
      proc.kill();
      reject(new Error(`${provider} timed out after 5 minutes`));
    }, 300000);
  });
}

/**
 * Dispatch to API-based provider (OpenAI-compatible)
 */
async function dispatchToAPI(provider, model, prompt) {
  const providers = getProviders();
  const config = providers[provider];

  if (!config) {
    throw new Error(`Unknown provider: ${provider}`);
  }

  const apiKey = process.env[config.envVar];
  if (!apiKey) {
    throw new Error(`API key not found. Set the ${config.envVar} environment variable.`);
  }

  const effectiveModel = model || config.defaultModel;
  const url = `${config.baseUrl}/chat/completions`;

  console.error(`[${provider}] Calling API: ${url} with model ${effectiveModel}`);

  try {
    const response = await fetch(url, {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${apiKey}`,
        'Content-Type': 'application/json'
      },
      body: JSON.stringify({
        model: effectiveModel,
        messages: [{ role: 'user', content: prompt }],
        temperature: 0.7,
        max_tokens: 4096
      })
    });

    if (!response.ok) {
      const errorText = await response.text();
      throw new Error(`API error ${response.status}: ${errorText}`);
    }

    const data = await response.json();

    if (data.error) {
      throw new Error(`API returned error: ${data.error.message || JSON.stringify(data.error)}`);
    }

    if (!data.choices || !data.choices[0] || !data.choices[0].message) {
      throw new Error(`Unexpected API response format: ${JSON.stringify(data)}`);
    }

    return data.choices[0].message.content;
  } catch (err) {
    if (err.name === 'TypeError' && err.message.includes('fetch')) {
      throw new Error(`Network error calling ${provider} API: ${err.message}`);
    }
    throw err;
  }
}

/**
 * Orchestrate multiple agents in parallel
 */
async function orchestrateParallel(agents, prompt) {
  console.error(`[Parallel] Starting ${agents.length} agents...`);

  const tasks = agents.map(({ role, provider, model }) => {
    const rolePrompt = role ? `As ${role}: ${prompt}` : prompt;
    return dispatchToCLI(provider, model, rolePrompt)
      .then(output => ({ role, provider, model, output, status: 'success' }))
      .catch(error => ({ role, provider, model, output: null, status: 'error', error: error.message }));
  });

  const results = await Promise.all(tasks);

  const succeeded = results.filter(r => r.status === 'success').length;
  console.error(`[Parallel] Completed: ${succeeded}/${agents.length} succeeded`);

  return results;
}

/**
 * Orchestrate agents in a pipeline (sequential)
 */
async function orchestratePipeline(stages, prompt) {
  console.error(`[Pipeline] Starting ${stages.length}-stage pipeline...`);

  let context = prompt;
  const results = [];

  for (let i = 0; i < stages.length; i++) {
    const { role, provider, model } = stages[i];
    console.error(`[Pipeline] Stage ${i + 1}/${stages.length}: ${role || provider}`);

    const stagePrompt = i === 0
      ? (role ? `As ${role}: ${prompt}` : prompt)
      : `Previous context:\n${context}\n\nYour task${role ? ` as ${role}` : ''}: Continue with the original request.`;

    try {
      const output = await dispatchToCLI(provider, model, stagePrompt);
      results.push({ stage: i + 1, role, provider, model, output, status: 'success' });
      context = output;
    } catch (error) {
      results.push({ stage: i + 1, role, provider, model, output: null, status: 'error', error: error.message });
      console.error(`[Pipeline] Stage ${i + 1} failed: ${error.message}`);
      break; // Stop pipeline on error
    }
  }

  return results;
}

/**
 * Run consensus voting among multiple providers
 */
async function runConsensus(voters, threshold, question) {
  console.error(`[Consensus] Polling ${voters.length} voters with threshold ${threshold}...`);

  // Ask each voter the question
  const results = await orchestrateParallel(
    voters.map(v => ({ role: 'voter', provider: v.provider, model: v.model })),
    `Answer YES or NO to the following question. Only respond with YES or NO, nothing else.\n\nQuestion: ${question}`
  );

  // Count votes
  const votes = results.map(r => {
    if (r.status !== 'success') return null;
    const answer = r.output.toUpperCase().trim();
    if (answer.includes('YES')) return 'YES';
    if (answer.includes('NO')) return 'NO';
    return 'ABSTAIN';
  });

  const yesCount = votes.filter(v => v === 'YES').length;
  const noCount = votes.filter(v => v === 'NO').length;
  const validVotes = votes.filter(v => v === 'YES' || v === 'NO').length;

  const agreement = validVotes > 0 ? Math.max(yesCount, noCount) / validVotes : 0;
  const decision = yesCount >= noCount ? 'YES' : 'NO';
  const consensus = agreement >= threshold;

  return {
    question,
    votes: results.map((r, i) => ({
      provider: r.provider,
      model: r.model,
      vote: votes[i],
      raw: r.output
    })),
    summary: {
      yes: yesCount,
      no: noCount,
      abstain: votes.filter(v => v === 'ABSTAIN').length,
      errors: votes.filter(v => v === null).length
    },
    decision,
    agreement: (agreement * 100).toFixed(1) + '%',
    consensusReached: consensus,
    threshold: (threshold * 100).toFixed(1) + '%'
  };
}

/**
 * Parse agent specification string
 * Format: "role1:provider1:model1,role2:provider2:model2" or "role1:provider1,role2:provider2"
 */
function parseAgentSpec(spec) {
  const providers = getProviders();
  return spec.split(',').map(part => {
    const segments = part.trim().split(':');
    if (segments.length === 1) {
      // Just provider name
      const provider = segments[0];
      return { role: null, provider, model: providers[provider]?.defaultModel };
    } else if (segments.length === 2) {
      // role:provider or provider:model
      const [first, second] = segments;
      if (providers[second]) {
        // role:provider
        return { role: first, provider: second, model: providers[second]?.defaultModel };
      } else if (providers[first]) {
        // provider:model
        return { role: null, provider: first, model: second };
      }
      // Assume role:provider
      return { role: first, provider: second, model: null };
    } else {
      // role:provider:model
      const [role, provider, model] = segments;
      return { role, provider, model };
    }
  });
}

/**
 * Parse voter specification string
 * Format: "provider1,provider2" or "provider1:model1,provider2:model2"
 */
function parseVoterSpec(spec) {
  const providers = getProviders();
  return spec.split(',').map(part => {
    const segments = part.trim().split(':');
    const provider = segments[0];
    const model = segments[1] || providers[provider]?.defaultModel;
    return { provider, model };
  });
}

/**
 * Print usage information
 */
function printUsage() {
  console.log(`
MultiModel Provider Dispatcher

USAGE:
  node invoke.js <command> [options] "prompt"

COMMANDS:
  dispatch      Send a prompt to a single provider
  parallel      Run multiple agents in parallel
  pipeline      Run agents sequentially, passing context
  consensus     Vote on a yes/no question
  list-providers Show available providers

DISPATCH OPTIONS:
  --provider, -p <name>   Provider name (gemini, codex, copilot, zhipu, minimax)
  --model, -m <model>     Model to use (optional, uses default if not specified)

PARALLEL/PIPELINE OPTIONS:
  --agents, -a <spec>     Agent specification
                          Format: "role1:provider1,role2:provider2"
                          Example: "analyst:gemini,reviewer:codex"

CONSENSUS OPTIONS:
  --voters, -v <spec>     Voter specification
                          Format: "provider1,provider2,provider3"
  --threshold, -t <n>     Agreement threshold (0.0-1.0, default: 0.75)

EXAMPLES:
  # Single provider dispatch
  node invoke.js dispatch -p gemini -m gemini-2.5-pro "Explain async/await"

  # Parallel execution
  node invoke.js parallel -a "analyst:gemini,critic:codex" "Review this code"

  # Pipeline execution
  node invoke.js pipeline -a "writer:gemini,editor:codex,reviewer:zhipu" "Write a function"

  # Consensus voting
  node invoke.js consensus -v "gemini,codex,zhipu" -t 0.66 "Is this code safe?"

  # List available providers
  node invoke.js list-providers
`);
}

/**
 * List available providers
 */
function listProviders() {
  const providers = getProviders();
  console.log('\nAvailable Providers:\n');

  for (const [name, config] of Object.entries(providers)) {
    const status = config.enabled ? 'enabled' : 'disabled';
    const type = config.type || 'cli';
    const defaultModel = config.defaultModel || 'default';
    const envNote = config.envVar ? ` (requires ${config.envVar})` : '';

    console.log(`  ${name}`);
    console.log(`    Type: ${type} | Status: ${status} | Default Model: ${defaultModel}${envNote}`);
    if (config.models) {
      console.log(`    Models: ${config.models.join(', ')}`);
    }
    if (config.role) {
      console.log(`    Role: ${config.role}`);
    }
    console.log();
  }
}

/**
 * Parse command line arguments
 */
function parseArgs(args) {
  const result = {
    command: null,
    provider: null,
    model: null,
    agents: null,
    voters: null,
    threshold: 0.75,
    prompt: null
  };

  let i = 0;
  while (i < args.length) {
    const arg = args[i];

    if (!result.command && !arg.startsWith('-')) {
      result.command = arg;
      i++;
      continue;
    }

    switch (arg) {
      case '--provider':
      case '-p':
        result.provider = args[++i];
        break;
      case '--model':
      case '-m':
        result.model = args[++i];
        break;
      case '--agents':
      case '-a':
        result.agents = args[++i];
        break;
      case '--voters':
      case '-v':
        result.voters = args[++i];
        break;
      case '--threshold':
      case '-t':
        result.threshold = parseFloat(args[++i]);
        break;
      case '--help':
      case '-h':
        result.command = 'help';
        break;
      default:
        if (!arg.startsWith('-')) {
          result.prompt = arg;
        }
        break;
    }
    i++;
  }

  return result;
}

/**
 * Format output as JSON
 */
function formatOutput(data) {
  return JSON.stringify(data, null, 2);
}

/**
 * Main entry point
 */
async function main() {
  const args = parseArgs(process.argv.slice(2));

  if (!args.command || args.command === 'help') {
    printUsage();
    process.exit(0);
  }

  try {
    let result;

    switch (args.command) {
      case 'dispatch':
        if (!args.provider) {
          console.error('Error: --provider is required for dispatch command');
          process.exit(1);
        }
        if (!args.prompt) {
          console.error('Error: prompt is required');
          process.exit(1);
        }
        result = await dispatchToCLI(args.provider, args.model, args.prompt);
        console.log(result);
        break;

      case 'parallel':
        if (!args.agents) {
          console.error('Error: --agents is required for parallel command');
          process.exit(1);
        }
        if (!args.prompt) {
          console.error('Error: prompt is required');
          process.exit(1);
        }
        const parallelAgents = parseAgentSpec(args.agents);
        result = await orchestrateParallel(parallelAgents, args.prompt);
        console.log(formatOutput(result));
        break;

      case 'pipeline':
        if (!args.agents) {
          console.error('Error: --agents is required for pipeline command');
          process.exit(1);
        }
        if (!args.prompt) {
          console.error('Error: prompt is required');
          process.exit(1);
        }
        const pipelineStages = parseAgentSpec(args.agents);
        result = await orchestratePipeline(pipelineStages, args.prompt);
        console.log(formatOutput(result));
        break;

      case 'consensus':
        if (!args.voters) {
          console.error('Error: --voters is required for consensus command');
          process.exit(1);
        }
        if (!args.prompt) {
          console.error('Error: question is required');
          process.exit(1);
        }
        const voters = parseVoterSpec(args.voters);
        result = await runConsensus(voters, args.threshold, args.prompt);
        console.log(formatOutput(result));
        break;

      case 'list-providers':
        listProviders();
        break;

      default:
        console.error(`Unknown command: ${args.command}`);
        printUsage();
        process.exit(1);
    }
  } catch (error) {
    console.error(`Error: ${error.message}`);
    if (process.env.DEBUG) {
      console.error(error.stack);
    }
    process.exit(1);
  }
}

// Run main
main().catch(err => {
  console.error(`Fatal error: ${err.message}`);
  process.exit(1);
});

// Export functions for programmatic use
module.exports = {
  dispatchToCLI,
  dispatchToAPI,
  orchestrateParallel,
  orchestratePipeline,
  runConsensus,
  getProviders,
  parseAgentSpec,
  parseVoterSpec
};
