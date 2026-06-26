/**
 * Zod Validator Benchmark
 *
 * Loads test data and runs Zod validation benchmark.
 */

const { performance } = require('perf_hooks');

let z;
try {
  z = require('zod');
} catch {
  console.warn('⚠  zod not installed. Run: npm install\n');
}

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

function run(data, iterations) {
  const schema = buildZodSchema();
  if (!schema) {
    return { name: 'TS Zod', available: false };
  }

  // Warm-up
  for (let i = 0; i < 100; i++) schema.parse(data);

  const start = performance.now();
  for (let i = 0; i < iterations; i++) {
    schema.parse(data);
  }
  const elapsed = performance.now() - start;

  const opsPerSec = (iterations / elapsed) * 1000;

  return {
    name: 'TS Zod',
    available: true,
    elapsed,
    opsPerSec,
  };
}

module.exports = { run, buildZodSchema };