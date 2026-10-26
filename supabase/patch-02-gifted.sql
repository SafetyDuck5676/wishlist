-- Патч 02: отметка «подарено».
-- Выполните целиком в Supabase → SQL Editor → Run.

alter table items add column if not exists gifted boolean not null default false;

-- Админ и так может менять items (политика items_write), отдельные права не нужны.
