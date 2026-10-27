// Run the pinned source checkout directly; no npm install or source edits.
import { registerHooks } from 'node:module';
import { readFileSync } from 'node:fs';
import { resolve } from 'node:path';
import { pathToFileURL } from 'node:url';

if (Number(process.versions.node.split('.')[0]) < 24) throw new Error('Node 24+ is required');
if (!process.argv[2]) throw new Error('Pass the Zod repository root');
const root = resolve(process.argv[2]);
const version = JSON.parse(readFileSync(resolve(root, 'packages/zod/package.json'), 'utf8')).version;
if (version !== '4.6.7') throw new Error(`Expected Zod 4.6.7, found ${version}`);
registerHooks({
  resolve(specifier, context, nextResolve) {
    try { return nextResolve(specifier, context); }
    catch (error) {
      if (error.code === 'ERR_MODULE_NOT_FOUND' && specifier.endsWith('.js')) {
        return nextResolve(specifier.slice(0, -3) + '.ts', context);
      }
      throw error;
    }
  },
});
const z = await import(pathToFileURL(resolve(root, 'packages/zod/src/v4/classic/external.ts')).href);
const cases = {};
function record(name, result, extra = {}) {
  if (Object.hasOwn(cases, name)) throw new Error(`Duplicate case ${name}`);
  cases[name] = result.success
    ? { success: true, data: result.data, ...extra }
    : { success: false, diagnostics: result.error.issues.map(({ code, path }) => ({ code, path })), ...extra };
}
const left = () => z.strictObject({ a: z.string() });
const right = () => z.strictObject({ b: z.string() });
const pair = { a: 'x', b: 'y' };
record('intersection.prefault-missing', z.intersection(left().prefault(pair), right().prefault(pair)).safeParse(undefined));
const intersectionDefaults = () => z.intersection(z.string().default('a'), z.string().default('a'));
record('intersection.defaults-required-field', z.object({ v: intersectionDefaults() }).safeParse({}));
record('intersection.defaults-outer-optional', z.object({ v: intersectionDefaults().optional() }).safeParse({}));
{
  let calls = 0;
  const field = z.tuple([z.string()]).refine(() => { calls++; return true; });
  const schema = z.object({ v: field }).refine(() => { calls++; return true; });
  record('tuple.overlong-callbacks', schema.safeParse({ v: ['a', 'b'] }), { calls });
}
record('intersection.strict', z.intersection(left(), right()).safeParse(pair));
record('intersection.unknown-keys', z.intersection(left(), right()).safeParse({ ...pair, c: 1, d: 2 }));
record('intersection.strict-strip', z.intersection(left(), z.object({ b: z.string() })).safeParse({ ...pair, c: 1 }));
record('intersection.nested-strict', z.intersection(z.object({ inner: z.strictObject({ a: z.string() }) }), z.object({ other: z.string() })).safeParse({ inner: { a: 'x', extra: 1 }, other: 'y' }));
{
  let calls = 0;
  const a = left().transform(v => { calls++; return v; }).pipe(z.object({ a: z.string().toUpperCase() }));
  const b = right().transform(v => { calls++; return v; });
  const result = z.intersection(a, b).safeParse(pair);
  record('intersection.effects', result, { calls });
}
{
  let calls = 0;
  const a = z.object({ inner: z.strictObject({ a: z.string() }) }).transform(v => { calls++; return v; });
  const result = z.intersection(a, z.object({ other: z.string() })).safeParse({ inner: { a: 'x', extra: 1 }, other: 'y' });
  record('intersection.nested-effects', result, { calls });
}
{
  let calls = 0;
  const a = left().refine(() => false, 'boom').transform(v => { calls++; return v; });
  const result = z.intersection(a, right()).safeParse(pair);
  record('intersection.refinement-blocks-transform', result, { calls });
}
{
  let calls = 0;
  const integer = z.number().int().refine(() => { calls++; return true; });
  const schema = z.object({ n: integer }).refine(() => { calls++; return true; });
  const result = schema.safeParse({ n: 1.5 });
  record('int.fractional-callbacks', result, { calls });
}
for (const [label, value] of [['positive', 9007199254740992], ['negative', -9007199254740992]]) {
  let calls = 0;
  const result = z.number().int().refine(() => { calls++; return true; }).safeParse(value);
  record(`int.unsafe-${label}-continuation`, result, { calls });
}
{
  const observed = [];
  const result = z.string().min(3).trim().refine(v => { observed.push(v); return false; }, 'later').safeParse(' x');
  record('effects.builtin-dirty-trim', result, { observed });
}
{
  let calls = 0;
  const result = z.string().min(3).transform(v => { calls++; return v; }).safeParse(' x');
  record('effects.custom-dirty-blocked', result, { calls });
}
const prefault = () => z.object({ a: z.string().min(3).prefault('x').optional() });
record('optional.invalid-prefault-absent', prefault().safeParse({}));
record('optional.invalid-prefault-present', prefault().safeParse({ a: 'x' }));
record('optional.valid-prefault', z.object({ a: z.string().min(3).prefault('abc').optional() }).safeParse({}));
{
  let calls = 0;
  const a = z.preprocess(v => { calls++; return v; }, z.string().default('fallback')).optional();
  const result = z.object({ a }).safeParse({});
  record('optional.preprocess-default', result, { calls });
}
const pipeDefault = () => z.string().optional().pipe(z.string().default('x'));
record('pipe.default-direct', z.object({ a: pipeDefault() }).safeParse({}));
record('pipe.default-outer-optional', z.object({ a: pipeDefault().optional() }).safeParse({}));
record('pipe.default-partial', z.object({ a: pipeDefault() }).partial().safeParse({}));
record('tuple.default', z.tuple([z.string().default('x')]).safeParse([]));
record('tuple.trailing-optional', z.tuple([z.string(), z.string().optional()]).safeParse(['a']));
record('tuple.minimum-prefix', z.tuple([z.string(), z.string().optional()]).safeParse([]));
record('tuple.overlong-invalid-element', z.tuple([z.string()]).safeParse([1, 2]));
record('unicode.lower', z.string().toLowerCase().safeParse('ÉCOLE ΣΊΣΥΦΟΣ İ ẞ 𐐀 Ꭰ'));
record('unicode.upper', z.string().toUpperCase().safeParse('straße ﬃ ǰ ΐ 𐐨 ꭰ'));
record('unicode.sigma-context', z.string().toLowerCase().safeParse("ΟΣ ΟΣΑ ΣΣ AΣ'A AΣ'! AΣ1A ⅠΣ"));
record('unicode.trim-whitespace', z.string().trim().safeParse('\ufeff\u00a0\u2028 x \u3000\u2029'));
record('unicode.trim-nonwhitespace', z.string().trim().safeParse('\u0085\u180e\u200b\u2060'));
record('datetime.minute-offset', z.string().datetime({ precision: -1, offset: true }).safeParse('2024-01-01T12:34+08:00'));
record('datetime.minute-reject-seconds', z.string().datetime({ precision: -1, offset: true }).safeParse('2024-01-01T12:34:00+08:00'));
record('datetime.zero-local-reject-minutes', z.string().datetime({ precision: 0, local: true }).safeParse('2024-01-01T12:34'));
record('datetime.zero-local-seconds', z.string().datetime({ precision: 0, local: true }).safeParse('2024-01-01T12:34:00'));
record('datetime.default-local-minutes', z.string().datetime({ local: true }).safeParse('2024-01-01T12:34'));
record('ulid.lower', z.string().ulid().safeParse('01arz3ndektsv4rrffq69g5fav'));
record('ulid.mixed', z.string().ulid().safeParse('01ArZ3nDeKtSv4rRfFq69g5FaV'));
record('ulid.invalid-alphabet', z.string().ulid().safeParse('01ARZ3NDEKTSV4RRFFQ69G5FAi'));
for (const io of ['input', 'output']) {
  const schema = z.toJSONSchema(z.number().int(), { io });
  const bounds = Object.fromEntries(['type', 'minimum', 'maximum'].map(key => [key, schema[key] ?? null]));
  record(`int.schema-${io}-bounds`, { success: true, data: bounds });
}
record('divergence.uri-profile', z.string().url().safeParse(' https://example.com '));
record('divergence.cuid-profile', z.string().cuid().safeParse('c123456'));
record('divergence.email-profile', z.string().email().safeParse("a'@example.com"));
record('divergence.exact-decimal-multiple', z.number().multipleOf(0.1).safeParse(0.30000000000000004));
{
  let calls = 0;
  const a = z.string().optional().transform(() => { calls++; return 'filled'; });
  const result = z.object({ a }).safeParse({});
  record('divergence.missing-json-callback', result, { calls });
}
for (const [name, value, count] of [['astral', '😀', 1], ['mixed', 'a😀b', 3], ['combining', 'e\u0301', 2], ['zwj', '🧑‍🍼', 3]]) {
  record(`unicode.length-${name}`, z.string().length(count).safeParse(value));
  record(`unicode.min-${name}`, z.string().min(count + 1).safeParse(value));
}
process.stdout.write(JSON.stringify({ version, cases }) + '\n');
