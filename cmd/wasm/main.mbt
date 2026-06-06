///|
/// Wasm benchmark module for cross-language comparison.
///
/// Usage:
///   moon run cmd/wasm -- moonzod       # Run moon_zod benchmark
///   moon run cmd/wasm -- handcrafted   # Run handcrafted match benchmark
///   moon run cmd/wasm -- verify        # Verify both outputs match
let schema : @moon_zod.Schema = @moon_zod.object({
  "users": @moon_zod.array(
    @moon_zod.object({
      "id": @moon_zod.number().int().min(0),
      "name": @moon_zod.string().min(1).max(100),
      "email": @moon_zod.string().email().optional(),
      "role": @moon_zod.enum_values(["admin", "user", "viewer"]),
      "profile": @moon_zod.object({
        "age": @moon_zod.number().int().min(0).max(150),
        "tags": @moon_zod.array(@moon_zod.string().min(1)),
        "metadata": @moon_zod.object({
          "department": @moon_zod.string().min(1),
          "level": @moon_zod.number().int().min(1).max(10),
          "active": @moon_zod.boolean(),
        }).optional(),
      }),
    }),
  ),
  "config": @moon_zod.object({
    "version": @moon_zod.string().min(1),
    "debug": @moon_zod.boolean(),
    "maxRetries": @moon_zod.number().int().min(0).max(10),
  }),
})

///|
let large_input : Json = Json::object({
  "users": Json::array([
    Json::object({
      "id": Json::number(1.0),
      "name": Json::string("Alice"),
      "email": Json::string("alice@example.com"),
      "role": Json::string("admin"),
      "profile": Json::object({
        "age": Json::number(30.0),
        "tags": Json::array([
          Json::string("rust"),
          Json::string("wasm"),
          Json::string("ai"),
        ]),
        "metadata": Json::object({
          "department": Json::string("Engineering"),
          "level": Json::number(5.0),
          "active": Json::boolean(true),
        }),
      }),
    }),
    Json::object({
      "id": Json::number(2.0),
      "name": Json::string("Bob"),
      "role": Json::string("user"),
      "profile": Json::object({
        "age": Json::number(25.0),
        "tags": Json::array([Json::string("design")]),
        "metadata": Json::object({
          "department": Json::string("Design"),
          "level": Json::number(3.0),
          "active": Json::boolean(false),
        }),
      }),
    }),
    Json::object({
      "id": Json::number(3.0),
      "name": Json::string("Charlie"),
      "role": Json::string("viewer"),
      "profile": Json::object({
        "age": Json::number(42.0),
        "tags": Json::array([Json::string("python"), Json::string("data")]),
      }),
    }),
  ]),
  "config": Json::object({
    "version": Json::string("1.0.0"),
    "debug": Json::boolean(false),
    "maxRetries": Json::number(3.0),
  }),
})

///|
fn main {
  let args = @env.args()
  let mode = if args.length() > 1 { args[1] } else { "moonzod" }
  let n = 100_000

  match mode {
    "moonzod" => {
      let _ = bench_moon_zod(n)
    }
    "handcrafted" => {
      let _ = bench_handcrafted_match(n)
    }
    "startup" => println("[DONE] startup")
    "verify" => {
      let mz = bench_moon_zod(1)
      let hc = bench_handcrafted_match(1)
      if mz == hc {
        println("VERIFY: Both implementations agree (all validations passed)")
      } else {
        println("VERIFY: MISMATCH between moon_zod and handcrafted match!")
      }
    }
    _ => {
      println("Usage: moon run cmd/wasm -- <mode>")
      println("  moonzod     - Run moon_zod validation benchmark")
      println("  handcrafted - Run handcrafted match benchmark")
      println(
        "  verify      - Verify both implementations agree\n  startup     - Measure process startup overhead (no-op)",
      )
    }
  }
}

///|
/// Run moon_zod validation N times. Returns true on success.
pub fn bench_moon_zod(n : Int) -> Bool {
  for i = 0; i < n; i = i + 1 {
    match schema.parse(large_input) {
      Ok(_) => ()
      Err(_) => return false
    }
  }
  println("[DONE] moon_zod: \{n.to_string()} iterations")
  true
}

///|
/// Run handcrafted match validation N times. Returns true on success.
pub fn bench_handcrafted_match(n : Int) -> Bool {
  for i = 0; i < n; i = i + 1 {
    if !validate_data(large_input) {
      return false
    }
  }
  println("[DONE] handcrafted: \{n.to_string()} iterations")
  true
}

///|
/// Validate the full data structure using raw pattern matching.
fn validate_data(json : Json) -> Bool {
  match json {
    Object(map) =>
      match (map.get("users"), map.get("config")) {
        (Some(users), Some(config)) =>
          validate_users(users) && validate_config(config)
        _ => false
      }
    _ => false
  }
}

///|
fn validate_config(json : Json) -> Bool {
  match json {
    Object(fields) => {
      match fields.get("version") {
        Some(String(s)) => if s.length() < 1 { return false }
        _ => return false
      }
      match fields.get("debug") {
        Some(True) | Some(False) => ()
        _ => return false
      }
      match fields.get("maxRetries") {
        Some(Number(v, ..)) =>
          if v != v.to_int().to_double() || v < 0.0 || v > 10.0 {
            return false
          }
        _ => return false
      }
      true
    }
    _ => false
  }
}

///|
fn validate_users(json : Json) -> Bool {
  match json {
    Array(users) => {
      for user in users {
        if !validate_user(user) {
          return false
        }
      }
      true
    }
    _ => false
  }
}

///|
fn validate_user(json : Json) -> Bool {
  match json {
    Object(fields) => {
      // id: number, int, >= 0
      match fields.get("id") {
        Some(Number(v, ..)) =>
          if v != v.to_int().to_double() || v < 0.0 {
            return false
          }
        _ => return false
      }
      // name: string, 1..100
      match fields.get("name") {
        Some(String(s)) =>
          if s.length() < 1 || s.length() > 100 {
            return false
          }
        _ => return false
      }
      // email: optional string with email format
      match fields.get("email") {
        Some(Null) | None => ()
        Some(String(s)) => if !has_at_and_dot(s) { return false }
        _ => return false
      }
      // role: string, one of ["admin", "user", "viewer"]
      match fields.get("role") {
        Some(String(s)) =>
          if s != "admin" && s != "user" && s != "viewer" {
            return false
          }
        _ => return false
      }
      // profile
      match fields.get("profile") {
        Some(p) => validate_profile(p)
        _ => false
      }
    }
    _ => false
  }
}

///|
fn validate_profile(json : Json) -> Bool {
  match json {
    Object(fields) => {
      // age: number, int, 0..150
      match fields.get("age") {
        Some(Number(v, ..)) =>
          if v != v.to_int().to_double() || v < 0.0 || v > 150.0 {
            return false
          }
        _ => return false
      }
      // tags: array of strings with min length 1
      match fields.get("tags") {
        Some(Array(tags)) =>
          for tag in tags {
            match tag {
              String(s) => if s.length() < 1 { return false }
              _ => return false
            }
          }
        _ => return false
      }
      // metadata: optional object
      match fields.get("metadata") {
        Some(Null) | None => ()
        Some(m) => if !validate_metadata(m) { return false }
      }
      true
    }
    _ => false
  }
}

///|
fn validate_metadata(json : Json) -> Bool {
  match json {
    Object(fields) => {
      match fields.get("department") {
        Some(String(s)) => if s.length() < 1 { return false }
        _ => return false
      }
      match fields.get("level") {
        Some(Number(v, ..)) =>
          if v != v.to_int().to_double() || v < 1.0 || v > 10.0 {
            return false
          }
        _ => return false
      }
      match fields.get("active") {
        Some(True) | Some(False) => ()
        _ => return false
      }
      true
    }
    _ => false
  }
}

///|
fn has_at_and_dot(s : String) -> Bool {
  let chars = s.to_array()
  let mut at_pos = -1
  for i, c in chars {
    if c == '@' {
      at_pos = i
      break
    }
  }
  if at_pos <= 0 {
    return false
  }
  for i = at_pos + 1; i < chars.length(); i = i + 1 {
    if chars[i] == '.' && i > at_pos + 1 && i < chars.length() - 1 {
      return true
    }
  }
  false
}
