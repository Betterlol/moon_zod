///|
/// Measure the full in-memory read/decode/validate pipeline, without network I/O.
async fn measure(
  label : String,
  input : String,
  records : Int32,
  sse~ : Bool,
) -> Unit {
  let samples : Array[Int64] = []
  for run in 0..<9 {
    let start = @moon_async.now()
    let reader = @io.MemoryReader() <| writer => { writer.write(input) }
    defer reader.close()
    let valid = if sse {
      @zod_async.validate_sse_json(reader, @core.unknown(), _ => ()).valid
    } else {
      @zod_async.validate_jsonl(reader, @core.unknown(), _ => ()).valid
    }
    assert_eq(valid, records)
    let elapsed = @moon_async.now() - start
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
