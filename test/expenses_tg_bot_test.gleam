import app_error.{InvalidMessageFormat}
import gleam/option.{None, Some}
import gleeunit
import services/action_service.{Expense}

pub fn main() {
  gleeunit.main()
}

pub fn parse_full_message_test() {
  assert action_service.new().parse("Hosting Services 12.50 USD crEdit Card")
    == Ok(Expense(
      amount: 12.5,
      currency: "USD",
      category: Some("hosting services"),
      source: Some("credit card"),
    ))
}

pub fn parse_no_category_no_source_test() {
  assert action_service.new().parse("12.50 usd")
    == Ok(Expense(amount: 12.5, currency: "USD", category: None, source: None))
}

pub fn parse_integer_amount_test() {
  assert action_service.new().parse("food 42 USD")
    == Ok(Expense(
      amount: 42.0,
      currency: "USD",
      category: Some("food"),
      source: None,
    ))
}

pub fn parse_invalid_format_test() {
  assert action_service.new().parse("not a valid message 15")
    == Error(InvalidMessageFormat("Message does not match regexp"))
}
