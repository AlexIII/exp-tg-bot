import app_error.{type AppError}
import birl.{type Time}
import data/expenses_repo.{type ExpensesRepo}
import gleam/float
import gleam/list
import gleam/result
import gleam/string
import services/action_service.{type ActionService}
import services/currency_service.{type CurrencyService}
import services/types.{type MessageAttrs}

pub type Context {
  Context(
    action_service: ActionService,
    expenses_repo: ExpensesRepo,
    currency_service: CurrencyService,
  )
}

pub type ReportGrouping {
  ByCategory
  BySource
}

pub type ReportPeriod {
  ThisMonth
  LastMonth
}

pub type ExpenseGroup =
  expenses_repo.ExpenseGroup

pub type ExpensesReport {
  ExpensesReport(
    by: ReportGrouping,
    period: ReportPeriod,
    from: Time,
    to: Time,
    expenses: List(ExpenseGroup),
    total_usd: Float,
  )
}

pub type ExpensesService {
  ExpensesService(
    ctx: Context,
    process_user_message: fn(String, MessageAttrs) -> Result(Nil, AppError),
    get_report_for_user: fn(Int, ReportGrouping, ReportPeriod) ->
      Result(ExpensesReport, AppError),
    delete_expense_by_user_and_message_id: fn(Int, Int) -> Result(Nil, AppError),
  )
}

pub fn new(ctx: Context) -> ExpensesService {
  ExpensesService(
    ctx:,
    process_user_message: fn(message, attrs) {
      process_user_message(ctx, message, attrs)
    },
    get_report_for_user: fn(user_tg_id, by, period) {
      get_report_for_user(ctx, user_tg_id, by, period)
    },
    delete_expense_by_user_and_message_id: fn(user_tg_id, message_id) {
      delete_expense_by_user_and_message_id(ctx, user_tg_id, message_id)
    },
  )
}

fn process_user_message(
  ctx: Context,
  message: String,
  attrs: MessageAttrs,
) -> Result(Nil, AppError) {
  ctx.action_service.parse(message)
  |> result.try(fn(action) {
    case action {
      action_service.Expense(amount, currency, category, source) -> {
        ctx.currency_service.get_rate(currency, "USD")
        |> result.try(fn(rate) {
          let amount_usd = amount *. rate
          ctx.expenses_repo.add_expense(expenses_repo.AddExpense(
            user_tg_id: attrs.from_id,
            amount:,
            currency:,
            amount_usd:,
            category:,
            source:,
            message_id: attrs.id,
          ))
        })
      }
      // other_action ->
      //   Error(app_error.AppError(
      //     "Unsupported action type" <> string.inspect(other_action),
      //   ))
    }
  })
}

fn get_report_for_user(
  ctx: Context,
  user_tg_id: Int,
  by: ReportGrouping,
  period: ReportPeriod,
) -> Result(ExpensesReport, AppError) {
  let #(from, to) = case period {
    ThisMonth -> {
      let to = birl.now()
      let from =
        birl.unix_epoch()
        |> birl.set_day(birl.Day(
          birl.get_day(to).year,
          birl.get_day(to).month,
          1,
        ))
      #(from, to)
    }
    LastMonth -> {
      let now = birl.now()
      let to =
        birl.unix_epoch()
        |> birl.set_day(birl.Day(
          birl.get_day(now).year,
          birl.get_day(now).month,
          1,
        ))

      let #(from_year, from_month) = {
        let cur_year = birl.get_day(now).year
        let cur_month = birl.get_day(now).month

        case cur_month {
          1 -> #(cur_year - 1, 12)
          m -> #(cur_year, m - 1)
        }
      }

      let from =
        birl.unix_epoch()
        |> birl.set_day(birl.Day(from_year, from_month, 1))
      #(from, to)
    }
  }

  let get_expenses = case by {
    ByCategory -> ctx.expenses_repo.get_expenses_for_user_by_category
    BySource -> ctx.expenses_repo.get_expenses_for_user_by_source
  }

  use expenses <- result.try(get_expenses(user_tg_id, from, to))
  let total_usd =
    list.fold(expenses, 0.0, fn(acc, expense) { acc +. expense.total_usd })

  Ok(ExpensesReport(by:, period:, from:, to:, expenses:, total_usd:))
}

pub fn report_to_text(report: ExpensesReport) -> String {
  let by = case report.by {
    ByCategory -> "category"
    BySource -> "source"
  }

  let period = case report.period {
    ThisMonth -> "this month"
    LastMonth -> "last month"
  }

  let rows = case report.expenses {
    [] -> ""
    expenses ->
      list.fold(expenses, "", fn(acc, expense) {
        let row =
          expense.group
          <> " ..... "
          <> float.to_string(float.to_precision(expense.total_usd, 2))
        case acc {
          "" -> row
          _ -> acc <> "\n" <> row
        }
      })
  }

  "By: "
  <> by
  <> "\n"
  <> "Period: "
  <> period
  <> "\n"
  <> "From: "
  <> { birl.to_date_string(report.from) |> string.slice(0, 10) }
  <> "\n"
  <> "To: "
  <> { birl.to_date_string(report.to) |> string.slice(0, 10) }
  <> "\n"
  <> "Total USD: "
  <> float.to_string(float.to_precision(report.total_usd, 2))
  <> case rows {
    "" -> ""
    _ -> "\n\n" <> "Group ..... USD\n" <> "-----------------------\n" <> rows
  }
}

fn delete_expense_by_user_and_message_id(
  ctx: Context,
  user_tg_id: Int,
  message_id: Int,
) -> Result(Nil, AppError) {
  ctx.expenses_repo.delete_expense_by_user_and_message_id(
    user_tg_id,
    message_id,
  )
}
