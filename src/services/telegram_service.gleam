import gleam/bool
import gleam/function.{identity}
import gleam/httpc
import gleam/list
import gleam/option.{type Option}
import gleam/result
import gleam/string
import logging.{Info}
import telega
import telega/bot
import telega/client as telega_httpc
import telega/error as telega_error
import telega/reply
import telega/router
import telega/update

pub type Command =
  update.Command

pub type Config {
  Config(
    bot_token: String,
    enable_logs: Bool,
    handle_text: Option(fn(Int, String) -> Option(String)),
    handle_command: List(#(String, fn(Int, Command) -> Option(String))),
  )
}

/// Runs the Telegram bot with the given configuration.
/// Returns a function that can be called to gracefully shut down the bot.
pub fn run(config: Config) -> fn() -> Nil {
  let router =
    router.new("echo_bot")
    |> bool.guard(
      config.enable_logs,
      fn(r) { router.use_middleware(r, router.with_logging) },
      fn() { fn(r) { r } },
    )
    |> has(
      config.handle_text,
      fn(handle_text) {
        fn(r) {
          use ctx, text <- router.on_any_text(r)
          {
            use resp <- option.map(handle_text(ctx.update.from_id, text))
            send_reply(ctx, resp)
          }
          Ok(ctx)
        }
      },
      fn() { identity },
    )
    |> fn(r) {
      list.fold(config.handle_command, r, fn(r, cmd) {
        let #(cmd_name, handler) = cmd
        use ctx, cmd <- router.on_command(r, cmd_name)
        {
          use resp <- option.map(handler(ctx.update.from_id, cmd))
          send_reply(ctx, resp)
        }
        Ok(ctx)
      })
    }

  let client =
    telega_httpc.new(config.bot_token, fn(req) {
      use error <- result.map_error(httpc.send(req))
      telega_error.FetchError(string.inspect(error))
    })

  let assert Ok(bot) =
    telega.new_for_polling(api_client: client)
    |> telega.with_router(router)
    |> telega.init_for_polling_nil_session()

  fn() { telega.shutdown(bot) }
}

fn send_reply(ctx: bot.Context(a, b), text: String) {
  use send_error <- result.map_error(reply.with_text(ctx, text))
  logging.log(Info, "Failed to send reply: " <> string.inspect(send_error))
  send_error
}

fn has(option: Option(a), on_value: fn(a) -> b, on_none: fn() -> b) -> b {
  option
  |> option.map(on_value)
  |> option.lazy_unwrap(on_none)
}
