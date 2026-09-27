-- ============================================================
-- AidPulsate — Migration 005: Fix Existing Schema + Full RLS
--
-- ⚠ PASTE THIS ENTIRE FILE into the Supabase SQL Editor and
--   click "Run".  It is fully idempotent — safe to run more
--   than once.
--
-- What it does:
--   1. Adds missing constraints & indexes to existing tables
--   2. Creates the updated_at trigger function
--   3. Attaches the updated_at trigger to profiles
--   4. Creates the current_user_role() helper (used by RLS)
--   5. Drops & recreates all RLS policies cleanly
--   6. Creates the handle_new_user trigger (auto-creates profile on signup)
--   7. Creates the SMS payload parser trigger
--   8. Grants correct permissions to authenticated / anon
--   9. Enables Realtime on sos_events & location_pings
--  10. Creates promote_to_admin / demote_from_admin helpers
-- ============================================================

-- ── 1. Missing constraint on responders ─────────────────────
-- The dumped schema was missing the unique pair constraint.
alter table public.responders
  drop constraint if exists responders_event_admin_unique;

alter table public.responders
  add constraint responders_event_admin_unique
  unique (event_id, admin_id);

-- ── 2. Indexes ───────────────────────────────────────────────
create index if not exists idx_profiles_role
  on public.profiles (role);

create index if not exists idx_devices_user_id
  on public.devices (user_id);

create index if not exists idx_sos_events_user_id
  on public.sos_events (user_id);

create index if not exists idx_sos_events_status
  on public.sos_events (status)
  where status = 'active';

create index if not exists idx_sos_events_started_at
  on public.sos_events (started_at desc);

create index if not exists idx_location_pings_event_time
  on public.location_pings (event_id, created_at desc);

create index if not exists idx_location_pings_user_id
  on public.location_pings (user_id);

create index if not exists idx_responders_admin_id
  on public.responders (admin_id);

create index if not exists idx_responders_event_id
  on public.responders (event_id);

create index if not exists idx_sms_inbox_unprocessed
  on public.sms_inbox (received_at)
  where processed = false;

-- ── 3. updated_at maintenance function ──────────────────────
create or replace function public.set_updated_at()
returns trigger
language plpgsql
security invoker
set search_path = ''
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists trg_profiles_updated_at on public.profiles;
create trigger trg_profiles_updated_at
  before update on public.profiles
  for each row execute function public.set_updated_at();

-- ── 4. current_user_role() helper ───────────────────────────
-- Used by every RLS policy that checks for 'admin'.
-- Reads from public.profiles (written only by the SECURITY DEFINER
-- trigger — clients cannot forge their own role).
create or replace function public.current_user_role()
returns text
language sql
stable
security invoker
set search_path = ''
as $$
  select role from public.profiles where id = (select auth.uid());
$$;

-- ── 5. Row Level Security ────────────────────────────────────
-- Drop all existing policies first so re-running is safe.

-- profiles
alter table public.profiles enable row level security;
drop policy if exists "profiles: owner select"      on public.profiles;
drop policy if exists "profiles: owner update"      on public.profiles;
drop policy if exists "profiles: admin select all"  on public.profiles;

create policy "profiles: owner select"
  on public.profiles for select to authenticated
  using ( (select auth.uid()) = id );

create policy "profiles: owner update"
  on public.profiles for update to authenticated
  using ( (select auth.uid()) = id )
  with check ( (select auth.uid()) = id );

-- Prevent clients from changing their own role via update.
create policy "profiles: admin select all"
  on public.profiles for select to authenticated
  using ( public.current_user_role() = 'admin' );

-- devices
alter table public.devices enable row level security;
drop policy if exists "devices: owner select"     on public.devices;
drop policy if exists "devices: owner insert"     on public.devices;
drop policy if exists "devices: owner update"     on public.devices;
drop policy if exists "devices: owner delete"     on public.devices;
drop policy if exists "devices: admin select all" on public.devices;

create policy "devices: owner select"
  on public.devices for select to authenticated
  using ( (select auth.uid()) = user_id );

create policy "devices: owner insert"
  on public.devices for insert to authenticated
  with check ( (select auth.uid()) = user_id );

create policy "devices: owner update"
  on public.devices for update to authenticated
  using ( (select auth.uid()) = user_id )
  with check ( (select auth.uid()) = user_id );

create policy "devices: owner delete"
  on public.devices for delete to authenticated
  using ( (select auth.uid()) = user_id );

create policy "devices: admin select all"
  on public.devices for select to authenticated
  using ( public.current_user_role() = 'admin' );

-- sos_events
alter table public.sos_events enable row level security;
drop policy if exists "sos_events: victim insert"     on public.sos_events;
drop policy if exists "sos_events: victim select own" on public.sos_events;
drop policy if exists "sos_events: victim update own" on public.sos_events;
drop policy if exists "sos_events: admin select all"  on public.sos_events;
drop policy if exists "sos_events: admin update"      on public.sos_events;

create policy "sos_events: victim insert"
  on public.sos_events for insert to authenticated
  with check ( (select auth.uid()) = user_id );

create policy "sos_events: victim select own"
  on public.sos_events for select to authenticated
  using ( (select auth.uid()) = user_id );

create policy "sos_events: victim update own"
  on public.sos_events for update to authenticated
  using ( (select auth.uid()) = user_id )
  with check ( (select auth.uid()) = user_id );

create policy "sos_events: admin select all"
  on public.sos_events for select to authenticated
  using ( public.current_user_role() = 'admin' );

create policy "sos_events: admin update"
  on public.sos_events for update to authenticated
  using ( public.current_user_role() = 'admin' )
  with check ( public.current_user_role() = 'admin' );

-- location_pings
alter table public.location_pings enable row level security;
drop policy if exists "location_pings: victim insert"     on public.location_pings;
drop policy if exists "location_pings: victim select own" on public.location_pings;
drop policy if exists "location_pings: admin select all"  on public.location_pings;

create policy "location_pings: victim insert"
  on public.location_pings for insert to authenticated
  with check ( (select auth.uid()) = user_id );

create policy "location_pings: victim select own"
  on public.location_pings for select to authenticated
  using ( (select auth.uid()) = user_id );

create policy "location_pings: admin select all"
  on public.location_pings for select to authenticated
  using ( public.current_user_role() = 'admin' );

-- responders
alter table public.responders enable row level security;
drop policy if exists "responders: admin insert"          on public.responders;
drop policy if exists "responders: admin select"          on public.responders;
drop policy if exists "responders: admin update"          on public.responders;
drop policy if exists "responders: admin delete"          on public.responders;
drop policy if exists "responders: victim read own event" on public.responders;

create policy "responders: admin insert"
  on public.responders for insert to authenticated
  with check ( public.current_user_role() = 'admin' );

create policy "responders: admin select"
  on public.responders for select to authenticated
  using ( public.current_user_role() = 'admin' );

create policy "responders: admin update"
  on public.responders for update to authenticated
  using ( public.current_user_role() = 'admin' )
  with check ( public.current_user_role() = 'admin' );

create policy "responders: admin delete"
  on public.responders for delete to authenticated
  using ( public.current_user_role() = 'admin' );

create policy "responders: victim read own event"
  on public.responders for select to authenticated
  using (
    exists (
      select 1 from public.sos_events e
      where e.id = responders.event_id
        and e.user_id = (select auth.uid())
    )
  );

-- sms_inbox — no client access; service_role only (bypasses RLS entirely)
alter table public.sms_inbox enable row level security;

-- ── 6. Auto-create profile on signup ────────────────────────
-- Reads role from user_metadata set by the Flutter signup screen.
-- SECURITY DEFINER so it can bypass RLS to insert into profiles.
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_role text;
  v_name text;
begin
  v_role := coalesce(new.raw_user_meta_data ->> 'role', 'victim');
  if v_role not in ('victim', 'admin') then
    v_role := 'victim';
  end if;
  v_name := coalesce(new.raw_user_meta_data ->> 'full_name', '');

  insert into public.profiles (id, full_name, role)
  values (new.id, v_name, v_role)
  on conflict (id) do nothing;

  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- ── 7. SMS payload parser trigger ───────────────────────────
create or replace function public.process_sms_payload()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_parts  text[];
  v_ref_id text;
  v_lat    double precision;
  v_lng    double precision;
  v_seq    integer;
  v_event  record;
begin
  v_parts := string_to_array(new.raw_body, '|');

  if array_length(v_parts, 1) <> 7 or v_parts[1] <> 'AP' then
    update public.sms_inbox
    set processed = true, processed_at = now(),
        parse_error = 'Invalid format: expected AP|ref|ts|lat|lng|seq|hmac'
    where id = new.id;
    return new;
  end if;

  v_ref_id := v_parts[2];
  v_lat    := v_parts[4]::double precision;
  v_lng    := v_parts[5]::double precision;
  v_seq    := v_parts[6]::integer;

  select * into v_event
  from public.sos_events
  where ref_id like '%' || v_ref_id and status = 'active'
  limit 1;

  if v_event is null then
    update public.sms_inbox
    set processed = true, processed_at = now(),
        parse_error = 'No active sos_event for ref_id: ' || v_ref_id
    where id = new.id;
    return new;
  end if;

  insert into public.location_pings (event_id, user_id, lat, lng, source, seq)
  values (v_event.id, v_event.user_id, v_lat, v_lng, 'sms_payload', v_seq)
  on conflict do nothing;

  update public.sms_inbox
  set processed = true, processed_at = now(), parse_error = null
  where id = new.id;

  return new;
exception when others then
  update public.sms_inbox
  set processed = true, processed_at = now(), parse_error = sqlerrm
  where id = new.id;
  return new;
end;
$$;

drop trigger if exists on_sms_inbox_insert on public.sms_inbox;
create trigger on_sms_inbox_insert
  after insert on public.sms_inbox
  for each row execute function public.process_sms_payload();

-- ── 8. Grants ────────────────────────────────────────────────
grant usage on schema public to authenticated;

grant select, insert, update         on public.profiles        to authenticated;
grant select, insert, update, delete on public.devices         to authenticated;
grant select, insert, update         on public.sos_events      to authenticated;
grant select, insert                 on public.location_pings  to authenticated;
grant select, insert, update, delete on public.responders      to authenticated;
-- sms_inbox intentionally excluded — service_role only

revoke all on public.profiles        from anon;
revoke all on public.devices         from anon;
revoke all on public.sos_events      from anon;
revoke all on public.location_pings  from anon;
revoke all on public.responders      from anon;
revoke all on public.sms_inbox       from anon;

-- ── 9. Realtime ──────────────────────────────────────────────
-- Guard against "already a member" error — idempotent.
do $$
begin
  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'sos_events'
  ) then
    alter publication supabase_realtime add table public.sos_events;
  end if;

  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'location_pings'
  ) then
    alter publication supabase_realtime add table public.location_pings;
  end if;
end;
$$;

-- ── 10. Admin management helpers ─────────────────────────────
-- Usage (SQL Editor only — never from the Flutter app):
--   select public.promote_to_admin('admin@example.com');
--   select public.demote_from_admin('admin@example.com');
--   select * from public.admin_users;

drop view if exists public.admin_users;
create view public.admin_users
  with (security_invoker = true)
as
select p.id, u.email, p.full_name, p.phone, p.created_at
from public.profiles p
join auth.users u on u.id = p.id
where p.role = 'admin';

create or replace function public.promote_to_admin(p_email text)
returns text
language plpgsql
security definer
set search_path = ''
as $$
declare v_id uuid;
begin
  select id into v_id from auth.users
  where email = lower(trim(p_email)) limit 1;

  if v_id is null then
    return 'ERROR: no user with email ' || p_email;
  end if;

  insert into public.profiles (id, role)
  values (v_id, 'admin')
  on conflict (id) do update set role = 'admin', updated_at = now();

  return 'OK: ' || p_email || ' promoted to admin (' || v_id || ')';
end;
$$;

create or replace function public.demote_from_admin(p_email text)
returns text
language plpgsql
security definer
set search_path = ''
as $$
declare v_id uuid;
begin
  select id into v_id from auth.users
  where email = lower(trim(p_email)) limit 1;

  if v_id is null then
    return 'ERROR: no user with email ' || p_email;
  end if;

  update public.profiles
  set role = 'victim', updated_at = now()
  where id = v_id;

  return 'OK: ' || p_email || ' demoted to victim (' || v_id || ')';
end;
$$;

revoke execute on function public.promote_to_admin(text)  from public, authenticated, anon;
revoke execute on function public.demote_from_admin(text) from public, authenticated, anon;
