///|
test "schema_to_prompt object field with default" {
  let s = object({ "role": string().default(Json::string("user")) })
  let expected = "{\n" + "  role?: string,\n" + "}"
  @debug.assert_eq(schema_to_prompt(s), expected)
}

///|
test "schema_to_prompt array with element and array constraints" {
  let s = array(string().min(2)).min(1).max(10)
  let expected = "string[]  // [min: 1 items, max: 10 items, min: 2]"
  @debug.assert_eq(schema_to_prompt(s), expected)
}

///|
test "schema_to_prompt string refine custom message" {
  let s = string().refine(
    fn(json) {
      match json {
        String(s) => s.contains("good")
        _ => false
      }
    },
    "Must contain 'good'",
  )
  @debug.assert_eq(schema_to_prompt(s), "string  // [Must contain 'good']")
}

///|
/// Phase 16 — schema_to_prompt TypeScript interface generation
test "schema_to_prompt leaf types" {
  @debug.assert_eq(schema_to_prompt(string()), "string")
  @debug.assert_eq(schema_to_prompt(number()), "number")
  @debug.assert_eq(schema_to_prompt(boolean()), "boolean")
  @debug.assert_eq(schema_to_prompt(null()), "null")
}

///|
test "schema_to_prompt optional and default" {
  @debug.assert_eq(schema_to_prompt(string().optional()), "string | null")
  @debug.assert_eq(
    schema_to_prompt(string().default(Json::string("x"))),
    "string | null",
  )
}

///|
test "schema_to_prompt string constraints" {
  @debug.assert_eq(
    schema_to_prompt(string().min(2).max(50)),
    "string  // [2-50 chars]",
  )
  @debug.assert_eq(schema_to_prompt(string().min(3)), "string  // [min: 3]")
  @debug.assert_eq(schema_to_prompt(string().max(100)), "string  // [max: 100]")
  @debug.assert_eq(schema_to_prompt(string().email()), "string  // [email]")
  @debug.assert_eq(schema_to_prompt(string().url()), "string  // [url]")
}

///|
test "schema_to_prompt number constraints" {
  @debug.assert_eq(schema_to_prompt(number().int()), "number  // [int]")
  @debug.assert_eq(
    schema_to_prompt(number().positive()),
    "number  // [positive]",
  )
  @debug.assert_eq(
    schema_to_prompt(number().negative()),
    "number  // [negative]",
  )
  @debug.assert_eq(
    schema_to_prompt(number().int().min(0).max(150)),
    "number  // [int, 0-150]",
  )
  @debug.assert_eq(schema_to_prompt(number().min(10)), "number  // [min: 10]")
  @debug.assert_eq(schema_to_prompt(number().max(100)), "number  // [max: 100]")
  @debug.assert_eq(
    schema_to_prompt(number().multipleOf(5)),
    "number  // [multiple of 5]",
  )
}

///|
test "schema_to_prompt enum" {
  @debug.assert_eq(
    schema_to_prompt(enum_values(["admin", "user", "viewer"])),
    "\"admin\" | \"user\" | \"viewer\"",
  )
  @debug.assert_eq(schema_to_prompt(enum_values(["a"])), "\"a\"")
}

///|
test "schema_to_prompt array" {
  @debug.assert_eq(schema_to_prompt(array(string())), "string[]")
  @debug.assert_eq(
    schema_to_prompt(array(string()).min(2)),
    "string[]  // [min: 2 items]",
  )
  @debug.assert_eq(
    schema_to_prompt(array(string()).max(5)),
    "string[]  // [max: 5 items]",
  )
  @debug.assert_eq(
    schema_to_prompt(array(string()).min(1).max(10)),
    "string[]  // [min: 1 items, max: 10 items]",
  )
  @debug.assert_eq(
    schema_to_prompt(array(string().email())),
    "string[]  // [email]",
  )
}

///|
test "schema_to_prompt union" {
  @debug.assert_eq(
    schema_to_prompt(union([string(), number()])),
    "string | number",
  )
  @debug.assert_eq(
    schema_to_prompt(union([string(), number(), boolean()])),
    "string | number | boolean",
  )
}

///|
test "schema_to_prompt optional with constraints" {
  @debug.assert_eq(
    schema_to_prompt(string().min(3).optional()),
    "string | null  // [min: 3]",
  )
  @debug.assert_eq(
    schema_to_prompt(number().int().optional()),
    "number | null  // [int]",
  )
}

///|
test "schema_to_prompt transform transparent" {
  let s = string().transform(fn(json) { Ok(json) })
  @debug.assert_eq(schema_to_prompt(s), "string")
  let s2 = number().int().transform(fn(j) { Ok(j) })
  @debug.assert_eq(schema_to_prompt(s2), "number  // [int]")
}

///|
test "schema_to_prompt empty object" {
  @debug.assert_eq(schema_to_prompt(object({})), "{}")
}

///|
test "schema_to_prompt simple object" {
  let s = object({
    "name": string().min(2).max(50),
    "age": number().int().min(0).max(150),
  })
  let expected = "{\n" +
    "  name: string,  // [2-50 chars]\n" +
    "  age: number,  // [int, 0-150]\n" +
    "}"
  @debug.assert_eq(schema_to_prompt(s), expected)
}

///|
test "schema_to_prompt object with optional fields" {
  let s = object({
    "name": string(),
    "email": string().email().optional(),
    "role": enum_values(["admin", "user"]),
  })
  let expected = "{\n" +
    "  name: string,\n" +
    "  email?: string,  // [email]\n" +
    "  role: \"admin\" | \"user\",\n" +
    "}"
  @debug.assert_eq(schema_to_prompt(s), expected)
}

///|
test "schema_to_prompt nested object" {
  let s = object({
    "profile": object({
      "age": number().int().min(0).max(150),
      "tags": array(string().min(1)),
    }),
  })
  let expected = "{\n" +
    "  profile: {\n" +
    "    age: number,  // [int, 0-150]\n" +
    "    tags: string[],  // [min: 1]\n" +
    "  },\n" +
    "}"
  @debug.assert_eq(schema_to_prompt(s), expected)
}

///|
test "schema_to_prompt nested optional object" {
  let s = object({
    "metadata": object({ "level": number().int().min(1).max(10) }).optional(),
  })
  let expected = "{\n" +
    "  metadata?: {\n" +
    "    level: number,  // [int, 1-10]\n" +
    "  },\n" +
    "}"
  @debug.assert_eq(schema_to_prompt(s), expected)
}

///|
test "schema_to_prompt refine custom message" {
  let s = number().refine(
    fn(json) {
      match json {
        Number(v, ..) => v > 10.0
        _ => false
      }
    },
    "Value must be > 10",
  )
  @debug.assert_eq(schema_to_prompt(s), "number  // [Value must be > 10]")
}

///|
test "schema_to_prompt nonempty is filtered" {
  // nonempty has no annotation and its message matches the built-in
  let s = string().nonempty()
  @debug.assert_eq(schema_to_prompt(s), "string")
}

///|
test "schema_to_prompt default with constraints" {
  let s = string().min(3).default(Json::string("abc"))
  @debug.assert_eq(schema_to_prompt(s), "string | null  // [min: 3]")
}

///|
test "schema_to_prompt describe alone" {
  @debug.assert_eq(
    schema_to_prompt(string().describe("用户名")),
    "string  // 用户名",
  )
}

///|
test "schema_to_prompt describe with constraints" {
  @debug.assert_eq(
    schema_to_prompt(string().min(3).max(50).describe("用户名")),
    "string  // [3-50 chars] — 用户名",
  )
}

///|
test "schema_to_prompt describe on optional" {
  @debug.assert_eq(
    schema_to_prompt(string().min(3).optional().describe("昵称")),
    "string | null  // [min: 3] — 昵称",
  )
}

///|
test "schema_to_prompt describe alone on optional" {
  @debug.assert_eq(
    schema_to_prompt(string().optional().describe("备注")),
    "string | null  // 备注",
  )
}

///|
test "schema_to_prompt describe on object fields" {
  let s = object({
    "name": string().min(2).max(50).describe("产品名称"),
    "price": number().positive().describe("产品价格"),
    "url": string().url().describe("产品链接"),
  })
  let expected = "{\n" +
    "  name: string,  // [2-50 chars] — 产品名称\n" +
    "  price: number,  // [positive] — 产品价格\n" +
    "  url: string,  // [url] — 产品链接\n" +
    "}"
  @debug.assert_eq(schema_to_prompt(s), expected)
}

///|
test "schema_to_prompt describe on optional object field" {
  let s = object({
    "email": string().email().optional().describe("用户邮箱"),
  })
  let expected = "{\n" +
    "  email?: string,  // [email] — 用户邮箱\n" +
    "}"
  @debug.assert_eq(schema_to_prompt(s), expected)
}

///|
test "schema_to_prompt describe on nested object field" {
  let s = object({
    "profile": object({
      "bio": string().min(10).max(500).describe("个人简介"),
    }).describe("用户资料"),
  })
  let expected = "{\n" +
    "  profile: {\n" +
    "    bio: string,  // [10-500 chars] — 个人简介\n" +
    "  },  // 用户资料\n" +
    "}"
  @debug.assert_eq(schema_to_prompt(s), expected)
}

///|
test "schema_to_prompt describe through transform" {
  let s = string().describe("保持原样").transform(fn(j) { Ok(j) })
  @debug.assert_eq(schema_to_prompt(s), "string  // 保持原样")
}

///|
/// Schema composition — prompt output
test "schema_to_prompt pick" {
  let s = object({ "a": string().min(2), "b": number() }).pick(["a"])
  let expected = "{\n" + "  a: string,  // [min: 2]\n" + "}"
  @debug.assert_eq(schema_to_prompt(s), expected)
}

///|
test "schema_to_prompt omit" {
  let s = object({ "a": string(), "b": number().int() }).omit(["b"])
  let expected = "{\n" + "  a: string,\n" + "}"
  @debug.assert_eq(schema_to_prompt(s), expected)
}

///|
test "schema_to_prompt partial" {
  let s = object({ "a": string().min(2), "b": number().int() }).partial()
  let expected = "{\n" +
    "  a?: string,  // [min: 2]\n" +
    "  b?: number,  // [int]\n" +
    "}"
  @debug.assert_eq(schema_to_prompt(s), expected)
}

///|
test "schema_to_prompt pick with field description" {
  let s = object({
    "name": string().min(2).describe("用户名"),
    "age": number().int().describe("年龄"),
  }).pick(["name"])
  let expected = "{\n" + "  name: string,  // [min: 2] — 用户名\n" + "}"
  @debug.assert_eq(schema_to_prompt(s), expected)
}

///|
test "schema_to_prompt intersection" {
  @debug.assert_eq(
    schema_to_prompt(intersection([string(), number()])),
    "string & number",
  )
  @debug.assert_eq(
    schema_to_prompt(intersection([string(), number(), boolean()])),
    "string & number & boolean",
  )
}
