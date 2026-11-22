# Foodivo — Food Delivery Platform

A full-stack food delivery platform with four role-based experiences —
**Admin**, **Restaurant**, **Client**, and **Driver** — available on both a
**web app** (Next.js) and an **Android app** (Flutter), sharing one Supabase
backend. One login routes each person straight to the dashboard built for
their role, on whichever platform they're using, with Row Level Security
enforcing on the backend that a client can never see another client's data,
a restaurant can only manage its own menu and orders, and so on.

Built as a university/portfolio project to demonstrate full-stack
architecture: real authentication, a normalized relational schema with
proper access control, live realtime updates, file storage, and a complete
order lifecycle from checkout to delivery.

## What it does

- **Admin** — approve/suspend restaurants and drivers, view every order and
  user on the platform, see live revenue and order stats.
- **Restaurant** — onboard with a profile (logo, cover photo, phone,
  address), manage a categorized menu with photos per item, accept or
  reject incoming orders, mark them ready for pickup.
- **Client** — browse approved restaurants with photos, build a cart,
  check out with a saved delivery address, track an order live through
  every status (accepted → ready → picked up → delivered), see the
  assigned driver's name, phone, photo, and live location on a map.
- **Driver** — onboard with vehicle info, phone, and a profile photo; go
  online/offline; claim available deliveries; update status through pickup
  and delivery; see delivery history and earnings.

Live updates (new orders, status changes, driver location) push to every
relevant screen via Supabase Realtime — no manual refreshing needed.

## Tech stack

- **Web:** Next.js 14 (App Router), React, TypeScript, Tailwind CSS
- **Android:** Flutter / Dart — same four role-based experiences as the
  web app, as a native mobile client
- **Backend:** Supabase — Postgres database, Auth, Row Level Security,
  Realtime subscriptions, Storage (for restaurant/meal/profile photos).
  One backend serves both the web app and the Android app, so a restaurant
  managing its menu on the web and a driver accepting a delivery on
  Android are working against the exact same data, instantly, through
  the same RLS policies.

## Architecture highlights

- **One schema, four roles.** A single `profiles` table with a `role`
  enum drives access control everywhere — in the Next.js middleware (route
  protection) and in Postgres Row Level Security policies (data
  protection), so access control isn't just a UI concern.
- **Server Actions for all mutations**, with critical business rules
  enforced server-side, not just hidden in the UI — e.g. order status can
  only move through valid transitions, and checkout re-verifies menu
  prices against the database rather than trusting the client.
- **Race-condition-safe delivery claiming** — two drivers tapping "Accept"
  on the same order at the same instant can't both win it; the claim is a
  conditional database update, not a check-then-write.

## Project structure

```
schema.sql              Full Postgres schema: tables, enums, RLS policies, storage buckets
web/                     Next.js web app (all 4 roles)
  app/
    admin/               Admin dashboard
    restaurant/           Restaurant dashboard
    client/              Client-facing app
    driver/               Driver dashboard
  lib/                   Supabase clients, shared types, helpers
  components/            Shared UI (dashboard shell, image uploader, realtime refresher)
android/                 Flutter Android app (all 4 roles, same Supabase backend)
```

## Getting started

**Backend (required for either app):** run `schema.sql` in a Supabase
project first — both the web app and the Android app connect to the same
project.

- **Web:** see [`web/README.md`](web/README.md) for full setup
  (environment variables, running locally, and how new
  restaurants/drivers/clients get onboarded and approved).
- **Android:** see `android/README.md` for Flutter setup and running on a
  device/emulator (coming as the Android app is built out).

## Status

**Web:** feature-complete for the core order flow across all four roles
(auth, menus with photos, ordering, live tracking, realtime updates).
**Android:** in progress, building out the same four roles against the
same backend. Not yet built on either platform: ratings/reviews UI,
search/filtering, push notifications.

## License

MIT (or your preferred license — add a LICENSE file).
