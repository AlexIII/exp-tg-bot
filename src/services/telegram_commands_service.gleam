import app_error.{type AppError}
import gleam/option.{type Option, Some}
import gleam/result
import gleam/string
import logging.{Info}
import services/expenses_service.{type ExpensesService}
import services/telegram_service.{type Command}
import services/types.{type MessageAttrs}
import utils/utils.{has}

pub type Context {
  Context(expenses_service: ExpensesService)
}

pub type TelegramCommandsService {
  TelegramCommandsService(
    ctx: Context,
    /// text -> response message
    handle_message: fn(String, MessageAttrs) -> Option(String),
    /// (command_name, (command -> response message))[]
    get_command_handlers: fn() ->
      List(#(String, fn(Command, MessageAttrs) -> Option(String))),
  )
}

pub fn new(ctx: Context) -> TelegramCommandsService {
  TelegramCommandsService(
    ctx:,
    handle_message: fn(text, attrs) { handle_message(ctx, text, attrs) },
    get_command_handlers: fn() { get_command_handlers(ctx) },
  )
}

const help = "- To add an expense: [category] amount currency [source]
  e.g. 'food 12.50 USD credit card'

- To get a report: /report [last]
  e.g. '/report' for this month, '/report last' for last month

- To delete an expense: reply to the expense message (quoted) with '/del'

This is an open-source project.
https://github.com/AlexIII/exp-tg-bot
"

fn handle_message(
  ctx: Context,
  text: String,
  attrs: MessageAttrs,
) -> Option(String) {
  ctx.expenses_service.process_user_message(text, attrs)
  |> result.map(fn(_) { "Expense added" })
  |> error_to_message
}

fn get_command_handlers(
  ctx: Context,
) -> List(#(String, fn(Command, MessageAttrs) -> Option(String))) {
  [
    #("report", fn(cmd: Command, attrs: MessageAttrs) {
      handle_report_cmd(ctx, attrs.from_id, cmd)
    }),
    #("help", fn(_, _) { handle_help_cmd() }),
    #("del", fn(_, attrs: MessageAttrs) { handle_delete_cmd(ctx, attrs) }),
  ]
}

fn handle_help_cmd() -> Option(String) {
  Some(help)
}

fn handle_report_cmd(
  ctx: Context,
  from_id: Int,
  cmd: telegram_service.Command,
) -> Option(String) {
  case cmd.command {
    "report" -> {
      let period = case cmd.payload {
        Some("last") | Some("last " <> _) -> expenses_service.LastMonth
        _ -> expenses_service.ThisMonth
      }

      ctx.expenses_service.get_report_for_user(
        from_id,
        expenses_service.ByCategory,
        period,
      )
      |> result.map(expenses_service.report_to_text)
      |> error_to_message
    }
    _ -> Some("Unknown command: " <> cmd.command)
  }
}

fn handle_delete_cmd(ctx: Context, attrs: MessageAttrs) -> Option(String) {
  has(
    attrs.reply_to_message_id,
    fn(reply_to_message_id) {
      ctx.expenses_service.delete_expense_by_user_and_message_id(
        attrs.from_id,
        reply_to_message_id,
      )
      |> result.map(fn(_) { "Expense deleted" })
      |> error_to_message
    },
    fn() {
      Some("To delete an expense, reply to the expense message with /del")
    },
  )
}

fn error_to_message(result: Result(String, AppError)) -> Option(String) {
  result.try_recover(result, fn(error) {
    logging.log(
      Info,
      "Error processing message: " <> string.inspect(error.message),
    )
    Ok(
      "Sorry, I couldn't process your message: "
      <> string.inspect(error.message)
      <> "\n\n"
      <> help,
    )
  })
  |> option.from_result
}
