import app_error.{type AppError, InvalidMessageFormat}
import gleam/float
import gleam/int
import gleam/option.{type Option, None, Some}
import gleam/regexp
import gleam/result
import gleam/string

pub type Action {
  Expense(
    amount: Float,
    currency: String,
    category: Option(String),
    source: Option(String),
  )
}

pub type ActionService {
  /// message format: "[category] amount currency [source]"
  /// 
  /// example: "food 12.50 USD credit card"
  ActionService(parse: fn(String) -> Result(Action, AppError))
}

pub fn new() -> ActionService {
  ActionService(parse)
}

fn parse(message: String) -> Result(Action, AppError) {
  let assert Ok(re) =
    regexp.from_string("^(.+\\s+)?(\\d+.?\\d*)\\s+(\\w\\w\\w)(\\s+.*)?$")

  case regexp.scan(re, string.trim(message)) {
    [match] -> {
      let build_expense = fn(category, amount, currency, source) {
        use f <- result.map(parse_amount(amount))
        Expense(
          amount: f,
          currency: currency |> string.uppercase,
          category: category |> normalize_str,
          source: source |> normalize_str,
        )
      }

      case match.submatches {
        [category, Some(amount), Some(currency), source] ->
          build_expense(category, amount, currency, source)
        [category, Some(amount), Some(currency)] ->
          build_expense(category, amount, currency, None)
        _ -> Error(InvalidMessageFormat("Unexpected regexp result"))
      }
    }
    _ -> Error(InvalidMessageFormat("Message does not match regexp"))
  }
}

fn parse_amount(amount) {
  float.parse(amount)
  |> result.lazy_or(fn() { int.parse(amount) |> result.map(int.to_float) })
  |> result.map_error(fn(_) { InvalidMessageFormat("Invalid amount") })
}

fn normalize_str(s: Option(String)) {
  let none_if_empty = fn(s) {
    case s {
      "" -> None
      _ -> Some(s)
    }
  }

  use s <- option.then(s)

  s
  |> string.trim
  |> string.lowercase
  |> none_if_empty
}
