-- Run ONCE in Supabase Dashboard -> SQL Editor (safe to re-run: create or replace).
-- Lets a client see the name + phone of the driver delivering THEIR order,
-- only while the delivery is in progress. Profiles stay private otherwise.
begin;

create or replace function public.get_order_driver(p_order_id uuid)
returns table (
  full_name text,
  phone text,
  avatar_url text,
  vehicle_type text,
  license_plate text,
  current_latitude double precision,
  current_longitude double precision
)
language sql
stable
security definer
set search_path = public
as $$
  select p.full_name, p.phone, p.avatar_url,
         d.vehicle_type, d.license_plate,
         d.current_latitude, d.current_longitude
  from public.orders o
  join public.driver_profiles d on d.id = o.driver_id
  join public.profiles p on p.id = d.id
  where o.id = p_order_id
    and o.status in ('driver_assigned', 'picked_up')
    and (
      o.client_id = auth.uid()
      or o.restaurant_id in (select r.id from public.restaurants r where r.owner_id = auth.uid())
      or auth_role() = 'admin'
    );
$$;

revoke execute on function public.get_order_driver(uuid) from public, anon;
grant execute on function public.get_order_driver(uuid) to authenticated;

commit;
