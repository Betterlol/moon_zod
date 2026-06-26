#!/usr/bin/env node

/**
 * Cross-Language Benchmark Runner
 *
 * Compares validators side-by-side:
 *   - TypeScript Zod (in-process)
 *   - MoonZod (native via @bench library)
 *
 * Run: node bench.js
 *       npm run bench
 */

const path = require('path');
const fs = require('fs');

const ITERATIONS = 100_000;
const BENCH_DIR = path.resolve(__dirname);
const PROJECT_ROOT = path.resolve(BENCH_DIR, '..');

const testData = JSON.parse(
  fs.readFileSync(path.join(BENCH_DIR, 'test_data.json'), 'utf-8')
);

const zodBench = require('./validators/zod');
const moonZodBench = require('./validators/moon_zod');

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
  const zodResult = zodBench.run(testData, ITERATIONS);

  if (zodResult.available) {
    console.log(
      '  ✔  Zod          :',
      fmtNum(zodResult.elapsed),
      'ms  (' + fmtOps(zodResult.opsPerSec) + ' ops/sec)',
    );
  } else {
    console.log('  ⚠  Zod          : skipped (zod not installed)');
  }

  // ── MoonZod native benchmark ───────────────────────────────────
  console.log();
  const mzResult = moonZodBench.run(JSON.stringify(testData));

  if (mzResult.available && mzResult.results) {
    console.log();
    console.log('─'.repeat(60));
    console.log('  MoonZod @bench Results (calibrated ns/op)');
    console.log('─'.repeat(60));
    for (const b of mzResult.results) {
      const nsPerOp = (b.mean / b.batch_size) * 1e6;
      const opsPerSec = (b.batch_size / b.mean) * 1000;
      console.log(
        `  ${b.name.padEnd(26)} ${fmtNum(nsPerOp).padStart(10)} ns/op  ${fmtOps(opsPerSec).padStart(12)} ops/sec`,
      );
    }
  }

  // ── Summary comparison ─────────────────────────────────────────
  console.log();
  console.log('─'.repeat(60));
  console.log('  Summary Comparison (ops/sec)');
  console.log('─'.repeat(60));

  if (zodResult.available) {
    console.log(
      `  ${'TS Zod'.padEnd(26)} ${fmtOps(zodResult.opsPerSec).padStart(14)} ops/sec`,
    );
  }

  if (mzResult.available && mzResult.results) {
    const validBench = mzResult.results.find((b) => b.name === 'Valid Throughput');
    if (validBench) {
      const mzOpsPerSec = (validBench.batch_size / validBench.mean) * 1000;
      console.log(
        `  ${'MoonZod (native)'.padEnd(26)} ${fmtOps(mzOpsPerSec).padStart(14)} ops/sec`,
      );

      if (zodResult.available) {
        const ratio = (mzOpsPerSec / zodResult.opsPerSec).toFixed(1);
        console.log();
        console.log(`  MoonZod is ${ratio}x faster than TS Zod`);
      }
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