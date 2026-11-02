///|
test "schema_to_prompt object field with default" {
  let s = @core.object({ "role": @core.string().default(Json::string("user")) })
  let expected = "{\n" + "  role?: string,\n" + "}"
  @debug.assert_eq(@exporters.schema_to_prompt(s), expected)
}

///|
test "schema_to_prompt array with element and array constraints" {
  let s = @core.array(@core.string().min(2)).min(1).max(10)
  let expected = "string[]  // [min: 1 items, max: 10 items, min: 2]"
  @debug.assert_eq(@exporters.schema_to_prompt(s), expected)
}

///|
test "schema_to_prompt string refine custom message" {
  let s = @core.string().refine(
    fn(json) {
      match json {
        String(s) => s.contains("good")
        _ => false
      }
    },
    "Must contain 'good'",
  )
  @debug.assert_eq(
    @exporters.schema_to_prompt(s),
    "string  // [Must contain 'good']",
  )
}

///|
/// Phase 16 — schema_to_prompt TypeScript interface generation
test "schema_to_prompt leaf types" {
  @debug.assert_eq(@exporters.schema_to_prompt(@core.string()), "string")
  @debug.assert_eq(@exporters.schema_to_prompt(@core.number()), "number")
  @debug.assert_eq(@exporters.schema_to_prompt(@core.boolean()), "boolean")
  @debug.assert_eq(@exporters.schema_to_prompt(@core.null()), "null")
}

///|
test "schema_to_prompt optional and default" {
  @debug.assert_eq(
    @exporters.schema_to_prompt(@core.string().optional()),
    "string | undefined",
  )
  @debug.assert_eq(
    @exporters.schema_to_prompt(@core.string().default(Json::string("x"))),
    "string",
  )
}

///|
test "schema_to_prompt string constraints" {
  @debug.assert_eq(
    @exporters.schema_to_prompt(@core.string().min(2).max(50)),
    "string  // [2-50 chars]",
  )
  @debug.assert_eq(
    @exporters.schema_to_prompt(@core.string().min(3)),
    "string  // [min: 3]",
  )
  @debug.assert_eq(
    @exporters.schema_to_prompt(@core.string().max(100)),
    "string  // [max: 100]",
  )
  @debug.assert_eq(
    @exporters.schema_to_prompt(@core.string().email()),
    "string  // [email]",
  )
  @debug.assert_eq(
    @exporters.schema_to_prompt(@core.string().url()),
    "string  // [url]",
  )
}

///|
test "schema_to_prompt number constraints" {
  @debug.assert_eq(
    @exporters.schema_to_prompt(@core.number().int()),
    "number  // [int, -9007199254740991-9007199254740991]",
  )
  @debug.assert_eq(
    @exporters.schema_to_prompt(@core.number().positive()),
    "number  // [positive]",
  )
  @debug.assert_eq(
    @exporters.schema_to_prompt(@core.number().negative()),
    "number  // [negative]",
  )
  @debug.assert_eq(
    @exporters.schema_to_prompt(@core.number().int().min(0).max(150)),
    "number  // [int, 0-150]",
  )
  @debug.assert_eq(
    @exporters.schema_to_prompt(@core.number().min(10)),
    "number  // [min: 10]",
  )
  @debug.assert_eq(
    @exporters.schema_to_prompt(@core.number().max(100)),
    "number  // [max: 100]",
  )
  @debug.assert_eq(
    @exporters.schema_to_prompt(@core.number().multipleOf(5)),
    "number  // [multiple of 5]",
  )
}

///|
test "schema_to_prompt enum" {
  @debug.assert_eq(
    @exporters.schema_to_prompt(@core.enum_values(["admin", "user", "viewer"])),
    "\"admin\" | \"user\" | \"viewer\"",
  )
  @debug.assert_eq(
    @exporters.schema_to_prompt(@core.enum_values(["a"])),
    "\"a\"",
  )
}

///|
test "schema_to_prompt array" {
  @debug.assert_eq(
    @exporters.schema_to_prompt(@core.array(@core.string())),
    "string[]",
  )
  @debug.assert_eq(
    @exporters.schema_to_prompt(@core.array(@core.string()).min(2)),
    "string[]  // [min: 2 items]",
  )
  @debug.assert_eq(
    @exporters.schema_to_prompt(@core.array(@core.string()).max(5)),
    "string[]  // [max: 5 items]",
  )
  @debug.assert_eq(
    @exporters.schema_to_prompt(@core.array(@core.string()).min(1).max(10)),
    "string[]  // [min: 1 items, max: 10 items]",
  )
  @debug.assert_eq(
    @exporters.schema_to_prompt(@core.array(@core.string().email())),
    "string[]  // [email]",
  )
}

///|
test "schema_to_prompt union" {
  @debug.assert_eq(
    @exporters.schema_to_prompt(@core.union([@core.string(), @core.number()])),
    "string | number",
  )
  @debug.assert_eq(
    @exporters.schema_to_prompt(
      @core.union([@core.string(), @core.number(), @core.boolean()]),
    ),
    "string | number | boolean",
  )
}

///|
test "schema_to_prompt optional with constraints" {
  @debug.assert_eq(
    @exporters.schema_to_prompt(@core.string().min(3).optional()),
    "string | undefined  // [min: 3]",
  )
  @debug.assert_eq(
    @exporters.schema_to_prompt(@core.number().int().optional()),
    "number | undefined  // [int, -9007199254740991-9007199254740991]",
  )
}

///|
test "schema_to_prompt transform transparent" {
  let s = @core.string().transform(fn(json) { Ok(json) })
  @debug.assert_eq(@exporters.schema_to_prompt(s), "string")
  let s2 = @core.number().int().transform(fn(j) { Ok(j) })
  @debug.assert_eq(
    @exporters.schema_to_prompt(s2),
    "number  // [int, -9007199254740991-9007199254740991]",
  )
}

///|
test "schema_to_prompt empty object" {
  @debug.assert_eq(@exporters.schema_to_prompt(@core.object(Map([]))), "{}")
}

///|
test "schema_to_prompt simple object" {
  let s = @core.object({
    "name": @core.string().min(2).max(50),
    "age": @core.number().int().min(0).max(150),
  })
  let expected = "{\n" +
    "  name: string,  // [2-50 chars]\n" +
    "  age: number,  // [int, 0-150]\n" +
    "}"
  @debug.assert_eq(@exporters.schema_to_prompt(s), expected)
}

///|
test "schema_to_prompt keeps named schemas inline" {
  let s = @core.object({ "name": @core.string().min(2).name("Username") }).name(
    "User",
  )
  let expected = "{\n" + "  name: string,  // [min: 2]\n" + "}"
  @debug.assert_eq(@exporters.schema_to_prompt(s), expected)
}

///|
test "schema_to_prompt object with optional fields" {
  let s = @core.object({
    "name": @core.string(),
    "email": @core.string().email().optional(),
    "role": @core.enum_values(["admin", "user"]),
  })
  let expected = "{\n" +
    "  name: string,\n" +
    "  email?: string,  // [email]\n" +
    "  role: \"admin\" | \"user\",\n" +
    "}"
  @debug.assert_eq(@exporters.schema_to_prompt(s), expected)
}

///|
test "schema_to_prompt nested object" {
  let s = @core.object({
    "profile": @core.object({
      "age": @core.number().int().min(0).max(150),
      "tags": @core.array(@core.string().min(1)),
    }),
  })
  let expected = "{\n" +
    "  profile: {\n" +
    "    age: number,  // [int, 0-150]\n" +
    "    tags: string[],  // [min: 1]\n" +
    "  },\n" +
    "}"
  @debug.assert_eq(@exporters.schema_to_prompt(s), expected)
}

///|
test "schema_to_prompt nested optional object" {
  let s = @core.object({
    "metadata": @core.object({ "level": @core.number().int().min(1).max(10) }).optional(),
  })
  let expected = "{\n" +
    "  metadata?: {\n" +
    "    level: number,  // [int, 1-10]\n" +
    "  },\n" +
    "}"
  @debug.assert_eq(@exporters.schema_to_prompt(s), expected)
}

///|
test "schema_to_prompt refine custom message" {
  let s = @core.number().refine(
    fn(json) {
      match json {
        Number(v, ..) => v > 10.0
        _ => false
      }
    },
    "Value must be > 10",
  )
  @debug.assert_eq(
    @exporters.schema_to_prompt(s),
    "number  // [Value must be > 10]",
  )
}

///|
test "schema_to_prompt nonempty shows min constraint" {
  let s = @core.string().nonempty()
  @debug.assert_eq(@exporters.schema_to_prompt(s), "string  // [min: 1]")
}

///|
test "schema_to_prompt default with constraints" {
  let s = @core.string().min(3).default(Json::string("abc"))
  @debug.assert_eq(@exporters.schema_to_prompt(s), "string  // [min: 3]")
}

///|
test "schema_to_prompt describe alone" {
  @debug.assert_eq(
    @exporters.schema_to_prompt(@core.string().describe("用户名")),
    "string  // 用户名",
  )
}

///|
test "schema_to_prompt describe with constraints" {
  @debug.assert_eq(
    @exporters.schema_to_prompt(
      @core.string().min(3).max(50).describe("用户名"),
    ),
    "string  // [3-50 chars] — 用户名",
  )
}

///|
test "schema_to_prompt describe on optional" {
  @debug.assert_eq(
    @exporters.schema_to_prompt(
      @core.string().min(3).optional().describe("昵称"),
    ),
    "string | undefined  // [min: 3] — 昵称",
  )
}

///|
test "schema_to_prompt describe alone on optional" {
  @debug.assert_eq(
    @exporters.schema_to_prompt(@core.string().optional().describe("备注")),
    "string | undefined  // 备注",
  )
}

///|
test "schema_to_prompt describe on object fields" {
  let s = @core.object({
    "name": @core.string().min(2).max(50).describe("产品名称"),
    "price": @core.number().positive().describe("产品价格"),
    "url": @core.string().url().describe("产品链接"),
  })
  let expected = "{\n" +
    "  name: string,  // [2-50 chars] — 产品名称\n" +
    "  price: number,  // [positive] — 产品价格\n" +
    "  url: string,  // [url] — 产品链接\n" +
    "}"
  @debug.assert_eq(@exporters.schema_to_prompt(s), expected)
}

///|
test "schema_to_prompt describe on optional object field" {
  let s = @core.object({
    "email": @core.string().email().optional().describe("用户邮箱"),
  })
  let expected = "{\n" +
    "  email?: string,  // [email] — 用户邮箱\n" +
    "}"
  @debug.assert_eq(@exporters.schema_to_prompt(s), expected)
}

///|
test "schema_to_prompt describe on nested object field" {
  let s = @core.object({
    "profile": @core.object({
      "bio": @core.string().min(10).max(500).describe("个人简介"),
    }).describe("用户资料"),
  })
  let expected = "{\n" +
    "  profile: {\n" +
    "    bio: string,  // [10-500 chars] — 个人简介\n" +
    "  },  // 用户资料\n" +
    "}"
  @debug.assert_eq(@exporters.schema_to_prompt(s), expected)
}

///|
test "schema_to_prompt describe through transform" {
  let s = @core.string().describe("保持原样").transform(fn(j) { Ok(j) })
  @debug.assert_eq(@exporters.schema_to_prompt(s), "string  // 保持原样")
}

///|
/// Schema composition — prompt output
test "schema_to_prompt pick" {
  let s = @core.object({ "a": @core.string().min(2), "b": @core.number() }).pick([
      "a",
    ],
  )
  let expected = "{\n" + "  a: string,  // [min: 2]\n" + "}"
  @debug.assert_eq(@exporters.schema_to_prompt(s), expected)
}

///|
test "schema_to_prompt omit" {
  let s = @core.object({ "a": @core.string(), "b": @core.number().int() }).omit([
      "b",
    ],
  )
  let expected = "{\n" + "  a: string,\n" + "}"
  @debug.assert_eq(@exporters.schema_to_prompt(s), expected)
}

///|
test "schema_to_prompt partial" {
  let s = @core.object({ "a": @core.string().min(2), "b": @core.number().int() }).partial()
  let expected = "{\n" +
    "  a?: string,  // [min: 2]\n" +
    "  b?: number,  // [int, -9007199254740991-9007199254740991]\n" +
    "}"
  @debug.assert_eq(@exporters.schema_to_prompt(s), expected)
}

///|
test "schema_to_prompt pick with field description" {
  let s = @core.object({
    "name": @core.string().min(2).describe("用户名"),
    "age": @core.number().int().describe("年龄"),
  }).pick(["name"])
  let expected = "{\n" + "  name: string,  // [min: 2] — 用户名\n" + "}"
  @debug.assert_eq(@exporters.schema_to_prompt(s), expected)
}

///|
test "schema_to_prompt intersection" {
  @debug.assert_eq(
    @exporters.schema_to_prompt(
      @core.intersection([@core.string(), @core.number()]),
    ),
    "string & number",
  )
  @debug.assert_eq(
    @exporters.schema_to_prompt(
      @core.intersection([@core.string(), @core.number(), @core.boolean()]),
    ),
    "string & number & boolean",
  )
}

///|
test "schema_to_prompt literal values" {
  @debug.assert_eq(
    @exporters.schema_to_prompt(@core.literal(Json::number(3.14))),
    "3.14",
  )
  @debug.assert_eq(
    @exporters.schema_to_prompt(@core.literal(Json::boolean(true))),
    "true",
  )
  @debug.assert_eq(
    @exporters.schema_to_prompt(@core.literal(Json::boolean(false))),
    "false",
  )
  @debug.assert_eq(
    @exporters.schema_to_prompt(@core.literal(Json::null())),
    "null",
  )
  @debug.assert_eq(
    @exporters.schema_to_prompt(
      @core.literal(Json::array([Json::string("a"), Json::number(1)])),
    ),
    "[\"a\", 1]",
  )
  @debug.assert_eq(
    @exporters.schema_to_prompt(
      @core.literal(Json::object({ "ok": Json::boolean(true) })),
    ),
    "{\"ok\": true}",
  )
}

///|
test "schema_to_prompt non aborting broad schema types" {
  @debug.assert_eq(@exporters.schema_to_prompt(@core.any()), "any")
  @debug.assert_eq(@exporters.schema_to_prompt(@core.unknown()), "unknown")
  @debug.assert_eq(
    @exporters.schema_to_prompt(@core.tuple([@core.string(), @core.number()])),
    "[string, number]",
  )
  let s = @core.preprocess(fn(j) { Ok(j) }, @core.string().min(2))
  @debug.assert_eq(@exporters.schema_to_prompt(s), "string  // [min: 2]")
}
