import app_error.{ApiError, InvalidCurrency}
import gleam/http/response
import services/currency_service

pub fn get_rate_success_test() {
  let service =
    currency_service.new(
      currency_service.Context(fetch: fn(_req) {
        Ok(response.Response(
          status: 200,
          headers: [],
          body: "[{\"date\":\"2026-03-30\",\"base\":\"USD\",\"quote\":\"EUR\",\"rate\":0.92}]",
        ))
      }),
    )

  assert service.get_rate("usd", "eur") == Ok(0.92)
}

pub fn get_rate_invalid_currency_test() {
  let service =
    currency_service.new(
      currency_service.Context(fetch: fn(_req) {
        Ok(response.Response(status: 404, headers: [], body: ""))
      }),
    )

  assert service.get_rate("usd", "zzz")
    == Error(InvalidCurrency("Invalid currency pair: USD -> ZZZ"))
}

pub fn get_rate_invalid_json_test() {
  let service =
    currency_service.new(
      currency_service.Context(fetch: fn(_req) {
        Ok(response.Response(status: 200, headers: [], body: "not-json"))
      }),
    )

  let assert Error(ApiError(_)) = service.get_rate("usd", "eur")
}
