-- Run ONCE in Supabase Dashboard -> SQL Editor (safe to re-run).
-- Adds discounts / special offers to menu items.
--   offer_price_cents : discounted price in millimes (NULL = no discount).
--                       Only counts while it is lower than price_cents.
--   offer_label       : short tag shown on the card, e.g. "Promo Ramadan".
--   offer_ends_at     : offer stops automatically after this time (NULL = no end).
--   is_featured       : show the item in the "Special offers" section (works with or without a discount).
begin;

alter table public.menu_items
  add column if not exists offer_price_cents int,
  add column if not exists offer_label text,
  add column if not exists offer_ends_at timestamptz,
  add column if not exists is_featured boolean not null default false;

alter table public.menu_items drop constraint if exists menu_items_offer_price_check;
alter table public.menu_items
  add constraint menu_items_offer_price_check
  check (offer_price_cents is null or offer_price_cents >= 0);

alter table public.menu_items drop constraint if exists menu_items_offer_label_length;
alter table public.menu_items
  add constraint menu_items_offer_label_length
  check (offer_label is null or char_length(offer_label) <= 40);

-- Fast lookup of items currently on offer (browse page "Hot deals").
create index if not exists idx_menu_items_offers
  on public.menu_items (restaurant_id)
  where offer_price_cents is not null or is_featured;

commit;
