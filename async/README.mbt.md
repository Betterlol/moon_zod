# moon_zod async

`Betterlol/moon_zod/async` is an optional companion package. It leaves
`Betterlol/moon_zod/core` synchronous and dependency-light. The underlying
MoonBit async runtime is native-first; its Wasm support remains experimental.

## Async refinements

Wrap a normal schema with `async_schema()` and add checks that may perform I/O.
The normal parser runs first, so each check receives transformed and Strip-mode
cleaned JSON. A failing check returns `Some(async_issue(...))`; all check
failures are returned as `IssueCode::Custom` validation errors.

```mbt nocheck
let user = @moon_zod_async.async_schema(
  @moon_zod.object({ "email": @moon_zod.string().email() }),
).refine_async(value => {
  if email_is_taken(value) {
    Some(@moon_zod_async.async_issue("Email is already registered", path="email"))
  } else {
    None
  }
})

match user.parse_async(input) {
  Ok(clean) => // use clean
  Err(errors) => // report all validation errors
}
```

## JSON Lines streams

`validate_jsonl(reader, schema, handler)` reads one record at a time from an
`@io.Reader`. It waits for `handler` to finish before reading the next record,
providing backpressure without buffering the whole stream. Each non-blank line
emits `Valid`, `InvalidJson`, or `InvalidSchema`, followed by a `JsonlSummary`.

Call `async_schema.validate_jsonl(reader, handler)` when each record must also
run asynchronous refinements.
