///|
/// Shared example schemas for moon_zod demos.
///
/// Schemas: product, movie

///|
pub fn product_schema() -> @moon_zod.Schema {
  @moon_zod.object({
    "name": @moon_zod.string().min(3).max(100),
    "description": @moon_zod.string().min(10).max(500),
    "price": @moon_zod.number().positive(),
    "currency": @moon_zod.enum_values(["USD", "EUR", "GBP", "JPY", "CNY"]),
    "category": @moon_zod.enum_values([
      "electronics", "clothing", "food", "books", "other",
    ]),
    "tags": @moon_zod.array(@moon_zod.string().min(1)),
    "stock": @moon_zod.number().int().min(0),
    "metadata": @moon_zod.object({
      "brand": @moon_zod.string().min(1),
      "weight_kg": @moon_zod.number().positive(),
    }).optional(),
  })
}

///|
pub fn movie_schema() -> @moon_zod.Schema {
  @moon_zod.object({
    "title": @moon_zod.string().min(1).max(200),
    "director": @moon_zod.string().min(1),
    "year": @moon_zod.number().int().min(1888),
    "rating": @moon_zod.number().min(0).max(10),
    "genres": @moon_zod.array(@moon_zod.string().min(1)),
    "cast": @moon_zod.array(
      @moon_zod.object({
        "name": @moon_zod.string().min(1),
        "role": @moon_zod.string().min(1),
      }),
    ),
    "duration_minutes": @moon_zod.number().int().positive(),
  })
}

///|
pub fn course_catalog_schema() -> @moon_zod.Schema {
  @moon_zod.object({
    "course": @moon_zod.object({
      "code": @moon_zod.string()
      .min(3)
      .max(20)
      .message("Course code must be 3–20 characters"),
      "name": @moon_zod.string()
      .min(10)
      .max(200)
      .message("Course name is required (min 10 characters)"),
      "version": @moon_zod.number().int().positive().max(99),
      "credits": @moon_zod.number().positive().max(12),
      "level": @moon_zod.enum_values([
        "introductory", "intermediate", "advanced", "graduate",
      ]),
      "department": @moon_zod.string().min(2).max(100),
      "delivery": @moon_zod.enum_values(["online", "in_person", "hybrid"]),
    }),
    "instructor": @moon_zod.object({
      "name": @moon_zod.string().min(2).max(100),
      "email": @moon_zod.string()
      .email()
      .message("Instructor email must be valid"),
      "title": @moon_zod.enum_values([
        "professor", "associate_professor", "lecturer", "teaching_assistant",
      ]),
      "office_hours": @moon_zod.array(
        @moon_zod.object({
          "day": @moon_zod.enum_values([
            "monday", "tuesday", "wednesday", "thursday", "friday",
          ]),
          "start": @moon_zod.string().min(5).max(5),
          "end": @moon_zod.string().min(5).max(5),
        }),
      )
      .min(1)
      .max(5)
      .message("At least 1 office hour slot required"),
    }),
    "modules": @moon_zod.array(
      @moon_zod.object({
        "title": @moon_zod.string().min(5).max(100),
        "weeks": @moon_zod.number().int().min(1).max(16),
        "topics": @moon_zod.array(
          @moon_zod.object({
            "name": @moon_zod.string().min(5).max(100),
            "type": @moon_zod.enum_values([
              "lecture", "lab", "seminar", "workshop", "exam",
            ]),
            "hours": @moon_zod.number().positive().max(6),
          }),
        )
        .min(1)
        .max(20)
        .message("Each module needs 1–20 topics"),
      }),
    )
    .min(3)
    .max(16)
    .message("Course requires 3–16 modules"),
    "schedule": @moon_zod.object({
      "semester": @moon_zod.enum_values(["spring", "summer", "fall", "winter"]),
      "year": @moon_zod.number().int().min(2024).max(2030),
      "sessions": @moon_zod.array(
        @moon_zod.object({
          "day": @moon_zod.enum_values([
            "monday", "tuesday", "wednesday", "thursday", "friday",
          ]),
          "start_time": @moon_zod.string().min(5).max(5),
          "end_time": @moon_zod.string().min(5).max(5),
          "room": @moon_zod.string().min(3).max(20),
        }),
      )
      .min(1)
      .max(7),
    }),
    "assessment": @moon_zod.object({
      "grading": @moon_zod.enum_values(["letter", "pass_fail", "audit"]),
      "components": @moon_zod.array(
        @moon_zod.object({
          "name": @moon_zod.string().min(2).max(50),
          "weight": @moon_zod.number().positive().max(100),
          "type": @moon_zod.enum_values([
            "quiz", "midterm", "final", "project", "homework", "participation",
          ]),
        }),
      )
      .min(1)
      .max(10),
    }),
    "prerequisites": @moon_zod.array(@moon_zod.string().min(3).max(20)).optional(),
    "tags": @moon_zod.array(@moon_zod.string().min(2).max(30))
    .min(1)
    .max(10)
    .message("At least 1 tag is required"),
  })
}

///|
pub fn get_schema(name : String) -> Result[@moon_zod.Schema, String] {
  match name {
    "product" => Ok(product_schema())
    "movie" => Ok(movie_schema())
    "course_catalog" => Ok(course_catalog_schema())
    _ => Err("Unknown schema: " + name)
  }
}
