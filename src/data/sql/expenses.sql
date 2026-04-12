-- name: CreateExpense :exec
insert into
  expenses (user_tg_id, amount, currency, amount_usd, category, source, message_id)
values
  (?, ?, ?, ?, ?, ?, ?);

-- name: DeleteExpenseByUserAndMessageId :exec
delete from
  expenses
where
  user_tg_id = ? AND message_id = ?;

-- name: GetExpensesForUserByCategory :many
select category, SUM(amount_usd) as total_usd from expenses
where user_tg_id = ? AND created_at >= @date_from AND created_at < @date_to
group by category
order by total_usd desc;

-- name: GetExpensesForUserBySource :many
select source, SUM(amount_usd) as total_usd from expenses
where user_tg_id = ? AND created_at >= @date_from AND created_at < @date_to
group by source
order by total_usd desc;