-- Run in Supabase Dashboard -> SQL Editor (safe to re-run: create or replace).
-- place_order(): checkout done INSIDE the database, so the mobile app (and later the web)
-- can't tamper with prices. Same rules as web/app/client/actions.ts placeOrder():
--   * items must be available and belong to the restaurant, quantity 1..99
--   * base price = live offer price if any (offer < price and not expired), else price
--   * option rules: option must belong to the item, be available, no duplicates;
--     choice groups -> mode "add"; ingredient groups -> "remove" (free) or "extra" (if allowed)
--   * choice groups must respect min/max picks
--   * delivery fee 2.500 TND (2500 millimes)
-- Runs with the caller's permissions (RLS applies). Any error rolls everything back.
-- Pass 1 validates and prices everything; pass 2 only INSERTs (clients have no UPDATE
-- rights on order_items, so nothing is updated after insert).
--
-- p_items: [{"menuItemId": uuid, "quantity": int, "notes": text?,
--            "selections": [{"optionId": uuid, "mode": "add"|"extra"|"remove"}]}]
begin;

create or replace function public.place_order(
  p_restaurant_id uuid,
  p_address_id uuid,
  p_items jsonb,
  p_notes text default null
) returns uuid
language plpgsql
security invoker
set search_path = public
as $$
declare
  v_user uuid := auth.uid();
  v_fee constant int := 2500;
  v_order uuid;
  v_line jsonb;
  v_sel jsonb;
  v_item record;
  v_opt record;
  v_grp record;
  v_qty int;
  v_unit int;
  v_price int;
  v_mode text;
  v_line_id uuid;
  v_seen uuid[];
  v_count int;
  v_subtotal int := 0;
  v_opts jsonb;
  v_lines jsonb := '[]'::jsonb;
  v_o jsonb;
begin
  if v_user is null then
    raise exception 'Not authenticated';
  end if;
  if p_items is null or jsonb_typeof(p_items) <> 'array' or jsonb_array_length(p_items) = 0 then
    raise exception 'Cart is empty';
  end if;
  if not exists (select 1 from restaurants where id = p_restaurant_id and is_approved) then
    raise exception 'Restaurant not found.';
  end if;
  if not exists (select 1 from client_addresses where id = p_address_id and client_id = v_user) then
    raise exception 'Delivery address not found.';
  end if;

  -- ---------- Pass 1: validate + price ----------
  for v_line in select value from jsonb_array_elements(p_items) loop
    select id, name, price_cents, offer_price_cents, offer_ends_at, is_available, restaurant_id
      into v_item
      from menu_items
     where id = (v_line->>'menuItemId')::uuid;
    if not found or not v_item.is_available or v_item.restaurant_id <> p_restaurant_id then
      raise exception 'One or more items are no longer available';
    end if;

    v_qty := (v_line->>'quantity')::int;
    if v_qty is null or v_qty < 1 or v_qty > 99 then
      raise exception 'Invalid quantity';
    end if;

    -- Live discount applies to the base price only.
    v_unit := case
      when v_item.offer_price_cents is not null
       and v_item.offer_price_cents >= 0
       and v_item.offer_price_cents < v_item.price_cents
       and (v_item.offer_ends_at is null or v_item.offer_ends_at > now())
      then v_item.offer_price_cents
      else v_item.price_cents
    end;

    v_seen := '{}';
    v_opts := '[]'::jsonb;
    for v_sel in select value from jsonb_array_elements(coalesce(v_line->'selections', '[]'::jsonb)) loop
      select o.id, o.name, o.price_cents, o.is_available, o.allow_extra,
             g.name as group_name, g.kind
        into v_opt
        from menu_options o
        join menu_option_groups g on g.id = o.group_id
       where o.id = (v_sel->>'optionId')::uuid
         and g.menu_item_id = v_item.id;
      if not found or v_opt.id = any(v_seen) then
        raise exception '%: One of the selected options no longer exists. Please re-add it to your cart.', v_item.name;
      end if;
      v_seen := v_seen || v_opt.id;
      if not v_opt.is_available then
        raise exception '%: "%" is no longer available. Please re-add it to your cart.', v_item.name, v_opt.name;
      end if;

      v_mode := v_sel->>'mode';
      if not (
        (v_opt.kind = 'choice' and v_mode = 'add')
        or (v_opt.kind = 'ingredients' and (v_mode = 'remove' or (v_mode = 'extra' and v_opt.allow_extra)))
      ) then
        raise exception '%: Invalid choice for "%"', v_item.name, v_opt.name;
      end if;

      v_price := case when v_mode = 'remove' then 0 else v_opt.price_cents end;
      v_unit := v_unit + v_price;
      v_opts := v_opts || jsonb_build_object(
        'option_id', v_opt.id, 'group_name', v_opt.group_name,
        'option_name', v_opt.name, 'mode', v_mode, 'price_cents', v_price);
    end loop;

    -- Required / max picks on choice groups.
    for v_grp in
      select id, name, min_select, max_select
        from menu_option_groups
       where menu_item_id = v_item.id and kind = 'choice'
    loop
      select count(*) into v_count from menu_options where group_id = v_grp.id and id = any(v_seen);
      if v_count < v_grp.min_select then
        raise exception '%: "%" — please choose at least %', v_item.name, v_grp.name, v_grp.min_select;
      end if;
      if v_grp.max_select is not null and v_count > v_grp.max_select then
        raise exception '%: "%" — choose at most %', v_item.name, v_grp.name, v_grp.max_select;
      end if;
    end loop;

    v_subtotal := v_subtotal + v_unit * v_qty;
    v_lines := v_lines || jsonb_build_object(
      'menu_item_id', v_item.id, 'quantity', v_qty, 'unit_price_cents', v_unit,
      'notes', nullif(left(btrim(coalesce(v_line->>'notes', '')), 200), ''),
      'options', v_opts);
  end loop;

  -- ---------- Pass 2: insert ----------
  insert into orders (client_id, restaurant_id, delivery_address_id,
                      subtotal_cents, delivery_fee_cents, total_cents, notes)
  values (v_user, p_restaurant_id, p_address_id, v_subtotal, v_fee, v_subtotal + v_fee,
          nullif(left(btrim(coalesce(p_notes, '')), 500), ''))
  returning id into v_order;

  for v_line in select value from jsonb_array_elements(v_lines) loop
    v_line_id := gen_random_uuid();
    insert into order_items (id, order_id, menu_item_id, quantity, unit_price_cents, notes)
    values (v_line_id, v_order, (v_line->>'menu_item_id')::uuid, (v_line->>'quantity')::int,
            (v_line->>'unit_price_cents')::int, v_line->>'notes');

    for v_o in select value from jsonb_array_elements(v_line->'options') loop
      insert into order_item_options (order_item_id, option_id, group_name, option_name, mode, price_cents)
      values (v_line_id, (v_o->>'option_id')::uuid, v_o->>'group_name', v_o->>'option_name',
              v_o->>'mode', (v_o->>'price_cents')::int);
    end loop;
  end loop;

  insert into order_status_history (order_id, status, changed_by)
  values (v_order, 'pending', v_user);

  return v_order;
end;
$$;

revoke execute on function public.place_order(uuid, uuid, jsonb, text) from public, anon;
grant execute on function public.place_order(uuid, uuid, jsonb, text) to authenticated;

-- make the API see the new function immediately
notify pgrst, 'reload schema';

commit;
