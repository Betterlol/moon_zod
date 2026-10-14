///|
test "constraints retain strongest boundaries independent of chaining order" {
  assert_eq(constraint_comment(string().min(5).min(2)), "min: 5")
  assert_eq(constraint_comment(string().max(2).max(5)), "max: 2")
  assert_eq(constraint_comment(number().min(-10).max(-2)), "-10--2")
}

///|
test "constraints after a builtin transform remain visible" {
  assert_eq(constraint_comment(string().trim().min(3)), "min: 3")
}
