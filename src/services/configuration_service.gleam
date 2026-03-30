import app_error.{type AppError, ConfigMissing}
import dot_env as dot
import dot_env/env
import gleam/result

pub type AppConfig {
  AppConfig(db_file_path: String, bot_token: String)
}

const env_prefix = "EXPBOT_"

pub fn with_app_config(f: fn(AppConfig) -> a) -> a {
  let assert Ok(config) =
    get_app_config()
    |> result.map_error(fn(e) {
      panic as { "Failed to load configuration: " <> e.message }
    })
  f(config)
}

pub fn get_app_config() -> Result(AppConfig, AppError) {
  dot.new()
  |> dot.set_path(".env")
  |> dot.set_debug(False)
  |> dot.load

  use db_file_path <- result.try(get_env_var("DB_FILE_PATH"))
  use bot_token <- result.try(get_env_var("BOT_TOKEN"))

  Ok(AppConfig(db_file_path:, bot_token:))
}

fn get_env_var(name: String) -> Result(String, AppError) {
  use _ <- result.map_error(env.get_string(env_prefix <> name))
  ConfigMissing(
    "Environment variable '" <> env_prefix <> name <> "' is is not set",
  )
}
