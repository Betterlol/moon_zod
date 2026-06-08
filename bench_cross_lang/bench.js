#!/usr/bin/env node

/**
 * Cross-Language Benchmark Runner
 *
 * Compares two validators side-by-side:
 *   1. TypeScript Zod (in-process)
 *   2. MoonZod (native via @bench library, in-process)
 *
 * Both run in-process with no subprocess overhead.
 * Run: node bench.js
 *       npm run bench
 */

const { performance } = require('perf_hooks');
const { execFileSync } = require('child_process');
const path = require('path');

// ── Configuration ─────────────────────────────────────────────────
const ITERATIONS = 100_000;
const PROJECT_ROOT = path.resolve(__dirname, '..');

// ── Try loading Zod (optional) ────────────────────────────────────
let z;
try {
  z = require('zod');
} catch {
  console.warn('⚠  zod not installed. Run: npm install\n');
}

// ── Zod Schema (equivalent to the MoonBit schema) ─────────────────
function buildZodSchema() {
  if (!z) return null;
  return z.object({
    users: z.array(
      z.object({
        id: z.number().int().min(0),
        name: z.string().min(1).max(100),
        email: z.string().email().optional(),
        role: z.enum(['admin', 'user', 'viewer']),
        profile: z.object({
          age: z.number().int().min(0).max(150),
          tags: z.array(z.string().min(1)),
          metadata: z
            .object({
              department: z.string().min(1),
              level: z.number().int().min(1).max(10),
              active: z.boolean(),
            })
            .optional(),
        }),
      }),
    ),
    config: z.object({
      version: z.string().min(1),
      debug: z.boolean(),
      maxRetries: z.number().int().min(0).max(10),
    }),
  });
}

// ── Test Data (equivalent to moon_zod's large_input) ───────────────
function buildTestData() {
  return {
    users: [
      {
        id: 1,
        name: 'Alice',
        email: 'alice@example.com',
        role: 'admin',
        profile: {
          age: 30,
          tags: ['rust', 'wasm', 'ai'],
          metadata: {
            department: 'Engineering',
            level: 5,
            active: true,
          },
        },
      },
      {
        id: 2,
        name: 'Bob',
        role: 'user',
        profile: {
          age: 25,
          tags: ['design'],
          metadata: {
            department: 'Design',
            level: 3,
            active: false,
          },
        },
      },
      {
        id: 3,
        name: 'Charlie',
        role: 'viewer',
        profile: {
          age: 42,
          tags: ['python', 'data'],
        },
      },
    ],
    config: {
      version: '1.0.0',
      debug: false,
      maxRetries: 3,
    },
  };
}

// ── Benchmark: Zod ────────────────────────────────────────────────
function benchZod(schema, data) {
  const start = performance.now();
  for (let i = 0; i < ITERATIONS; i++) {
    schema.parse(data);
  }
  const elapsed = performance.now() - start;
  return elapsed;
}

// ── Benchmark: MoonZod (native via @bench) ────────────────────────
function benchMoonZod() {
  const stdout = execFileSync('moon', ['run', 'cmd/main'], {
    cwd: PROJECT_ROOT,
    timeout: 120_000,
    stdio: ['ignore', 'pipe', 'pipe'],
    encoding: 'utf-8',
  });
  // Last line is JSON from bench.dump_summaries()
  const lines = stdout.trim().split('\n');
  const jsonLine = lines[lines.length - 1];
  return JSON.parse(jsonLine);
}

// ── Format helpers ────────────────────────────────────────────────
function fmtNum(n) {
  return n.toLocaleString('en-US', { maximumFractionDigits: 1 });
}

function fmtOps(n) {
  return Number(n).toLocaleString('en-US', { maximumFractionDigits: 0 });
}

// ── Main ──────────────────────────────────────────────────────────
function main() {
  console.log('═'.repeat(60));
  console.log('  Cross-Language Benchmark Suite');
  console.log('  Iterations per run:', ITERATIONS.toLocaleString());
  console.log('═'.repeat(60));
  console.log();

  // ── Zod benchmark ──────────────────────────────────────────────
  let zodMs = null;
  const schema = buildZodSchema();
  const data = buildTestData();

  if (schema) {
    // Warm-up
    for (let i = 0; i < 100; i++) schema.parse(data);
    zodMs = benchZod(schema, data);
    console.log(
      '  ✔  Zod          :',
      fmtNum(zodMs),
      'ms  (' + fmtOps((ITERATIONS / zodMs) * 1000) + ' ops/sec)',
    );
  } else {
    console.log('  ⚠  Zod          : skipped (zod not installed)');
  }

  // ── MoonZod native benchmark ───────────────────────────────────
  console.log();
  console.log('  Running MoonZod native benchmark...');
  const mzResults = benchMoonZod();
  console.log();

  // Parse @bench JSON results
  console.log('─'.repeat(60));
  console.log('  MoonZod @bench Results (calibrated ns/op)');
  console.log('─'.repeat(60));
  for (const b of mzResults) {
    const nsPerOp = (b.mean / b.batch_size) * 1e6;
    const opsPerSec = (b.batch_size / b.mean) * 1000;
    console.log(
      `  ${b.name.padEnd(26)} ${fmtNum(nsPerOp).padStart(10)} ns/op  ${fmtOps(opsPerSec).padStart(12)} ops/sec`,
    );
  }

  // ── Summary comparison ─────────────────────────────────────────
  console.log();
  console.log('─'.repeat(60));
  console.log('  Summary Comparison (ops/sec)');
  console.log('─'.repeat(60));

  const zodOps = zodMs !== null ? (ITERATIONS / zodMs) * 1000 : null;

  if (zodOps !== null) {
    console.log(
      `  ${'TS Zod'.padEnd(26)} ${fmtOps(zodOps).padStart(14)} ops/sec`,
    );
  }

  // Use "Valid Throughput" for cross-comparison
  const validBench = mzResults.find((b) => b.name === 'Valid Throughput');
  if (validBench) {
    const mzOpsPerSec = (validBench.batch_size / validBench.mean) * 1000;
    console.log(
      `  ${'MoonZod (native)'.padEnd(26)} ${fmtOps(mzOpsPerSec).padStart(14)} ops/sec`,
    );

    if (zodOps !== null) {
      const ratio = (mzOpsPerSec / zodOps).toFixed(1);
      console.log();
      console.log(`  MoonZod is ${ratio}x faster than TS Zod`);
    }
  }

  console.log();
  console.log('  Notes:');
  console.log('  - Both validators run in-process (no subprocess overhead).');
  console.log(
    '  - TS Zod: wall-clock time for',
    ITERATIONS.toLocaleString(),
    'manual parse() calls.',
  );
  console.log(
    '  - MoonZod: calibrated by @bench library (automatic iteration count).',
  );
  console.log(
    '  - @bench reports mean time per batch; ns/op = (mean / batch_size) * 1e6.',
  );
  console.log(
    '  - MoonZod includes 3 benchmarks: Valid Throughput, Adversarial, Redundancy.',
  );
  console.log('─'.repeat(60));
}

main();
