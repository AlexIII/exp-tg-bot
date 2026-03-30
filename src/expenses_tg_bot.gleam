import app_error.{type AppError}
import data/expenses_repo
import gleam/httpc
import gleam/option.{type Option, Some}
import gleam/result
import gleam/string
import logging.{Info}
import services/action_service
import services/configuration_service
import services/currency_service
import services/expenses_service
import services/telegram_service
import sqlight
import utils/system

const help = "Usage:
- To add an expense: [category] amount currency [source]
  e.g. 'food 12.50 USD credit card'
- To get a report: /report [last]
  e.g. '/report' for this month, '/report last' for last month
"

pub fn main() {
  logging.configure()

  use app_config <- configuration_service.with_app_config()

  use conn <- sqlight.with_connection(app_config.db_file_path)

  let ctx =
    expenses_service.Context(
      action_service: action_service.new(),
      expenses_repo: expenses_repo.new(expenses_repo.Context(conn:)),
      currency_service: currency_service.new(currency_service.Context(
        httpc.send,
      )),
    )

  let handle_text = fn(from_id: Int, text: String) -> Option(String) {
    expenses_service.process_user_message(ctx, from_id, text)
    |> result.map(fn(_) { "Expense added" })
    |> error_to_message
  }

  let handle_report_cmd = fn(from_id: Int, cmd: telegram_service.Command) -> Option(
    String,
  ) {
    case cmd.command {
      "report" -> {
        let period = case cmd.payload {
          Some("last") | Some("last " <> _) -> expenses_service.LastMonth
          _ -> expenses_service.ThisMonth
        }

        expenses_service.get_report_for_user(
          ctx,
          from_id,
          expenses_service.ByCategory,
          period,
        )
        |> result.map(fn(report) { expenses_service.report_to_text(report) })
        |> error_to_message
      }
      _ -> Some("Unknown command: " <> cmd.command)
    }
  }

  let handle_help_cmd = fn(_from_id: Int, _cmd: telegram_service.Command) -> Option(
    String,
  ) {
    Some(help)
  }

  let shutdown =
    telegram_service.run(
      telegram_service.Config(
        bot_token: app_config.bot_token,
        enable_logs: True,
        handle_text: Some(handle_text),
        handle_command: [
          #("report", handle_report_cmd),
          #("help", handle_help_cmd),
        ],
      ),
    )

  logging.log(Info, "Starting bot... Press Ctrl+C to stop.")
  // Wait for Ctrl+C and shutdown gracefully
  system.wait_for_shutdown_signal()
  logging.log(Info, "Shutting down bot...")
  shutdown()
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
