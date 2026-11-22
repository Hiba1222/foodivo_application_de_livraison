-- Run in Supabase Dashboard -> SQL Editor (safe to re-run).
-- Problem: client_addresses is readable only by its owner (and admins), so drivers saw an
-- empty "Dropoff" on Available deliveries and My deliveries.
-- Fix: an approved driver may READ a delivery address only when it belongs to
--   * an order waiting for a driver (ready_for_pickup, not yet assigned), or
--   * an order they are currently delivering (driver_assigned / picked_up).
-- Read-only: drivers still can't change or list anyone's other addresses.
begin;

drop policy if exists addresses_driver_read on public.client_addresses;

create policy addresses_driver_read on public.client_addresses
  for select
  to authenticated
  using (
    exists (
      select 1
        from public.orders o
       where o.delivery_address_id = client_addresses.id
         and (
           (o.driver_id = auth.uid() and o.status in ('driver_assigned', 'picked_up'))
           or (
             o.status = 'ready_for_pickup'
             and o.driver_id is null
             and exists (select 1 from public.driver_profiles d where d.id = auth.uid() and d.is_approved)
           )
         )
    )
  );

commit;
