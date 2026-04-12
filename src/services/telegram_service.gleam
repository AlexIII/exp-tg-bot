import gleam/bool
import gleam/function.{identity}
import gleam/httpc
import gleam/list
import gleam/option.{type Option}
import gleam/result
import gleam/string
import logging.{Info}
import services/types.{type MessageAttrs, MessageAttrs}
import telega
import telega/bot
import telega/client as telega_httpc
import telega/error as telega_error
import telega/reply
import telega/router
import telega/update
import utils/utils.{has}

pub type Command =
  update.Command

pub type Config {
  Config(
    bot_token: String,
    enable_logs: Bool,
    /// message -> response text
    handle_text: Option(fn(String, MessageAttrs) -> Option(String)),
    /// command -> response text
    handle_command: List(#(String, fn(Command, MessageAttrs) -> Option(String))),
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
            use resp <- option.map(handle_text(
              text,
              map_telega_update_to_message_attrs(ctx.update),
            ))
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
          use resp <- option.map(handler(
            cmd,
            map_telega_update_to_message_attrs(ctx.update),
          ))
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

fn map_telega_update_to_message_attrs(update: update.Update) -> MessageAttrs {
  case update {
    update.TextUpdate(message: msg, from_id:, ..)
    | update.CommandUpdate(message: msg, from_id:, ..) ->
      MessageAttrs(
        id: msg.message_id,
        from_id: from_id,
        reply_to_message_id: msg.reply_to_message
          |> option.map(fn(reply) { reply.message_id }),
      )
    _ -> panic as "Unexpected update type"
  }
}

fn send_reply(ctx: bot.Context(a, b), text: String) {
  use send_error <- result.map_error(reply.with_text(ctx, text))
  logging.log(Info, "Failed to send reply: " <> string.inspect(send_error))
  Nil
}
