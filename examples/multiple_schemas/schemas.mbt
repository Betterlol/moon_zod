///|
fn full_user_schema() -> @moon_zod.Schema {
  @moon_zod.object({
    "id": uuid_schema(),
    "ip": ip_address_schema(),
    "name": @moon_zod.string()
    .min(2)
    .max(50)
    .describe("The user's display name, 2-50 characters"),
    "age": @moon_zod.number().int().min(0).max(150),
    "email": email_schema(),
    "bio": @moon_zod.string().max(500).optional().describe("Short biography"),
    "score": @moon_zod.number().int().min(0).max(100).optional(),
    "profile": optional_profile_schema(),
    "tags": @moon_zod.array(@moon_zod.string().min(1))
    .min(1)
    .max(10)
    .describe("Up to 10 tags"),
    "metadata": @moon_zod.object({
      "source": @moon_zod.string().describe("Where the user came from"),
      "is_verified": @moon_zod.boolean().default(false),
      "login_count": @moon_zod.number().int().min(0).default(0),
    })
    .optional()
    .describe("Optional metadata object"),
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
/// show how to use refine to add custom validation logic
fn product_schema() -> @moon_zod.Schema {
  @moon_zod.object({
    "name": @moon_zod.string()
    .min(1)
    .describe("Product display name")
    .refine(val => !(val == "invalid"), "product name cannot be 'invalid'"),
    "price": @moon_zod.number().positive().describe("Price in dollars"),
    "currency": @moon_zod.string()
    .length(3)
    .default("USD")
    .describe("ISO 4217 currency code"),
    "in_stock": @moon_zod.boolean()
    .default(true)
    .describe("Whether the product is currently in stock"),
    "metadata": @moon_zod.object({
      "description": @moon_zod.string().max(2000).optional(),
      "images": @moon_zod.array(@moon_zod.string().url())
      .max(10)
      .describe("Product image URLs"),
    })
    .optional()
    .name("ProductMetadata"),
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
fn order_info_schema() -> @moon_zod.Schema {
  @moon_zod.intersection([order_id_schema(), datetime_schema()]).name(
    "OrderInfo",
  )
}

///|
/// show how to use datetime schema
fn datetime_schema() -> @moon_zod.Schema {
  @moon_zod.object({
    "created_at": @moon_zod.string()
    .datetime()
    .describe("The time the order was created"),
    "updated_at": @moon_zod.string()
    .datetime()
    .describe("The last time the order was updated"),
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
/// show how to use transform
fn review_score_schema() -> @moon_zod.Schema {
  @moon_zod.number()
  .int()
  .positive()
  .max(5)
  .describe("Rating from 1 to 5")
  .transform(fn(j) { Ok(j) })
  .name("ReviewScore")
}

///|
/// show how to use null type and default with describe
fn shipping_info_schema() -> @moon_zod.Schema {
  @moon_zod.object({
    "address": address_schema(),
    "tracking_number": @moon_zod.string()
    .optional()
    .describe("Tracking number, available after shipment"),
    "estimated_days": @moon_zod.number()
    .int()
    .min(1)
    .max(30)
    .default(5)
    .describe("Estimated delivery days"),
    "gift_wrap": @moon_zod.boolean()
    .default(false)
    .describe("Whether to gift wrap the order"),
    "special_instructions": @moon_zod.string()
    .optional()
    .describe("Any special delivery instructions"),
  }).name("ShippingInfo")
}

///|
fn order_schema() -> @moon_zod.Schema {
  @moon_zod.object({
    "user": user_schema(),
    "product": product_schema(),
    "status": order_status_schema(),
    "quantity": @moon_zod.number()
    .int()
    .positive()
    .default(1)
    .describe("Number of items ordered"),
    "address": address_schema(),
    "info": order_info_schema(),
    "shipping": shipping_info_schema(),
    "review_score": review_score_schema().optional(),
    "notes": @moon_zod.string().optional().describe("Optional order notes"),
    "is_priority": @moon_zod.boolean()
    .default(false)
    .describe("Whether this is a priority order"),
    "coupon_code": @moon_zod.string()
    .optional()
    .describe("Optional coupon code"),
  }).name("Order")
}
