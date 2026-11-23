-- Allow one review per order (enables upsert with onConflict: 'order_id')
alter table reviews
  add constraint reviews_order_id_unique unique (order_id);

-- RLS policies for reviews
create policy "Client can insert their own review"
  on reviews for insert
  to authenticated
  with check (client_id = auth.uid());

create policy "Client can update their own review"
  on reviews for update
  to authenticated
  using (client_id = auth.uid());

create policy "Anyone can read reviews"
  on reviews for select
  to authenticated
  using (true);

-- Allow clients to cancel their own pending orders
create policy "Client can cancel own pending orders"
  on orders for update
  to authenticated
  using (
    client_id = auth.uid()
    and status = 'pending'
  )
  with check (
    client_id = auth.uid()
    and status = 'cancelled'
  );
