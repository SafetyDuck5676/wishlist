-- Схема вишлиста. Выполните целиком в Supabase → SQL Editor.

create table if not exists items (
  id uuid primary key default gen_random_uuid(),
  title text,
  url text,
  image_url text,
  price text,
  store text,
  rating smallint default 0 check (rating between 0 and 5),
  note text,
  category text,
  gifted boolean not null default false,
  created_at timestamptz default now()
);

create table if not exists reservations (
  item_id uuid primary key references items(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  name text,
  created_at timestamptz default now()
);

create table if not exists profiles (
  user_id uuid primary key references auth.users(id) on delete cascade,
  is_admin boolean not null default false
);

-- Автосоздание профиля при регистрации пользователя
create or replace function public.handle_new_user()
returns trigger language plpgsql security definer as $$
begin
  insert into public.profiles (user_id) values (new.id)
  on conflict (user_id) do nothing;
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- Проверка админа без рекурсии RLS (security definer)
create or replace function public.is_admin()
returns boolean language sql security definer stable as $$
  select coalesce((select is_admin from public.profiles where user_id = auth.uid()), false);
$$;

-- Row Level Security
alter table items enable row level security;
alter table reservations enable row level security;
alter table profiles enable row level security;

-- items: читают все; создаёт/меняет/удаляет только админ
drop policy if exists items_select on items;
create policy items_select on items for select using (true);

drop policy if exists items_write on items;
create policy items_write on items for all
  using (public.is_admin()) with check (public.is_admin());

-- reservations: читают только авторизованные не-админы (автор брони НЕ видит);
-- создаёт/удаляет пользователь только свою бронь
drop policy if exists reservations_select on reservations;
create policy reservations_select on reservations for select
  using (auth.uid() is not null and not public.is_admin());

drop policy if exists reservations_insert on reservations;
create policy reservations_insert on reservations for insert
  with check (auth.uid() = user_id);

drop policy if exists reservations_delete on reservations;
create policy reservations_delete on reservations for delete
  using (auth.uid() = user_id);

-- Админ не должен знать, КТО забронировал (сюрприз), но должен видеть, ЧТО занято.
-- security definer обходит RLS, поэтому возвращаем только id и только админу.
create or replace function public.reserved_item_ids()
returns setof uuid
language sql
security definer
stable
as $$
  select r.item_id from public.reservations r where public.is_admin();
$$;

grant execute on function public.reserved_item_ids() to anon, authenticated;

-- profiles: пользователь видит свой профиль; админ видит и меняет все
drop policy if exists profiles_select on profiles;
create policy profiles_select on profiles for select
  using (auth.uid() = user_id or public.is_admin());

drop policy if exists profiles_update on profiles;
create policy profiles_update on profiles for update
  using (public.is_admin());

-- Storage: публичный bucket для картинок айтемов
insert into storage.buckets (id, name, public)
values ('wishlist-images', 'wishlist-images', true)
on conflict (id) do nothing;

drop policy if exists wishlist_images_read on storage.objects;
create policy wishlist_images_read on storage.objects for select
  using (bucket_id = 'wishlist-images');

drop policy if exists wishlist_images_write on storage.objects;
create policy wishlist_images_write on storage.objects for insert
  with check (bucket_id = 'wishlist-images' and public.is_admin());

drop policy if exists wishlist_images_delete on storage.objects;
create policy wishlist_images_delete on storage.objects for delete
  using (bucket_id = 'wishlist-images' and public.is_admin());

-- Сделать себя админом (выполнить после первого входа, подставив свой uid):
-- update profiles set is_admin = true where user_id = '<ваш uid>';
