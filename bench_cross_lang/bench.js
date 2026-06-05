#!/usr/bin/env node

/**
 * Cross-Language Benchmark Runner
 *
 * Compares three validators side-by-side:
 *   1. TypeScript Zod (in-process)
 *   2. MoonZod (Wasm) via moonrun
 *   3. Handcrafted Match (Wasm) via moonrun
 *
 * Run: node bench.js
 *       npm run bench
 */

const { performance } = require('perf_hooks');
const { execFileSync } = require('child_process');
const path = require('path');
const fs = require('fs');

// ── Configuration ─────────────────────────────────────────────────
const ITERATIONS = 100_000;
const PROJECT_ROOT = path.resolve(__dirname, '..');
const WASM_PATH = path.join(
  PROJECT_ROOT,
  '_build/wasm/release/build/cmd/wasm/wasm.wasm',
);
const MOONRUN_PATH = path.join(
  PROJECT_ROOT,
  '..',
  '..',
  '..',
  '.moon/bin/moonrun',
);

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

// ── Benchmark: Wasm via moonrun ───────────────────────────────────
function benchWasm(mode) {
  const start = performance.now();
  try {
    execFileSync(MOONRUN_PATH, [WASM_PATH, mode], {
      cwd: PROJECT_ROOT,
      timeout: 120_000,
      stdio: ['ignore', 'pipe', 'pipe'],
    });
  } catch (e) {
    // If moonrun fails, try alternative wasm runtime
    tryFallback(mode);
  }
  const elapsed = performance.now() - start;
  return elapsed;
}

// ── Fallback: try existing wasm file with Node WASI ───────────────
function tryFallback(mode) {
  // Check if a wasm-gc debug file exists
  const gcPath = path.join(
    PROJECT_ROOT,
    '_build/wasm-gc/debug/build/cmd/wasm/wasm.wasm',
  );
  if (fs.existsSync(gcPath)) {
    const wasi = getWASI();
    if (wasi) {
      return runWASI(gcPath, wasi, mode);
    }
  }
  console.error(
    '✘  Could not run Wasm benchmark. Ensure moonrun is available.',
  );
  console.error('   Tried:', MOONRUN_PATH);
  process.exit(1);
}

// ── Helper: get WASI instance ──────────────────────────────────────
function getWASI() {
  try {
    const { WASI } = require('wasi');
    return WASI;
  } catch {
    return null;
  }
}

// ── Run wasm directly with Node WASI (timed) ───────────────────────
function runWASI(wasmPath, WASI, mode) {
  const wasmBuffer = fs.readFileSync(wasmPath);
  const wasi = new WASI({
    version: 'unstable',
    args: ['wasm', mode],
    env: {},
    preopens: {},
    returnOnExit: true,
  });

  return new Promise((resolve, reject) => {
    WebAssembly.instantiate(wasmBuffer, {
      wasi_snapshot_preview1: wasi.wasiImport,
    })
      .then(({ instance }) => {
        try {
          wasi.start(instance);
          resolve();
        } catch (e) {
          // WASI start throws on exit — that's expected
          resolve();
        }
      })
      .catch(reject);
  });
}

// ── Discover export functions from wasm module (for auto-detect) ──
function discoverWasmExports(wasmPath) {
  try {
    const buf = fs.readFileSync(wasmPath);
    const mod = new WebAssembly.Module(buf);
    return WebAssembly.Module.exports(mod).map((e) => e.name);
  } catch {
    return [];
  }
}

// ── Format helpers ────────────────────────────────────────────────
function fmtNum(n) {
  return n.toLocaleString('en-US', { maximumFractionDigits: 1 });
}

function fmtOps(ms) {
  const opsPerSec = (ITERATIONS / ms) * 1000;
  return opsPerSec.toLocaleString('en-US', { maximumFractionDigits: 0 });
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
    console.log('  ✔  Zod          :', fmtNum(zodMs), 'ms  (' + fmtOps(zodMs) + ' ops/sec)');
  } else {
    console.log('  ⚠  Zod          : skipped (zod not installed)');
  }

  // ── Wasm export discovery ───────────────────────────────────────
  console.log();
  if (fs.existsSync(WASM_PATH)) {
    const exports = discoverWasmExports(WASM_PATH);
    console.log('  Wasm exports    :', exports.length === 0 ? '(only _start)' : exports.join(', '));
    console.log('  Wasm file       :', path.relative(PROJECT_ROOT, WASM_PATH));
  } else {
    console.log('  Wasm file not found:', WASM_PATH);
    console.log('  Run: moon build --target wasm --release');
  }
  console.log();

  // ── Startup overhead measurement ────────────────────────────────
  console.log('  Measuring Wasm startup overhead...');
  const startupMs = benchWasm('startup');
  console.log('  ✔  Startup (no-op):', fmtNum(startupMs), 'ms');
  console.log();

  // ── MoonZod Wasm benchmark ──────────────────────────────────────
  console.log('  Running MoonZod Wasm benchmark...');
  const mzRaw = benchWasm('moonzod');
  const mzMs = Math.max(mzRaw - startupMs, 1);
  console.log('  ✔  MoonZod (Wasm):', fmtNum(mzRaw), 'ms raw,');

  // ── Handcrafted Wasm benchmark ──────────────────────────────────
  console.log('  Running Handcrafted Wasm benchmark...');
  const hcRaw = benchWasm('handcrafted');
  const hcMs = Math.max(hcRaw - startupMs, 1);
  console.log('  ✔  Handcrafted   :', fmtNum(hcRaw), 'ms raw');

  // ── Summary ─────────────────────────────────────────────────────
  console.log();
  console.log('─'.repeat(60));
  console.log('  Summary (', ITERATIONS.toLocaleString(), ' iterations each )');
  console.log('  (Wasm times adjusted: raw minus', fmtNum(startupMs), 'ms startup)');
  console.log('─'.repeat(60));

  if (zodMs !== null) {
    console.log(
      `  ${'TS Zod'.padEnd(22)} ${fmtNum(zodMs).padStart(8)} ms  ${fmtOps(zodMs).padStart(12)} ops/sec`,
    );
  }
  console.log(
    `  ${'MoonZod (Wasm)'.padEnd(22)} ${fmtNum(mzMs).padStart(8)} ms  ${fmtOps(mzMs).padStart(12)} ops/sec  (raw: ${fmtNum(mzRaw)} ms)`,
  );
  console.log(
    `  ${'Handcrafted (Wasm)'.padEnd(22)} ${fmtNum(hcMs).padStart(8)} ms  ${fmtOps(hcMs).padStart(12)} ops/sec  (raw: ${fmtNum(hcRaw)} ms)`,
  );

  if (zodMs !== null) {
    const ratio = (zodMs / mzMs).toFixed(2);
    const rel = parseFloat(ratio) > 1 ? 'faster' : 'slower';
    console.log();
    console.log(`  MoonZod is ${ratio}x ${rel} than TS Zod (after startup adjustment)`);
  }
  console.log();
  console.log('  Notes:');
  console.log('  - TS Zod runs in-process (V8). No startup overhead.');
  console.log('  - Wasm benchmarks include moonrun process + module instantiation.');
  console.log('  - Adjusted = raw - startup, isolating pure validation time.');
  console.log('  - Mutable Path Stack (Phase 5) enables zero-string');
  console.log('    allocation on the validation success path.');
  console.log('─'.repeat(60));
}

main();
