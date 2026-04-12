import gleam/option.{type Option}

pub fn has(option: Option(a), on_value: fn(a) -> b, on_none: fn() -> b) -> b {
  option
  |> option.map(on_value)
  |> option.lazy_unwrap(on_none)
}
