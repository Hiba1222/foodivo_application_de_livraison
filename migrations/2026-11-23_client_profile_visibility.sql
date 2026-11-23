-- Allow restaurants and drivers to read the profile (name, phone) of clients
-- whose orders they are handling. Without this policy, the profiles join in
-- orders queries returns null because the existing policy only lets users read
-- their own profile.

drop policy if exists "profiles_order_party_select" on profiles;
create policy "profiles_order_party_select" on profiles for select
  using (
    -- The viewer is the restaurant owner of an order placed by this client.
    id in (
      select o.client_id from orders o
      join restaurants r on r.id = o.restaurant_id
      where r.owner_id = auth.uid()
    )
    or
    -- The viewer is the driver assigned to an order placed by this client.
    id in (
      select o.client_id from orders o
      where o.driver_id = auth.uid()
    )
  );
