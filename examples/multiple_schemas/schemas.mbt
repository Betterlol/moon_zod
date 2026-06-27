///|
fn full_user_schema() -> @moon_zod.Schema {
  @moon_zod.object({
    "id": uuid_schema(),
    "ip": ip_address_schema(),
    "name": @moon_zod.string().min(2).max(50),
    "age": @moon_zod.number().int().min(0).max(150),
    "email": email_schema(),
    "profile": optional_profile_schema(),
    "notifications_enabled": @moon_zod.boolean().optional().default(true),
  }).name("FullUser")
}

///|
/// show how to use the email schema in another schema
fn email_schema() -> @moon_zod.Schema {
  @moon_zod.string().email().name("Email")
}

///|
/// show how to use the url schema in another schema
fn url_schema() -> @moon_zod.Schema {
  @moon_zod.string().url().name("Url")
}

///|
/// show how to use the uuid schema in another schema
fn uuid_schema() -> @moon_zod.Schema {
  @moon_zod.string().uuid().name("Uuid")
}

///|
/// show how to use the ip schema in another schema
fn ip_address_schema() -> @moon_zod.Schema {
  @moon_zod.string().ip().name("IpAddress")
}

///|
/// show how to use partial to make all properties optional
fn optional_profile_schema() -> @moon_zod.Schema {
  fn profile_schema() -> @moon_zod.Schema {
    @moon_zod.object({
      "bio": @moon_zod.string().max(500),
      "avatar_url": url_schema(),
    }).name("Profile")
  }
  let profile = profile_schema()
  profile.partial().name("OptionalProfile")
}

///|
/// show how to use omit and pick to create a new schema based on an existing one
fn user_schema() -> @moon_zod.Schema {
  let full_user = full_user_schema()
  let user_without_email = full_user.omit(["email"])
  let user_with_only_name_and_age = user_without_email.pick(["name", "age"])
  user_with_only_name_and_age.name("User")
}

///|
fn product_schema() -> @moon_zod.Schema {
  @moon_zod.object({
    "name": @moon_zod.string().min(1),
    "price": @moon_zod.number().positive(),
  }).name("Product")
}

///|
/// show how to use enum values
fn order_status_schema() -> @moon_zod.Schema {
  @moon_zod.enum_values(["pending", "shipped", "delivered", "cancelled"])
  .name("OrderStatus")
  .describe("The status of an order")
}

///|
/// show how to use union types
fn address_schema() -> @moon_zod.Schema {
  fn home_address_schema() -> @moon_zod.Schema {
    @moon_zod.object({
      "type": @moon_zod.literal("home"),
      "street": @moon_zod.string().min(1),
      "city": @moon_zod.string().min(1),
    }).name("HomeAddress")
  }
  fn office_address_schema() -> @moon_zod.Schema {
    @moon_zod.object({
      "type": @moon_zod.literal("office"),
      "company": @moon_zod.string().min(1),
    }).name("OfficeAddress")
  }
  @moon_zod.union([home_address_schema(), office_address_schema()]).name(
    "Address",
  )
}

///|
/// show how to use intersection types
/// it can generate a TypeScript intersection type and a Zod schema for it
fn order_info_schema() -> @moon_zod.Schema {
  @moon_zod.intersection([order_id_schema(), datetime_schema()]).name(
    "OrderInfo",
  )
}

///|
fn datetime_schema() -> @moon_zod.Schema {
  @moon_zod.object({
    "created_at": @moon_zod.string().datetime(),
    "updated_at": @moon_zod.string().datetime(),
  }).name("DateTime")
}

///|
fn order_id_schema() -> @moon_zod.Schema {
  fn order_id_positive_schema() -> @moon_zod.Schema {
    @moon_zod.object({ "id": @moon_zod.number().int().positive() })
  }
  fn order_id_smaller_than_100_schema() -> @moon_zod.Schema {
    @moon_zod.object({ "id": @moon_zod.number().int().max(100) })
  }
  @moon_zod.intersection([
    order_id_positive_schema(),
    order_id_smaller_than_100_schema(),
  ]).name("OrderId")
}

///|
fn order_schema() -> @moon_zod.Schema {
  @moon_zod.object({
    "user": user_schema(),
    "product": product_schema(),
    "status": order_status_schema(),
    "address": address_schema(),
    "info": order_info_schema(),
  }).name("Order")
}

