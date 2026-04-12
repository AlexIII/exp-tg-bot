create table
  if not exists expenses (
    id integer primary key autoincrement,
    user_tg_id int not null,
    amount real not null,
    currency text not null,
    amount_usd real not null,
    category text,
    source text,
    created_at text not null default (datetime ('now'))
  );

create index if not exists idx_expenses_user_tg_id on expenses (user_tg_id);

create index if not exists idx_expenses_user_created_at on expenses (user_tg_id, created_at);

create index if not exists idx_expenses_category on expenses (category);

create index if not exists idx_expenses_source on expenses (source);

create index if not exists idx_expenses_created_at on expenses (created_at);