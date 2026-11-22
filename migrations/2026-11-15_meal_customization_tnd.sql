-- Run ONCE on the existing database (Supabase dashboard -> SQL Editor -> paste -> Run).
-- Runs as a single transaction: all or nothing.
begin;

-- 1. Meal customization tables + access rules (same as schema.sql section 11)
create table if not exists public.menu_option_groups (
  id uuid primary key default uuid_generate_v4(),
  menu_item_id uuid not null references public.menu_items(id) on delete cascade,
  name text not null,
  kind text not null default 'choice' check (kind in ('choice', 'ingredients')),
  min_select int not null default 0 check (min_select >= 0),
  max_select int check (max_select is null or max_select >= 1),
  sort_order int not null default 0,
  created_at timestamptz not null default now()
);
create table if not exists public.menu_options (
  id uuid primary key default uuid_generate_v4(),
  group_id uuid not null references public.menu_option_groups(id) on delete cascade,
  name text not null,
  price_cents int not null default 0 check (price_cents >= 0),
  is_default boolean not null default false,
  allow_extra boolean not null default true,
  is_available boolean not null default true,
  sort_order int not null default 0
);
create table if not exists public.order_item_options (
  id uuid primary key default uuid_generate_v4(),
  order_item_id uuid not null references public.order_items(id) on delete cascade,
  option_id uuid references public.menu_options(id) on delete set null,
  group_name text not null,
  option_name text not null,
  mode text not null check (mode in ('add', 'extra', 'remove')),
  price_cents int not null default 0
);
create index if not exists idx_option_groups_item on public.menu_option_groups(menu_item_id);
create index if not exists idx_options_group on public.menu_options(group_id);
create index if not exists idx_order_item_options_item on public.order_item_options(order_item_id);

alter table public.menu_option_groups enable row level security;
alter table public.menu_options enable row level security;
alter table public.order_item_options enable row level security;

create policy "option_groups_public_read" on public.menu_option_groups for select using (true);
create policy "option_groups_owner_write" on public.menu_option_groups for all
  using (menu_item_id in (select mi.id from public.menu_items mi join public.restaurants r on r.id = mi.restaurant_id where r.owner_id = auth.uid()) or auth_role() = 'admin');
create policy "options_public_read" on public.menu_options for select using (true);
create policy "options_owner_write" on public.menu_options for all
  using (group_id in (select g.id from public.menu_option_groups g join public.menu_items mi on mi.id = g.menu_item_id join public.restaurants r on r.id = mi.restaurant_id where r.owner_id = auth.uid()) or auth_role() = 'admin');
create policy "order_item_options_visibility" on public.order_item_options for select
  using (order_item_id in (select id from public.order_items));
create policy "order_item_options_client_insert" on public.order_item_options for insert
  with check (order_item_id in (select oi.id from public.order_items oi join public.orders o on o.id = oi.order_id where o.client_id = auth.uid()));

-- 2. Currency -> TND millimes (1 TND = 1000). Old values were hundredths: x10.
update public.menu_items set price_cents = price_cents * 10;
update public.orders set subtotal_cents = subtotal_cents * 10, delivery_fee_cents = delivery_fee_cents * 10, total_cents = total_cents * 10;
update public.order_items set unit_price_cents = unit_price_cents * 10;

-- 3. Fix: order_status_history had no policies, so the order timeline was always empty.
create policy "status_history_visibility" on public.order_status_history for select
  using (order_id in (select id from public.orders));
create policy "status_history_insert" on public.order_status_history for insert
  with check (changed_by = auth.uid() and order_id in (select id from public.orders));

commit;
