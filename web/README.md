# Foodivo — Web (Next.js + Supabase)

Role-based web platform for the food delivery app. One login, routed by role:
`admin`, `restaurant_owner`, `client`, `driver`. **All four roles are now
fully built** on the web platform.

To try another role: create a user in Supabase Auth, then insert a `profiles`
row with the matching `role` for that user id (same pattern as the admin user
below). A restaurant owner or driver lands on an onboarding form first;
approve them from the Admin panel before they can do anything (restaurant
shows up to clients, driver can go online).

## Setup

1. Create a Supabase project at https://supabase.com.
2. In the SQL editor, run `../schema.sql` (from the project root) to create
   all tables, enums, and Row Level Security policies.
3. **Turn off email confirmation** (Supabase dashboard → Authentication →
   Providers → Email → toggle off "Confirm email"). Self-signup inserts the
   user's `profiles` row immediately after `signUp()` returns a session —
   if email confirmation is required, there's no session yet and that insert
   is blocked. Fine to leave off for a dev/portfolio project; for a real
   production app you'd add email verification back with a server-side
   step instead.
4. Create your first **admin** user (there's no self-signup option for
   admin — on purpose, see below):
   - Supabase dashboard → Authentication → Add user (set email + password).
   - Then in the SQL editor:
     ```sql
     insert into profiles (id, role, full_name)
     values ('<the-user-id-from-auth>', 'admin', 'Your Name');
     ```
5. Copy `.env.local.example` to `.env.local` and fill in your project URL + anon key
   (Supabase dashboard → Project Settings → API).
6. Install and run:
   ```bash
   npm install
   npm run dev
   ```
7. Visit `http://localhost:3000`, log in with the admin account you created.

## How restaurants, drivers and clients are added

**Self-signup, at `/signup`.** Anyone can create an account and pick their
role (Client, Restaurant, Driver):
- `client` → goes straight to the Browse page, fully usable immediately.
- `restaurant_owner` → lands on the restaurant onboarding form, then shows
  up in the Admin → Restaurants list as "Pending" until an admin approves it.
  It won't be visible to clients, and can't receive orders, until approved.
- `driver` → lands on the driver onboarding form, then shows up in
  Admin → Drivers as "Pending" until an admin approves it. Can't go online
  or accept deliveries until approved.

**Admin accounts are not self-signup** — there's deliberately no "Admin"
option on the signup page. Create additional admins the same way as the
first one (step 4 above): add the user in Supabase Auth, then insert their
`profiles` row with `role = 'admin'` via SQL. This keeps the highest-trust
role out of a public signup form.

## What's built so far

- Shared login (`/login`) for all 4 roles, redirecting by `profiles.role`.
- `middleware.ts` enforces role-based access: a client can't open `/admin`, etc.
- **Admin panel** (`/admin`):
  - Overview — live counts (orders, active orders, pending approvals, revenue)
  - Restaurants — approve / suspend restaurant signups
  - Drivers — approve / suspend driver signups
  - Orders — view every order on the platform
  - Users — list of all registered users
- **Restaurant panel** (`/restaurant`):
  - Onboarding — a new restaurant_owner creates their restaurant profile before anything else unlocks
  - Overview — today's pending/active order counts, today's revenue, open/closed toggle
  - Menu — add categories, add/delete items, toggle item availability on/off
  - Orders — see incoming orders with line items, Accept / Reject new orders, mark accepted orders "ready for pickup" (status transitions are validated server-side in `actions.ts`, not just hidden in the UI)
  - Settings — edit restaurant profile (name, cuisine, description, address)

- **Client panel** (`/client`):
  - Browse — open, approved restaurants
  - Restaurant menu — categorized items, add to cart (cart held in React context, one restaurant at a time)
  - Cart — adjust quantities, see subtotal/fee/total
  - Checkout — pick or add a delivery address, place order (prices are re-verified server-side in `actions.ts`, never trusted from the client)
  - Orders — order history + a per-order tracking timeline (pending → accepted → ready → driver assigned → picked up → delivered)

- **Driver panel** (`/driver`):
  - Onboarding — new drivers register vehicle type/plate, then wait for admin approval
  - Overview — online/offline toggle (only works once approved), today's active/delivered/earnings stats
  - Available deliveries — unassigned `ready_for_pickup` orders anyone online can claim; `acceptDelivery` in `actions.ts` uses a conditional update (`status = ready_for_pickup AND driver_id IS NULL`) so two drivers can't claim the same order in a race
  - My deliveries — active delivery with pickup/dropoff addresses and client contact info, "Picked up" then "Mark as delivered" buttons
  - History — completed deliveries with fee earned

## Full loop is now walkable end to end

Restaurant owner adds a menu → client orders → restaurant accepts & marks
ready → a driver accepts the delivery, picks it up, marks it delivered →
client sees "Delivered" on their tracking page → admin sees the completed
order and the revenue in their overview.

## Polish pass: realtime + live driver location

- **Live updates everywhere** — `components/RealtimeRefresher.tsx` subscribes
  to Postgres changes on the `orders` table (and `driver_profiles` for
  location) and refreshes the page automatically. It's dropped into: admin
  overview + orders, restaurant overview + orders, client orders list +
  order detail, driver available + my-deliveries. No more manually
  reloading to see a new order or a status change.
- **Driver live location** — while a driver is toggled online,
  `app/driver/LocationTracker.tsx` watches the browser's geolocation and
  reports it to the server every time it changes meaningfully. On the
  client's order tracking page, once a driver is assigned and en route,
  an embedded OpenStreetMap view shows their current position — updating
  live via the same realtime subscription.
- Required: in the Supabase SQL editor, re-run the bottom of `schema.sql`
  (section 9, `alter publication supabase_realtime add table ...`) if you
  ran the schema before this update — it enables Realtime on `orders` and
  `driver_profiles`.
- Note: browsers only allow geolocation on `https://` or `localhost`, so
  this works out of the box in dev and once deployed, no extra config.

## Photos, phone numbers & address collection

- **Restaurant photos** — Settings has a logo upload (circle) and a cover
  photo upload (wide); the cover photo shows on the client's Browse page
  and restaurant detail page.
- **Meal photos** — each row in the restaurant's Menu page has its own
  photo uploader; shown as a thumbnail to clients browsing that restaurant.
- **Driver photo** — Driver → Settings has a profile photo uploader; shown
  to the client on their order tracking page once a driver is assigned.
- **Phone numbers** — collected at signup for every role, and editable
  later: Restaurant Settings (business phone), Driver Settings (personal
  phone), Client Settings (personal phone).
- **Client address** — if a client has no saved address (or somehow no
  phone), they're prompted for it right after login, before they can
  browse. Addresses are also manageable afterward in Client → Settings
  (add, delete, set default).

All photo uploads go through a Supabase Storage bucket called `media`
(public read, write restricted by Row Level Security — a restaurant owner
can only write to `restaurants/<their-restaurant-id>/...`, and everyone can
only write to their own `avatars/<their-id>/...`). **If you ran `schema.sql`
before this update, re-run just the bottom "STORAGE" section** (search for
`insert into storage.buckets`) to create the bucket and its policies.

## Meal customization (UberEats-style options)

- **Restaurant → Menu → click an item (or "+ Customize")** opens its
  customization page. Creating a new item takes you there automatically.
- Each item can have **option groups** of two kinds:
  - **Choice list**: the customer picks from options, with min/max rules.
    Examples: bread (required, pick 1), sauces (up to 2), paid extras (any number).
    Each option can add to the price and can be pre-selected.
  - **Ingredients**: what's already in the meal. The customer picks
    **No / Regular / Extra** for each one. "Extra" can cost money; removing is free.
- One-click **quick-start templates** (bread, ingredients, extras, sauces,
  size, side, drink), **copy options from another item**, reorder groups,
  mark single options "Sold out", and **Preview as customer**.
- Clients tap an item to open a popup with Required/Optional badges, a live
  price, special instructions and quantity. Identical setups merge into one cart line.
- At checkout the server recalculates every price and re-checks every rule
  from the database (`lib/menu-options.ts`, shared with the popup).
  Each chosen option is saved in `order_item_options`, so the restaurant's
  order ticket shows "No onion · Extra cheese (+1.000 TND)". It stays correct
  even if the menu changes later.
- **If you ran `schema.sql` before this update, re-run just section 11
  ("MEAL CUSTOMIZATION")**. It is safe to re-run.

## Next up (web)

Still missing compared to a full UberEats-style app — worth prioritizing
based on what matters most for your project:
- **Ratings & reviews** — `reviews` table already exists in the schema with
  no UI yet. Would add: a prompt after delivery for the client to rate
  restaurant + driver, and average ratings shown on restaurant cards.
- **Search / filter on Browse** — by name or cuisine type.
- **Order cancellation** — a client cancelling a `pending` order before the
  restaurant responds.
- **Driver earnings history** / payout tracking beyond the simple History tab.
- **Push notifications** — currently everything is in-app realtime; no
  email/SMS/push when an order status changes.

## Next platform

Once you're happy with the web app, the same schema and role model carry
straight over to the **Flutter Android app** — same Supabase project, same
tables, same RLS policies, just a different UI layer.
