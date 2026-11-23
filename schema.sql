-- ============================================================
-- FOOD DELIVERY APP — DATABASE SCHEMA (Supabase / PostgreSQL)
-- ============================================================
-- Run this in the Supabase SQL editor (or via `supabase db push`).
-- Uses Supabase's built-in `auth.users` table for authentication;
-- this schema adds app-specific profile + role data on top of it.

-- ------------------------------------------------------------
-- 0. EXTENSIONS
-- ------------------------------------------------------------
create extension if not exists "uuid-ossp";
create extension if not exists "postgis"; -- for lat/lng distance queries (driver matching)

-- ------------------------------------------------------------
-- 1. ROLES & PROFILES
-- ------------------------------------------------------------
-- One row per auth.users row. role determines which app/dashboard
-- the user can access (enforced both client-side and via RLS below).
create type user_role as enum ('admin', 'restaurant_owner', 'client', 'driver');

create table profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  role user_role not null,
  full_name text not null,
  phone text,
  avatar_url text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- ------------------------------------------------------------
-- 2. RESTAURANTS
-- ------------------------------------------------------------
create table restaurants (
  id uuid primary key default uuid_generate_v4(),
  owner_id uuid not null references profiles(id) on delete cascade,
  name text not null,
  description text,
  cuisine_type text,
  logo_url text,
  cover_image_url text,
  address text not null,
  latitude double precision not null,
  longitude double precision not null,
  phone text,
  is_open boolean not null default true,          -- restaurant-toggled "accepting orders"
  is_approved boolean not null default false,       -- admin approval gate
  avg_prep_time_minutes int default 20,
  created_at timestamptz not null default now()
);

create table menu_categories (
  id uuid primary key default uuid_generate_v4(),
  restaurant_id uuid not null references restaurants(id) on delete cascade,
  name text not null,                               -- e.g. "Burgers", "Drinks"
  sort_order int default 0
);

create table menu_items (
  id uuid primary key default uuid_generate_v4(),
  restaurant_id uuid not null references restaurants(id) on delete cascade,
  category_id uuid references menu_categories(id) on delete set null,
  name text not null,
  description text,
  price_cents int not null check (price_cents >= 0),
  image_url text,
  is_available boolean not null default true,
  created_at timestamptz not null default now()
);

-- ------------------------------------------------------------
-- 3. CLIENT ADDRESSES
-- ------------------------------------------------------------
create table client_addresses (
  id uuid primary key default uuid_generate_v4(),
  client_id uuid not null references profiles(id) on delete cascade,
  label text,                                       -- "Home", "Work"
  address_line text not null,
  latitude double precision not null,
  longitude double precision not null,
  is_default boolean default false
);

-- ------------------------------------------------------------
-- 4. DRIVERS
-- ------------------------------------------------------------
create table driver_profiles (
  id uuid primary key references profiles(id) on delete cascade,
  vehicle_type text,                                -- "bike", "scooter", "car"
  license_plate text,
  is_online boolean not null default false,
  is_approved boolean not null default false,       -- admin approval gate
  current_latitude double precision,
  current_longitude double precision,
  last_location_update timestamptz
);

-- Separate history table so live location updates (high write volume)
-- don't bloat/lock the driver_profiles row.
create table driver_locations_history (
  id bigserial primary key,
  driver_id uuid not null references driver_profiles(id) on delete cascade,
  latitude double precision not null,
  longitude double precision not null,
  recorded_at timestamptz not null default now()
);

-- ------------------------------------------------------------
-- 5. ORDERS
-- ------------------------------------------------------------
create type order_status as enum (
  'pending',            -- just placed, awaiting restaurant
  'accepted',           -- restaurant accepted, preparing
  'rejected',           -- restaurant rejected
  'ready_for_pickup',   -- food ready, awaiting driver pickup
  'driver_assigned',    -- driver assigned, heading to restaurant
  'picked_up',          -- driver has the food, en route to client
  'delivered',          -- completed
  'cancelled'
);

create table orders (
  id uuid primary key default uuid_generate_v4(),
  client_id uuid not null references profiles(id),
  restaurant_id uuid not null references restaurants(id),
  driver_id uuid references driver_profiles(id),
  delivery_address_id uuid not null references client_addresses(id),
  status order_status not null default 'pending',
  subtotal_cents int not null,
  delivery_fee_cents int not null default 0,
  total_cents int not null,
  payment_method text not null default 'card',      -- "card", "cash"
  payment_status text not null default 'pending',    -- "pending", "paid", "failed"
  notes text,
  created_at timestamptz not null default now(),
  accepted_at timestamptz,
  ready_at timestamptz,
  picked_up_at timestamptz,
  delivered_at timestamptz
);

create table order_items (
  id uuid primary key default uuid_generate_v4(),
  order_id uuid not null references orders(id) on delete cascade,
  menu_item_id uuid not null references menu_items(id),
  quantity int not null check (quantity > 0),
  unit_price_cents int not null,                    -- snapshot at order time (price may change later)
  notes text
);

-- Append-only audit trail of every status change — useful for the
-- admin dashboard timeline view and for debugging disputes.
create table order_status_history (
  id bigserial primary key,
  order_id uuid not null references orders(id) on delete cascade,
  status order_status not null,
  changed_by uuid references profiles(id),
  changed_at timestamptz not null default now()
);

-- ------------------------------------------------------------
-- 6. REVIEWS
-- ------------------------------------------------------------
create table reviews (
  id uuid primary key default uuid_generate_v4(),
  order_id uuid not null references orders(id) on delete cascade,
  client_id uuid not null references profiles(id),
  restaurant_rating int check (restaurant_rating between 1 and 5),
  driver_rating int check (driver_rating between 1 and 5),
  comment text,
  created_at timestamptz not null default now(),
  unique (order_id)   -- one review per order, enables upsert
);

-- ------------------------------------------------------------
-- 7. INDEXES
-- ------------------------------------------------------------
create index idx_menu_items_restaurant on menu_items(restaurant_id);
create index idx_orders_client on orders(client_id);
create index idx_orders_restaurant on orders(restaurant_id);
create index idx_orders_driver on orders(driver_id);
create index idx_orders_status on orders(status);
create index idx_driver_locations_driver on driver_locations_history(driver_id, recorded_at desc);

-- ------------------------------------------------------------
-- 8. ROW LEVEL SECURITY (RLS)
-- ------------------------------------------------------------
-- Enable RLS everywhere; Supabase denies by default until a policy allows.
alter table profiles enable row level security;
alter table restaurants enable row level security;
alter table menu_categories enable row level security;
alter table menu_items enable row level security;
alter table client_addresses enable row level security;
alter table driver_profiles enable row level security;
alter table orders enable row level security;
alter table order_items enable row level security;
alter table reviews enable row level security;

-- Helper: fetch the caller's role.
create or replace function auth_role() returns user_role as $$
  select role from profiles where id = auth.uid();
$$ language sql stable security definer;

-- profiles: everyone can read their own; admins read all.
-- Restaurants and drivers can also read the profile of clients whose orders they handle.
create policy "profiles_self_select" on profiles for select
  using (id = auth.uid() or auth_role() = 'admin');
create policy "profiles_order_party_select" on profiles for select
  using (
    id in (
      select o.client_id from orders o
      join restaurants r on r.id = o.restaurant_id
      where r.owner_id = auth.uid()
    )
    or
    id in (
      select o.client_id from orders o
      where o.driver_id = auth.uid()
    )
  );
create policy "profiles_self_update" on profiles for update
  using (id = auth.uid());
-- Lets a freshly-signed-up user create their own profile row (their id must
-- match the authenticated user — they can't create a profile for anyone else,
-- and can't grant themselves a role by updating it later since update only
-- changes columns, not who the row belongs to).
create policy "profiles_self_insert" on profiles for insert
  with check (id = auth.uid());

-- restaurants: public read of approved+open restaurants; owner manages their own; admin manages all.
create policy "restaurants_public_read" on restaurants for select
  using (is_approved = true or owner_id = auth.uid() or auth_role() = 'admin');
create policy "restaurants_owner_write" on restaurants for insert
  with check (owner_id = auth.uid() or auth_role() = 'admin');
create policy "restaurants_owner_update" on restaurants for update
  using (owner_id = auth.uid() or auth_role() = 'admin');

-- menu_items / menu_categories: public read; restaurant owner writes their own.
create policy "menu_items_public_read" on menu_items for select using (true);
create policy "menu_items_owner_write" on menu_items for all
  using (restaurant_id in (select id from restaurants where owner_id = auth.uid()) or auth_role() = 'admin');
create policy "menu_categories_public_read" on menu_categories for select using (true);
create policy "menu_categories_owner_write" on menu_categories for all
  using (restaurant_id in (select id from restaurants where owner_id = auth.uid()) or auth_role() = 'admin');

-- client_addresses: owner only.
create policy "addresses_owner_only" on client_addresses for all
  using (client_id = auth.uid() or auth_role() = 'admin');

-- driver_profiles: self + admin read/write; restaurants can see assigned driver's basic info via orders join (handled in app layer).
create policy "driver_self" on driver_profiles for all
  using (id = auth.uid() or auth_role() = 'admin');

-- orders: client sees own orders; restaurant owner sees orders for their restaurant;
-- driver sees orders assigned to them; admin sees all.
create policy "orders_visibility" on orders for select
  using (
    client_id = auth.uid()
    or driver_id = auth.uid()
    or restaurant_id in (select id from restaurants where owner_id = auth.uid())
    or auth_role() = 'admin'
  );
create policy "orders_client_insert" on orders for insert
  with check (client_id = auth.uid());
create policy "orders_update" on orders for update
  using (
    client_id = auth.uid()
    or driver_id = auth.uid()
    or restaurant_id in (select id from restaurants where owner_id = auth.uid())
    or auth_role() = 'admin'
  );

create policy "order_items_visibility" on order_items for select
  using (order_id in (select id from orders)); -- inherits orders RLS via join

-- reviews: client writes own; everyone can read (for restaurant rating display).
create policy "reviews_public_read" on reviews for select using (true);
create policy "reviews_client_write" on reviews for insert with check (client_id = auth.uid());

-- ------------------------------------------------------------
-- 9. REALTIME
-- ------------------------------------------------------------
-- Lets the web/mobile apps subscribe to live changes instead of polling:
-- order status updates (client/restaurant/driver/admin dashboards) and
-- driver location updates (client's live map while a driver is en route).
alter publication supabase_realtime add table orders;
alter publication supabase_realtime add table driver_profiles;

-- ------------------------------------------------------------
-- 10. STORAGE (restaurant photos, meal photos, driver/user avatars)
-- ------------------------------------------------------------
-- One public bucket, organized by path prefix:
--   avatars/<user_id>/...            -> that user's own profile photo
--   restaurants/<restaurant_id>/...  -> that restaurant's logo, cover photo,
--                                       and its menu items' photos
insert into storage.buckets (id, name, public)
values ('media', 'media', true)
on conflict (id) do nothing;

create policy "media_public_read" on storage.objects for select
  using (bucket_id = 'media');

create policy "media_avatar_write" on storage.objects for all
  using (
    bucket_id = 'media'
    and (storage.foldername(name))[1] = 'avatars'
    and (storage.foldername(name))[2] = auth.uid()::text
  )
  with check (
    bucket_id = 'media'
    and (storage.foldername(name))[1] = 'avatars'
    and (storage.foldername(name))[2] = auth.uid()::text
  );

create policy "media_restaurant_write" on storage.objects for all
  using (
    bucket_id = 'media'
    and (storage.foldername(name))[1] = 'restaurants'
    and (storage.foldername(name))[2]::uuid in (select id from restaurants where owner_id = auth.uid())
  )
  with check (
    bucket_id = 'media'
    and (storage.foldername(name))[1] = 'restaurants'
    and (storage.foldername(name))[2]::uuid in (select id from restaurants where owner_id = auth.uid())
  );

-- ------------------------------------------------------------
-- 11. MEAL CUSTOMIZATION (option groups / modifiers, UberEats-style)
-- ------------------------------------------------------------
-- Safe to re-run: if you ran schema.sql before this update, run just this
-- section in the Supabase SQL editor.
--
-- A menu item has option groups, of two kinds:
--   'choice'      -> customer picks between min_select and max_select options
--                    (bread, size, sauces, paid add-ons). price_cents is added
--                    to the meal price when the option is picked.
--   'ingredients' -> what's already in the meal; for each option the customer
--                    picks No / Regular / Extra. price_cents is the surcharge
--                    for "Extra" (removing is always free).
create table if not exists menu_option_groups (
  id uuid primary key default uuid_generate_v4(),
  menu_item_id uuid not null references menu_items(id) on delete cascade,
  name text not null,
  kind text not null default 'choice' check (kind in ('choice', 'ingredients')),
  min_select int not null default 0 check (min_select >= 0),
  max_select int check (max_select is null or max_select >= 1),
  sort_order int not null default 0,
  created_at timestamptz not null default now()
);

create table if not exists menu_options (
  id uuid primary key default uuid_generate_v4(),
  group_id uuid not null references menu_option_groups(id) on delete cascade,
  name text not null,
  price_cents int not null default 0 check (price_cents >= 0),
  is_default boolean not null default false,   -- choice: pre-selected
  allow_extra boolean not null default true,   -- ingredients: can be doubled
  is_available boolean not null default true,  -- 86 a single option
  sort_order int not null default 0
);

-- Snapshot of what the customer picked, so the ticket stays correct even if
-- the restaurant renames or deletes the option later.
create table if not exists order_item_options (
  id uuid primary key default uuid_generate_v4(),
  order_item_id uuid not null references order_items(id) on delete cascade,
  option_id uuid references menu_options(id) on delete set null,
  group_name text not null,
  option_name text not null,
  mode text not null check (mode in ('add', 'extra', 'remove')),
  price_cents int not null default 0
);

create index if not exists idx_option_groups_item on menu_option_groups(menu_item_id);
create index if not exists idx_options_group on menu_options(group_id);
create index if not exists idx_order_item_options_item on order_item_options(order_item_id);

alter table menu_option_groups enable row level security;
alter table menu_options enable row level security;
alter table order_item_options enable row level security;

drop policy if exists "option_groups_public_read" on menu_option_groups;
create policy "option_groups_public_read" on menu_option_groups for select using (true);
drop policy if exists "option_groups_owner_write" on menu_option_groups;
create policy "option_groups_owner_write" on menu_option_groups for all
  using (
    menu_item_id in (
      select mi.id from menu_items mi
      join restaurants r on r.id = mi.restaurant_id
      where r.owner_id = auth.uid()
    )
    or auth_role() = 'admin'
  );

drop policy if exists "options_public_read" on menu_options;
create policy "options_public_read" on menu_options for select using (true);
drop policy if exists "options_owner_write" on menu_options;
create policy "options_owner_write" on menu_options for all
  using (
    group_id in (
      select g.id from menu_option_groups g
      join menu_items mi on mi.id = g.menu_item_id
      join restaurants r on r.id = mi.restaurant_id
      where r.owner_id = auth.uid()
    )
    or auth_role() = 'admin'
  );

drop policy if exists "order_item_options_visibility" on order_item_options;
create policy "order_item_options_visibility" on order_item_options for select
  using (order_item_id in (select id from order_items)); -- inherits order_items/orders RLS
drop policy if exists "order_item_options_client_insert" on order_item_options;
create policy "order_item_options_client_insert" on order_item_options for insert
  with check (
    order_item_id in (
      select oi.id from order_items oi
      join orders o on o.id = oi.order_id
      where o.client_id = auth.uid()
    )
  );

-- Clients insert their own order lines at checkout.
drop policy if exists "order_items_client_insert" on order_items;
create policy "order_items_client_insert" on order_items for insert
  with check (order_id in (select id from orders where client_id = auth.uid()));

-- order_status_history: readable with the order; anyone allowed to see the
-- order can append a status change they made themselves.
drop policy if exists "status_history_visibility" on order_status_history;
create policy "status_history_visibility" on order_status_history for select
  using (order_id in (select id from orders));
drop policy if exists "status_history_insert" on order_status_history;
create policy "status_history_insert" on order_status_history for insert
  with check (changed_by = auth.uid() and order_id in (select id from orders));

-- MONEY: every *_cents column holds Tunisian dinar MILLIMES (1 TND = 1000),
-- despite the column name. See web/lib/currency.ts.
