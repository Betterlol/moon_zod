/**
 * MoonZod Validator Benchmark
 *
 * Runs MoonBit moon_zod benchmark via `moon run cmd/main`.
 * Optionally accepts a JSON string to use as custom test data.
 */

const { execFileSync } = require('child_process');
const path = require('path');

const PROJECT_ROOT = path.resolve(__dirname, '../..');

function run(customJson) {
  console.log('  Running MoonZod native benchmark...');

  const args = ['run', 'cmd/main'];
  if (customJson) {
    args.push('--', customJson);
  }

  const stdout = execFileSync('moon', args, {
    cwd: PROJECT_ROOT,
    timeout: 120_000,
    stdio: ['ignore', 'pipe', 'pipe'],
    encoding: 'utf-8',
  });

  const lines = stdout.trim().split('\n');
  // Find the line that starts with "JSON:" for machine-readable output
  const jsonLine = lines.find(line => line.startsWith('JSON:'));
  const results = jsonLine ? JSON.parse(jsonLine.substring(5)) : null;

  return {
    name: 'MoonZod (native)',
    available: true,
    results,
  };
}

module.exports = { run };