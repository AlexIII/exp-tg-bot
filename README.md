# Expenses Tracker Telegram Bot
<img align="right" src="./expenses_bot_logo.png" width="200" />

A Telegram bot for personal expense tracking, written in [Gleam](https://gleam.run) and running on the BEAM (Erlang OTP).

Try it here: [@a_track_expenses_bot](https://t.me/a_track_expenses_bot)

## Features

- **Log expenses** by sending a message: `[category] amount CURRENCY [source]`
  - e.g. `food 12.50 USD credit card` or just `50 EUR`
  - Amounts are automatically converted to USD via the [Frankfurter](https://api.frankfurter.dev) API
- **Monthly reports** - `/report` for the current month, `/report last` for the previous month
  - Grouped by category and source with USD totals
- **Multi-user** - expenses are scoped per Telegram user ID

## Requirements

- Gleam v1.15.2+
- Erlang/OTP 27+
- SQLite 3

## Configuration

Create a `.env` file (or set environment variables):

```env
EXPBOT_BOT_TOKEN=your_telegram_bot_token
EXPBOT_DB_FILE_PATH=/path/to/expenses.db
```

See `.example.env` for all available configuration options.

## Setup

**Initialize the database:**

```sh
sqlite3 expenses.db < schema.sql
```

**Run locally:**

```sh
gleam run
```

## Docker

```sh
EXPBOT_BOT_TOKEN=your_token docker compose up -d
```

The database is persisted in the `exp-tg-bot-data` Docker volume.

## Development

**Re-generate SQL query code**:

```sh
gleam run -m parrot -- --sqlite expenses.db
```

**Build an Erlang shipment:**

```sh
gleam export erlang-shipment
```

## License

MIT

