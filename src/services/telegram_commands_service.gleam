import app_error.{type AppError}
import gleam/option.{type Option, Some}
import gleam/result
import gleam/string
import logging.{Info}
import services/expenses_service.{type ExpensesService}
import services/telegram_service.{type Command}

pub type Context {
  Context(expenses_service: ExpensesService)
}

pub type TelegramCommandsService {
  TelegramCommandsService(
    ctx: Context,
    /// from_tg_id, text -> response message
    handle_message: fn(Int, String) -> Option(String),
    /// (command_name, (from_tg_id, command -> response message))[]
    get_command_handlers: fn() ->
      List(#(String, fn(Int, Command) -> Option(String))),
  )
}

pub fn new(ctx: Context) -> TelegramCommandsService {
  TelegramCommandsService(
    ctx:,
    handle_message: fn(from_id, text) { handle_message(ctx, from_id, text) },
    get_command_handlers: fn() { get_command_handlers(ctx) },
  )
}

const help = "Usage:
- To add an expense: [category] amount currency [source]
  e.g. 'food 12.50 USD credit card'
- To get a report: /report [last]
  e.g. '/report' for this month, '/report last' for last month
"

fn handle_message(ctx: Context, from_id: Int, text: String) -> Option(String) {
  ctx.expenses_service.process_user_message(from_id, text)
  |> result.map(fn(_) { "Expense added" })
  |> error_to_message
}

fn get_command_handlers(
  ctx: Context,
) -> List(#(String, fn(Int, Command) -> Option(String))) {
  [
    #("report", fn(from_id: Int, cmd: telegram_service.Command) {
      handle_report_cmd(ctx, from_id, cmd)
    }),
    #("help", fn(_from_id: Int, _cmd: telegram_service.Command) {
      handle_help_cmd()
    }),
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
