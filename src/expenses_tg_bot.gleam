import data/expenses_repo
import gleam/httpc
import gleam/option.{Some}
import logging.{Info}
import services/action_service
import services/configuration_service
import services/currency_service
import services/expenses_service
import services/telegram_commands_service
import services/telegram_service
import sqlight
import utils/system

pub fn main() {
  logging.configure()

  use app_config <- configuration_service.with_app_config()

  use conn <- sqlight.with_connection(app_config.db_file_path)

  let cmd_service = build_commands_service(conn)

  let shutdown =
    telegram_service.run(telegram_service.Config(
      bot_token: app_config.bot_token,
      enable_logs: True,
      handle_text: Some(cmd_service.handle_message),
      handle_command: cmd_service.get_command_handlers(),
    ))

  logging.log(Info, "Starting bot... Press Ctrl+C to stop.")
  system.wait_for_shutdown_signal()
  logging.log(Info, "Shutting down bot...")
  shutdown()
}

fn build_commands_service(conn: sqlight.Connection) {
  let currency_service =
    currency_service.new(currency_service.Context(httpc.send))
  let expenses_repo = expenses_repo.new(expenses_repo.Context(conn:))
  let action_service = action_service.new()

  let expenses_service =
    expenses_service.new(expenses_service.Context(
      action_service:,
      expenses_repo:,
      currency_service:,
    ))

  let telegram_commands_service =
    telegram_commands_service.new(telegram_commands_service.Context(
      expenses_service:,
    ))

  telegram_commands_service
}
