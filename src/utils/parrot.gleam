import birl.{type Time, to_iso8601}
import gleam/result
import gleam/string
import parrot/dev
import sqlight

pub fn to_sqlight(param: dev.Param) -> sqlight.Value {
  case param {
    dev.ParamBool(x) -> sqlight.bool(x)
    dev.ParamFloat(x) -> sqlight.float(x)
    dev.ParamInt(x) -> sqlight.int(x)
    dev.ParamString(x) -> sqlight.text(x)
    dev.ParamBitArray(x) -> sqlight.blob(x)
    dev.ParamNullable(x) -> sqlight.nullable(fn(a) { to_sqlight(a) }, x)
    not_supported ->
      panic as { "Unsupported param type: " <> string.inspect(not_supported) }
  }
}

pub fn to_sqlite_datetime(time: Time) -> String {
  to_iso8601(time) |> string.replace("T", " ") |> string.slice(0, 19)
}

pub fn from_sqlite_datetime(datetime: String) -> Time {
  result.unwrap(birl.parse(datetime), birl.unix_epoch())
}
