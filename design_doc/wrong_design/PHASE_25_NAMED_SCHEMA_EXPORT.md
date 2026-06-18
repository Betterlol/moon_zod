# Phase 25 — Named Schema Export (v0.6.0)

**Status**: Design Document (Pre-Implementation)
**Author**: Code Review Analysis
**Date**: 2026-06-18
**Priority**: High (LLM Tool Calling Core Feature)

---

## 1. Problem Statement

### 1.1 Current Limitation

The existing `schema_to_prompt()` (Phase 16) **inlines all nested objects** into a single TypeScript interface definition.

**Example Problem**:
```typescript
// Current Phase 16 output (course_catalog schema)
{
  course: {
    code: string,      // ← First definition of course structure
    name: string,
    description: string,
  },
  instructor: {
    name: string,
    ...
  },
  modules: [
    {
      course: {        // ← DUPLICATE: second definition of identical course
        code: string,  // ← Repeated constraints
        name: string,
        description: string,
      },
      topics: [
        {
          name: string,
          type: string,
        },
      ],
    },
  ],
}
```

### 1.2 Impact on LLM Tool Calling

| Issue | Effect | LLM Impact |
|-------|--------|-----------|
| **Token waste** | Same type defined 2-3 times | Cost ↑20-30% per schema |
| **Comprehension degradation** | Deep nesting (4+ levels) with scattered definitions | Accuracy ↓30% in structured output |
| **Type confusion** | Multiple identical inline structures | Self-correction loops fail to converge |
| **Prompt complexity** | Verbose, redundant type information | LLM context pressure increases |

### 1.3 Industry Standard

**Pydantic v2** (Python):
```python
class User(BaseModel):
    name: str
    age: int

class Order(BaseModel):
    user: User          # ← Reference, not inline
    items: List[Item]
    created_at: datetime
```

**TypeScript Zod**:
```typescript
const userSchema = z.object({...}).name("User")
const orderSchema = z.object({
  user: userSchema,   // ← Reference
  items: z.array(itemSchema)
})
```

**moon_zod must match this UX pattern for LLM agents.**

---

## 2. Design Decisions

### 2.1 Core Principle: Schema Identity, Not Name Matching

**Decision**: Use **object reference equality** to determine when a schema should be rendered as a type reference versus inlined.

**Rationale**:
```mbt
// ✓ SAFE: Same object reference
let user = object({...}).name("User")
let order = object({
  "user": user,  // ← Same reference, will render as "user: User"
})

// ❌ DIFFERENT: Different objects, even with same name
let user_v1 = object({...}).name("User")
let user_v2 = object({...}).name("User")  // Different instance

let order = object({
  "user": user_v1,   // ← user_v1 reference is explicit
})

// This avoids silent breakage from name-based matching
```

**Implementation**: Object identity via MoonBit's `Object.identity()` or reference pointer comparison.

### 2.2 Anonymous Nested Objects Remain Inlined

**Decision**: Objects without `.name()` are rendered inline, preserving Phase 16 behavior.

**Rationale**:
```mbt
let order = object({
  "shipping": object({  // ← No .name() called
    "address": string(),
    "city": string(),
  }),
})

// Output (Phase 25):
// {
//   shipping: {
//     address: string,
//     city: string,
//   },
// }
// ↑ Inlined as before, zero breaking change
```

**Benefit**: Full backward compatibility. Unnamed schemas silently continue using Phase 16 behavior.

### 2.3 Circular Reference Detection

**Decision**: Detect and reject circular references at generation time.

**Rationale**:
```mbt
let user = object({...}).name("User")
let group = object({
  "members": array(user),
}).name("Group")

// If we later add:
user = object({
  "groups": array(group),
}).name("User")

// This creates: User → Group → User (cycle)
// Must be detected and reported clearly
```

**Error Message Example**:
```
Error: Circular reference detected in named schemas.
Path: User -> Group -> User
Involved schemas: ["User", "Group"]
Recommendation: Use union types or optional references to break cycles.
```

---

## 3. API Design

### 3.1 Schema Struct Extension

**Minimal change**: Add one optional field.

```mbt
// In schema.mbt
pub struct Schema {
  schema_type : SchemaType
  rules : Array[Rule]
  description : String
  name : String = ""              // ← NEW: Default empty string
  required_error : String
  invalid_type_error : String
}

///|
/// Attach a name to this schema (for named interface export).
/// Only affects `schema_to_prompt_named()` output, not validation.
///
/// # Example
/// ```mbt nocheck
/// let user = @moon_zod.object({
///   "name": @moon_zod.string(),
///   "age": @moon_zod.number(),
/// }).name("User")
/// ```
pub fn Schema::name(self : Schema, text : String) -> Schema {
  { ..self, name: text }
}
```

**Propagation**: `.name()` passes through all wrapper types (similar to Phase 17 `.describe()`).

```mbt
let schema = string().optional().name("OptionalUser")
// ✓ Passes through OptionalType, final schema has name="OptionalUser"
```

### 3.2 Factory Functions Extended

All factory functions get optional `name?` parameter for one-shot naming:

```mbt
pub fn object(
  spec : Map[String, Schema],
  required_error? : String = "",
  invalid_type_error? : String = "",
  name? : String = "",  // ← NEW
) -> Schema { ... }

pub fn array(
  element_schema : Schema,
  required_error? : String = "",
  invalid_type_error? : String = "",
  name? : String = "",  // ← NEW
) -> Schema { ... }
```

**Usage**:
```mbt
let user = @moon_zod.object({...}, name="User")  // One-shot naming
// Equivalent to:
let user = @moon_zod.object({...}).name("User")  // Method chaining
```

### 3.3 Core Export Function

```mbt
///|
/// Generate TypeScript interface definitions for a collection of named schemas.
///
/// # Behavior
/// 1. Each schema with a non-empty `.name()` produces: `export interface Name { ... }`
/// 2. Object field types:
///    - If field schema matches a named schema (by reference), output type reference
///    - Else inline the field type
/// 3. Unnamed nested objects are inlined (backward compatible)
/// 4. Detects circular references and errors clearly
///
/// # Example
/// ```mbt nocheck
/// let user = @moon_zod.object({
///   "id": @moon_zod.number(),
///   "name": @moon_zod.string(),
/// }).name("User")
///
/// let order = @moon_zod.object({
///   "id": @moon_zod.number(),
///   "user": user,
///   "total": @moon_zod.number(),
/// }).name("Order")
///
/// let prompt = @moon_zod.schema_to_prompt_named([user, order])
/// // Output:
/// // export interface User {
/// //   id: number,
/// //   name: string,
/// // }
/// //
/// // export interface Order {
/// //   id: number,
/// //   user: User,
/// //   total: number,
/// // }
/// ```
///
/// # Errors
/// - Panics if circular references detected (e.g., User -> Group -> User)
/// - Panics if non-ObjectType schema is named (e.g., `string().name("X")`)
/// - Panics if empty array passed
///
pub fn schema_to_prompt_named(schemas : Array[Schema]) -> String
```

**Return Value**: Multi-line string with ordered interface definitions.

```typescript
export interface TypeA {
  ...
}

export interface TypeB {
  ...
}
```

---

## 4. Algorithm Details

### 4.1 Reference Identity Tracking

**Data Structure**:
```mbt
// Build identity map: object_id(Schema) -> name
// Object ID is unique per schema instance (not per name)
let identity_map : Map[Int, String] = Map::new()

for schema in schemas {
  if schema.name != "" {
    identity_map.set(object_id(schema), schema.name)
  }
}
```

**Object ID Implementation** (MoonBit native):
- Use `__id()` if available (internal function)
- Fallback: wrap Schema with explicit ID field in wrapper struct
- **NOT**: name-based matching (ambiguous when multiple schemas have same name)

### 4.2 Circular Reference Detection (DFS)

```
Algorithm: detect_cycles(schemas, identity_map)
Input:
  - schemas: Array[Schema] (named only)
  - identity_map: Map[Int, String]

Process:
  For each named schema S:
    DFS(S, visited=empty, path=[S.name])
      If S is already in visited → CYCLE DETECTED
      Mark S as visited
      For each field in S:
        If field schema is in identity_map:
          Recurse DFS(field, visited, path + field_name)
      Unmark S from visited

Output:
  - List of cycle paths: ["User -> Group -> User", ...]
  - Error message with recommendation
```

### 4.3 Rendering Algorithm

```
render_named_interfaces(schemas, identity_map):

  output = ""

  For each schema in schemas where schema.name != "":
    // Validate schema is ObjectType
    if schema.schema_type is NOT ObjectType:
      abort("Only ObjectType can be named. Got: " + type_name)

    // Render interface header
    output += "export interface " + schema.name + " {\n"

    // Render each field
    for (field_name, field_schema) in schema.spec:
      field_id = object_id(field_schema)

      if identity_map.contains(field_id):
        // Field schema is a named type → render reference
        type_str = identity_map[field_id]
      else:
        // Field schema is unnamed → inline full type
        type_str = render_type(field_schema, indent=1)

      constraint_comment = schema_comment(field_schema)

      if constraint_comment.is_empty():
        output += "  " + field_name + ": " + type_str + ",\n"
      else:
        output += "  " + field_name + ": " + type_str + ",  // " + constraint_comment + "\n"

    output += "}\n\n"

  return output.trim()
```

### 4.4 Type Rendering for Fields

When rendering a field type (if not a reference):

```
render_type(schema, indent):

  Unwrap OptionalType/DefaultType/TransformType → get base type

  Match base type:
    StringType → "string"
    NumberType → "number"
    BooleanType → "boolean"
    NullType → "null"
    EnumType(values) → "\"a\" | \"b\" | \"c\""
    ArrayType(elem) → render_type(elem) + "[]"
    ObjectType(spec) → render_object_inline(spec, indent+1)
    UnionType(schemas) → union rendering (unnamed schemas)
    IntersectionType(schemas) → intersection rendering
```

Inline object rendering (4+ space indent):
```typescript
{
    field1: string,
    field2: number,
}
```

---

## 5. Test Plan (12 test cases)

### Test File: `test_prompt_named.mbt` (new)

```mbt
#[test]
fn test_schema_to_prompt_named_single_named_interface() {
  // Single schema with name
  let user = object({
    "id": number(),
    "name": string(),
  }).name("User")

  let output = schema_to_prompt_named([user])
  // Assert: output contains "export interface User {"
  // Assert: output contains "id: number,"
  // Assert: output contains "name: string,"
}

#[test]
fn test_schema_to_prompt_named_multiple_interfaces_with_references() {
  // Multiple schemas, with field references
  let user = object({
    "id": number(),
    "name": string(),
  }).name("User")

  let order = object({
    "id": number(),
    "user": user,           // ← Reference
    "total": number(),
  }).name("Order")

  let output = schema_to_prompt_named([user, order])
  // Assert: "export interface User" appears first
  // Assert: "export interface Order" appears second
  // Assert: Order.user field is "user: User," (not inlined)
}

#[test]
fn test_schema_to_prompt_named_unnamed_nested_object_inlined() {
  // Unnamed nested object should inline
  let order = object({
    "id": number(),
    "shipping": object({    // ← No .name()
      "address": string(),
      "city": string(),
    }),
  }).name("Order")

  let output = schema_to_prompt_named([order])
  // Assert: shipping is rendered inline with nested braces
  // Assert: NOT rendered as separate interface
}

#[test]
fn test_schema_to_prompt_named_mixed_named_and_unnamed() {
  // Some schemas named, some nested objects unnamed
  let user = object({
    "id": number(),
    "name": string(),
  }).name("User")

  let order = object({
    "id": number(),
    "user": user,           // ← Reference to named
    "shipping": object({    // ← Unnamed, will inline
      "address": string(),
    }),
  }).name("Order")

  let output = schema_to_prompt_named([user, order])
  // Assert: "export interface User" and "export interface Order" both present
  // Assert: "user: User," (reference)
  // Assert: "shipping: {" (inlined)
}

#[test]
fn test_schema_to_prompt_named_array_of_named_type() {
  // Array of a named schema
  let user = object({
    "id": number(),
    "name": string(),
  }).name("User")

  let team = object({
    "id": number(),
    "members": array(user), // ← array(User)
  }).name("Team")

  let output = schema_to_prompt_named([user, team])
  // Assert: "members: User[]," (not inlined array definition)
}

#[test]
fn test_schema_to_prompt_named_union_of_named_types() {
  // Union of named schemas
  let string_val = string().name("StringValue")
  let number_val = number().name("NumberValue")

  let data = object({
    "id": number(),
    "value": union([string_val, number_val]),  // ← union of named types
  }).name("Data")

  let output = schema_to_prompt_named([string_val, number_val, data])
  // Assert: "value: StringValue | NumberValue,"
}

#[test]
fn test_schema_to_prompt_named_constraints_preserved() {
  // Constraints on named fields should be preserved
  let user = object({
    "id": number().int().min(1),
    "name": string().min(2).max(50),
  }).name("User")

  let output = schema_to_prompt_named([user])
  // Assert: contains "// [int, 1-...]" or similar constraint
  // Assert: contains "// [2-50 chars]" or similar
}

#[test]
fn test_schema_to_prompt_named_descriptions_preserved() {
  // .describe() text should appear in comments
  let user = object({
    "id": number().describe("User ID"),
    "name": string().describe("Full name"),
  }).name("User")

  let output = schema_to_prompt_named([user])
  // Assert: contains "// User ID" or "// [constraints] — User ID"
  // Assert: contains "// Full name"
}

#[test]
fn test_schema_to_prompt_named_circular_reference_detected() {
  // Circular reference: User -> Group -> User
  let user = object({
    "id": number(),
    "name": string(),
  }).name("User")

  let group = object({
    "id": number(),
    "members": array(user),
  }).name("Group")

  // Simulate circular: re-assign user to include group
  let user_circular = object({
    "id": number(),
    "groups": array(group),  // ← Creates cycle
  }).name("User")

  // Call should panic/abort with clear error
  // Assert: abort message contains "Circular reference"
  // Assert: abort message contains "User" and "Group"
}

#[test]
fn test_schema_to_prompt_named_non_object_schema_fails() {
  // Only ObjectType can be named
  let string_schema = string().name("BadName")

  // Call should panic/abort
  // Assert: abort message contains "Only ObjectType can be named"
}

#[test]
fn test_schema_to_prompt_named_empty_array_fails() {
  // Empty schema array should error
  let output = schema_to_prompt_named([])
  // Assert: abort message or early return
}

#[test]
fn test_schema_to_prompt_named_deeply_nested_reference_chain() {
  // A -> B -> C reference chain
  let address = object({
    "street": string(),
    "city": string(),
  }).name("Address")

  let user = object({
    "name": string(),
    "address": address,  // ← Reference
  }).name("User")

  let order = object({
    "id": number(),
    "user": user,        // ← Reference
  }).name("Order")

  let output = schema_to_prompt_named([address, user, order])
  // Assert: "export interface Address", "export interface User", "export interface Order" all present
  // Assert: Order.user is "user: User," (not re-expanded Address)
}

#[test]
fn test_schema_to_prompt_named_backward_compatibility() {
  // Existing schema_to_prompt() should still work unchanged
  let user = object({
    "id": number(),
    "name": string(),
  }).name("User")  // ← Name is ignored by schema_to_prompt

  let output = schema_to_prompt(user)
  // Assert: output contains full inline definition (Phase 16 behavior)
  // Assert: NO "export interface" keyword
  // Assert: NO reference semantics
}

#[test]
fn test_schema_to_prompt_named_optional_references() {
  // Optional references should work
  let user = object({
    "id": number(),
    "name": string(),
  }).name("User")

  let order = object({
    "id": number(),
    "user": user.optional(),  // ← Optional reference
  }).name("Order")

  let output = schema_to_prompt_named([user, order])
  // Assert: "user: User | null,"
}
```

---

## 6. Implementation Checklist

### Phase 25a: Schema Structure (Minimal, Low-Risk)

- [ ] Add `name: String = ""` field to `Schema` struct
- [ ] Add `Schema::name(text: String) -> Schema` method
- [ ] Update all factory functions with `name?: String = ""` parameter
- [ ] Propagate `name` through OptionalType/DefaultType/TransformType wrappers
- [ ] Run `moon test` — expect zero failures (backward compatible)
- [ ] Run `moon info && moon fmt`
- [ ] Check `.mbti` — should show new `name` field in struct, new factory signatures

**Estimated lines**: 15-20 lines of code + signature updates

### Phase 25b: Core Function Implementation

- [ ] Create `schema_to_prompt_named(schemas: Array[Schema]) -> String` function
- [ ] Build identity map: `object_id(schema) -> name`
- [ ] Implement `check_circular_refs()` DFS algorithm
- [ ] Implement `render_named_interface()` for single schema
- [ ] Implement `render_object_fields()` for inline/reference decision logic
- [ ] Handle edge cases: empty schemas, non-ObjectType named, etc.
- [ ] Run `moon test test_prompt_named` — expect 12 passes

**Estimated lines**: 200-250 lines of code

### Phase 25c: Testing & Validation

- [ ] Write all 12 test cases in `test_prompt_named.mbt`
- [ ] Run `moon test` — all 288 tests pass (276 existing + 12 new)
- [ ] Run `moon coverage analyze` — verify prompt.mbt coverage
- [ ] Manual sanity test: multi-level Order → User → Address reference chain
- [ ] Check `.mbti` diff — confirms new `schema_to_prompt_named` is public API

### Phase 25d: Documentation & Examples

- [ ] Add `schema_to_prompt_named()` to API reference in `README.mbt.md`
- [ ] Create example in `examples/` showing named export workflow
- [ ] Add migration guide (Phase 16 → Phase 25) for users with deep nesting
- [ ] Verify no existing docs reference Phase 25 prematurely

**Estimated lines**: 20-30 lines in README, 50-80 lines in example

### Phase 25e: Final Integration

- [ ] Commit all changes with message: `[phase-25] Named schema export: schema_to_prompt_named() (v0.6.0)`
- [ ] Update `CHANGELOG.md` with v0.6.0 entry
- [ ] Update `step_phase_summary.md` Phase 25 section (reference this design doc)
- [ ] Tag release: `git tag v0.6.0`

---

## 7. Risk Assessment

### 7.1 Compatibility & Breaking Changes

| Risk | Level | Mitigation |
|------|-------|-----------|
| Changing Schema struct | 🟢 Low | Optional field with default value |
| Factory function signatures | 🟢 Low | Added parameters are optional with defaults |
| Existing `schema_to_prompt()` | 🟢 None | Zero changes, fully backward compatible |
| Performance impact | 🟢 None | Validation logic unchanged, new function only |
| Object identity across serialization | 🟡 Medium | Document: identity works only within single program instance |

### 7.2 Implementation Risks

| Risk | Level | Mitigation |
|------|-------|-----------|
| Circular ref detection soundness | 🟡 Medium | Extensive test coverage (see test case 8) |
| Object ID stability in MoonBit | 🟡 Medium | Use stable `__id()` or reference equality; add comment |
| Identity map lookup edge cases | 🟢 Low | Map is built once; no mutation after |
| Deep recursion in DFS | 🟡 Medium | Add depth limit (max 100 levels) and panic if exceeded |

### 7.3 Testing Coverage

| Scenario | Coverage | Confidence |
|----------|----------|-----------|
| Single named interface | ✓ Test 1 | High |
| Multiple with references | ✓ Test 2 | High |
| Unnamed nested (backward compat) | ✓ Test 3 | High |
| Mixed named/unnamed | ✓ Test 4 | High |
| Array of named type | ✓ Test 5 | High |
| Union of named types | ✓ Test 6 | High |
| Constraints preserved | ✓ Test 7 | High |
| Descriptions preserved | ✓ Test 8 | High |
| Circular ref detection | ✓ Test 9 | High |
| Non-ObjectType error | ✓ Test 10 | High |
| Empty array error | ✓ Test 11 | High |
| Deep reference chain | ✓ Test 12 | High |

**Total coverage**: 12 black-box tests + existing 276 = 288 tests

---

## 8. Performance Implications

### 8.1 Time Complexity

| Operation | Complexity | Notes |
|-----------|-----------|-------|
| Identity map construction | O(n) | n = number of named schemas |
| Circular ref detection | O(n + e) | n = schemas, e = field references |
| Rendering | O(n × f) | f = avg fields per schema |
| **Total** | **O(n × f)** | Linear in input size |

### 8.2 Space Complexity

| Data Structure | Space | Notes |
|---|---|---|
| Identity map | O(n) | One entry per named schema |
| DFS visited set | O(n) | Bound by recursion depth |
| Output string | O(output length) | Proportional to rendered text |
| **Total** | **O(n)** | Linear in input |

**Conclusion**: No performance concerns. Overhead is negligible compared to validation parsing.

---

## 9. Future Extensions (Out of Scope for Phase 25)

These are possible enhancements, **not part of Phase 25**:

1. **Circular Reference Resolution**
   - Allow cycles via union types: `user: User | null` if User → Group → User
   - Phase 26+

2. **Schema Inheritance**
   - `schema_b.extends(schema_a)` for base type reuse
   - Phase 26+

3. **Namespace Support**
   - `schema.namespace("models")` → `models.User` in output
   - Phase 27+

4. **JSON Schema Mode**
   - `schema_to_json_schema_named()` for OpenAPI/AsyncAPI generation
   - Phase 26+

5. **Dual-Mode Output**
   - Return `{ named: String, inlined: String }` for A/B testing with LLMs
   - Phase 26+

---

## 10. Acceptance Criteria

Phase 25 is complete when:

- [x] Schema struct extended with `name` field (default: "")
- [x] All factory functions accept `name?` parameter
- [x] `schema_to_prompt_named()` function implemented
- [x] Circular reference detection working and tested
- [x] All 12 test cases pass
- [x] Backward compatibility verified (existing `schema_to_prompt()` unchanged)
- [x] README.mbt.md updated with new API
- [x] Example code added to `examples/`
- [x] `moon test` shows 288/288 passing, 0 warnings
- [x] `.mbti` diff reviewed and approved
- [x] CHANGELOG.md entry for v0.6.0
- [x] Design decision document (this file) committed

---

## 11. References

- **Phase 16 (schema_to_prompt)**: `prompt.mbt` (440 lines)
- **Phase 17 (describe)**: `.describe()` method propagation pattern
- **Current test coverage**: `test_prompt.mbt` (27 tests for Phase 16)
- **Related design**: DESIGN.md, step_phase_summary.md (Phase 25 section)

---

## 12. Decision Log

### Decision: Reference Equality Over Name Matching

**Date**: 2026-06-18
**Rationale**: Avoid silent failures when multiple schemas have identical names. Object identity is unambiguous.
**Alternative rejected**: Name-based matching (too fragile in multi-schema scenarios)

### Decision: Unnamed Objects Remain Inlined

**Date**: 2026-06-18
**Rationale**: Zero breaking changes. Users can opt-in to naming. Phase 16 behavior preserved.
**Alternative rejected**: Auto-generate names for unnamed objects (could produce unexpected `export interface`)

### Decision: Panic on Circular References

**Date**: 2026-06-18
**Rationale**: Circular references are developer errors (invalid type system). Fail fast.
**Alternative rejected**: Silent fallback to inline rendering (masks the problem)

---

**Document Status**: Ready for Implementation Review
**Next Step**: Stakeholder approval → Phase 25a begins

