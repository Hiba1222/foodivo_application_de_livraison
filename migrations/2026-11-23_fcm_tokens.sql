-- FCM device tokens for push notifications
create table if not exists public.fcm_tokens (
  id         bigserial primary key,
  user_id    uuid        not null references auth.users(id) on delete cascade,
  token      text        not null,
  platform   text        not null default 'android',
  updated_at timestamptz not null default now(),
  unique (user_id, token)
);

alter table public.fcm_tokens enable row level security;

create policy "Users manage their own FCM tokens"
  on public.fcm_tokens
  for all
  using  (auth.uid() = user_id)
  with check (auth.uid() = user_id);
