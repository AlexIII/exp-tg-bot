import app_error.{type AppError, DbError}
import birl.{type Time}
import expenses_tg_bot/sql
import gleam/dynamic/decode
import gleam/list
import gleam/option.{type Option}
import gleam/result
import sqlight
import utils/parrot

pub type AddExpense {
  AddExpense(
    user_tg_id: Int,
    amount: Float,
    currency: String,
    amount_usd: Float,
    category: Option(String),
    source: Option(String),
  )
}

pub type ExpenseGroup {
  ExpenseGroup(group: String, total_usd: Float)
}

pub type Context {
  Context(conn: sqlight.Connection)
}

pub type GetExpensesByGroup =
  fn(Int, Time, Time) -> Result(List(ExpenseGroup), AppError)

pub type ExpensesRepo {
  ExpensesRepo(
    ctx: Context,
    add_expense: fn(AddExpense) -> Result(Nil, AppError),
    get_expenses_for_user_by_category: GetExpensesByGroup,
    get_expenses_for_user_by_source: GetExpensesByGroup,
  )
}

pub fn new(ctx: Context) -> ExpensesRepo {
  ExpensesRepo(
    ctx,
    add_expense: fn(expense) { add_expense(ctx, expense) },
    get_expenses_for_user_by_category: fn(user_tg_id, date_from, date_to) {
      get_expenses_for_user_by_category(ctx, user_tg_id, date_from, date_to)
    },
    get_expenses_for_user_by_source: fn(user_tg_id, date_from, date_to) {
      get_expenses_for_user_by_source(ctx, user_tg_id, date_from, date_to)
    },
  )
}

fn add_expense(ctx: Context, expense: AddExpense) -> Result(Nil, AppError) {
  let #(sql, with) =
    sql.create_expense(
      expense.user_tg_id,
      expense.amount,
      expense.currency,
      expense.amount_usd,
      expense.category,
      expense.source,
    )
  let with = list.map(with, parrot.to_sqlight)

  sqlight.query(sql, on: ctx.conn, with:, expecting: decode.success(""))
  |> result.map_error(fn(e) {
    DbError("Error executing query in add_expense(): " <> e.message)
  })
  |> result.map(fn(_) { Nil })
}

fn get_expenses_for_user_by_category(
  ctx: Context,
  user_tg_id: Int,
  date_from: Time,
  date_to: Time,
) -> Result(List(ExpenseGroup), AppError) {
  let #(sql, with, expecting) =
    sql.get_expenses_for_user_by_category(
      user_tg_id,
      parrot.to_sqlite_datetime(date_from),
      parrot.to_sqlite_datetime(date_to),
    )
  let with = list.map(with, parrot.to_sqlight)

  sqlight.query(sql, on: ctx.conn, with:, expecting:)
  |> result.map(fn(rows) {
    list.map(rows, fn(row) {
      ExpenseGroup(
        group: option.unwrap(row.category, "<none>"),
        total_usd: option.unwrap(row.total_usd, 0.0),
      )
    })
  })
  |> result.map_error(fn(e) {
    DbError(
      "Error executing query in get_expenses_for_user_by_category(): "
      <> e.message,
    )
  })
}

fn get_expenses_for_user_by_source(
  ctx: Context,
  user_tg_id: Int,
  date_from: Time,
  date_to: Time,
) -> Result(List(ExpenseGroup), AppError) {
  let #(sql, with, expecting) =
    sql.get_expenses_for_user_by_source(
      user_tg_id,
      parrot.to_sqlite_datetime(date_from),
      parrot.to_sqlite_datetime(date_to),
    )
  let with = list.map(with, parrot.to_sqlight)

  sqlight.query(sql, on: ctx.conn, with:, expecting:)
  |> result.map(fn(rows) {
    list.map(rows, fn(row) {
      ExpenseGroup(
        group: option.unwrap(row.source, "<none>"),
        total_usd: option.unwrap(row.total_usd, 0.0),
      )
    })
  })
  |> result.map_error(fn(e) {
    DbError(
      "Error executing query in get_expenses_for_user_by_source(): "
      <> e.message,
    )
  })
}
