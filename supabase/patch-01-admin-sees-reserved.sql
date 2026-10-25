-- Патч для уже настроенного проекта.
-- Выполните один раз в Supabase → SQL Editor.
--
-- Что делает: разрешает админу видеть ФАКТ брони (какие айтемы заняты),
-- не раскрывая, кто именно забронировал. Нужно для метки «Забронировано».
--
-- Без этого патча приложение работает как раньше — админ просто не видит меток.

create or replace function public.reserved_item_ids()
returns setof uuid
language sql
security definer
stable
as $$
  select r.item_id from public.reservations r where public.is_admin();
$$;

grant execute on function public.reserved_item_ids() to anon, authenticated;
