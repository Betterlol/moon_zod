///|
/// Measure the full in-memory read/decode/validate pipeline, without network I/O.
async fn measure(
  label : String,
  input : String,
  records : Int32,
  sse~ : Bool,
) -> Unit {
  let samples : Array[Double] = []
  for run in 0..<9 {
    // Allow coroutine cleanup between samples outside the timed region.
    @moon_async.pause()
    let start = @bench.monotonic_clock_start()
    let reader = @io.MemoryReader() <| writer => { writer.write(input) }
    defer reader.close()
    let valid = if sse {
      @zod_async.validate_sse_json(reader, @core.unknown(), _ => ()).valid
    } else {
      @zod_async.validate_jsonl(reader, @core.unknown(), _ => ()).valid
    }
    assert_eq(valid, records)
    let elapsed = @bench.monotonic_clock_end(start) / 1000.0
    if run >= 2 {
      samples.push(elapsed)
    }
  }
  samples.sort()
  println(
    "\{label}: median \{samples[3]} ms (7 samples, 2 warmups, \{records} records)",
  )
}

///|
async fn main {
  measure(
    "JSONL short",
    "{\"name\":\"Ada\",\"active\":true}\n".repeat(20000),
    20000,
    sse=false,
  )
  measure(
    "SSE short",
    "data: {\"name\":\"Ada\"}\n\n".repeat(20000),
    20000,
    sse=true,
  )
  let long_record = "\"" + "a".repeat(16384) + "\"\n"
  measure("JSONL 16 KiB", long_record.repeat(500), 500, sse=false)
}
