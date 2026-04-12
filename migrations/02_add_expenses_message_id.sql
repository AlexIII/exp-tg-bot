alter table expenses
add column message_id text null;

create index if not exists idx_expenses_message_id on expenses (message_id);
