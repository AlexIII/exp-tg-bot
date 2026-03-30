import app_error.{type AppError, ApiError, InvalidCurrency}
import gleam/bool
import gleam/dynamic/decode
import gleam/http/request
import gleam/http/response
import gleam/httpc
import gleam/int
import gleam/json
import gleam/result
import gleam/string

pub type Context {
  Context(
    fetch: fn(request.Request(String)) ->
      Result(response.Response(String), httpc.HttpError),
  )
}

pub type CurrencyService {
  CurrencyService(
    ctx: Context,
    /// Accepts base currency (e.g. "USD") and target currency (e.g. "EUR"), returns exchange rate
    get_rate: fn(String, String) -> Result(Float, AppError),
  )
}

pub type Quote {
  Quote(date: String, base: String, quote: String, rate: Float)
}

pub fn new(ctx: Context) -> CurrencyService {
  CurrencyService(ctx:, get_rate: fn(base, quote) { get_rate(ctx, base, quote) })
}

fn get_rate(
  ctx: Context,
  base: String,
  quote: String,
) -> Result(Float, AppError) {
  let base = string.uppercase(base)
  let quote = string.uppercase(quote)

  use <- bool.guard(base == quote, Ok(1.0))

  let url =
    "https://api.frankfurter.dev/v2/rates?base=" <> base <> "&quotes=" <> quote

  use req <- result.try(
    request.to(url)
    |> result.map_error(fn(error) {
      ApiError(
        "Failed to build currency API request: " <> string.inspect(error),
      )
    }),
  )

  use resp <- result.try(
    ctx.fetch(req)
    |> result.map_error(fn(error) {
      ApiError("Currency API request failed: " <> string.inspect(error))
    }),
  )

  case resp.status {
    200 -> {
      use quotes <- result.try(
        json.parse(resp.body, using: quote_array_decoder())
        |> result.map_error(fn(error) {
          ApiError(
            "Failed to decode currency API response: " <> string.inspect(error),
          )
        }),
      )

      case quotes {
        [Quote(rate:, ..), ..] -> Ok(rate)
        [] ->
          Error(InvalidCurrency(
            "No exchange rate returned for " <> base <> " -> " <> quote,
          ))
      }
    }

    400 | 404 -> {
      Error(InvalidCurrency(
        "Invalid currency pair: " <> base <> " -> " <> quote,
      ))
    }

    _ ->
      Error(ApiError(
        "Currency API returned status "
        <> int.to_string(resp.status)
        <> " with body: "
        <> resp.body,
      ))
  }
}

fn quote_array_decoder() -> decode.Decoder(List(Quote)) {
  decode.list(quote_decoder())
}

fn quote_decoder() -> decode.Decoder(Quote) {
  use date <- decode.field("date", decode.string)
  use base <- decode.field("base", decode.string)
  use quote <- decode.field("quote", decode.string)
  use rate <- decode.field("rate", decode.float)
  decode.success(Quote(date:, base:, quote:, rate:))
}
