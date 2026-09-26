-- ============================================================
-- AidPulsate — Migration 002: Row Level Security
-- Roles:  victim  → owns their own data
--         admin   → read-all, assign responders, resolve events
--         service_role → gateway writes, trigger writes (bypasses RLS)
-- ============================================================
-- RLS is enforced via public.profiles.role which is populated
-- by the trigger in 003_triggers.sql from app_metadata.role.
-- app_metadata is set server-side only and cannot be spoofed
-- by a client JWT, unlike user_metadata.
-- ============================================================

-- Helper: returns the role stored in profiles for the current user.
-- Using a stable function avoids re-evaluating the sub-select per row.
create or replace function public.current_user_role()
returns text
language sql
stable
security invoker
set search_path = ''
as $$
  select role from public.profiles where id = (select auth.uid());
$$;

-- ── 1. profiles ─────────────────────────────────────────────
alter table public.profiles enable row level security;

-- Victims/users: read and update their own row only.
create policy "profiles: owner select"
  on public.profiles
  for select
  to authenticated
  using ( (select auth.uid()) = id );

create policy "profiles: owner update"
  on public.profiles
  for update
  to authenticated
  using ( (select auth.uid()) = id )
  with check ( (select auth.uid()) = id );

-- Admins: read all profiles (needed for victim lookup in dashboard).
create policy "profiles: admin select all"
  on public.profiles
  for select
  to authenticated
  using ( public.current_user_role() = 'admin' );

-- New profile row is inserted by the trigger (service_role context),
-- so no INSERT policy for authenticated is needed.

-- ── 2. devices ──────────────────────────────────────────────
alter table public.devices enable row level security;

-- Owner: full CRUD on their own device tokens.
create policy "devices: owner select"
  on public.devices
  for select
  to authenticated
  using ( (select auth.uid()) = user_id );

create policy "devices: owner insert"
  on public.devices
  for insert
  to authenticated
  with check ( (select auth.uid()) = user_id );

create policy "devices: owner update"
  on public.devices
  for update
  to authenticated
  using ( (select auth.uid()) = user_id )
  with check ( (select auth.uid()) = user_id );

create policy "devices: owner delete"
  on public.devices
  for delete
  to authenticated
  using ( (select auth.uid()) = user_id );

-- Admins: read all device records (needed to dispatch push/SMS).
create policy "devices: admin select all"
  on public.devices
  for select
  to authenticated
  using ( public.current_user_role() = 'admin' );

-- ── 3. sos_events ───────────────────────────────────────────
alter table public.sos_events enable row level security;

-- Victim: create and view their own events.
create policy "sos_events: victim insert"
  on public.sos_events
  for insert
  to authenticated
  with check ( (select auth.uid()) = user_id );

create policy "sos_events: victim select own"
  on public.sos_events
  for select
  to authenticated
  using ( (select auth.uid()) = user_id );

-- Victim: can only resolve/cancel their own active event.
create policy "sos_events: victim update own"
  on public.sos_events
  for update
  to authenticated
  using ( (select auth.uid()) = user_id )
  with check ( (select auth.uid()) = user_id );

-- Admin: read all events, update status (resolve/cancel).
create policy "sos_events: admin select all"
  on public.sos_events
  for select
  to authenticated
  using ( public.current_user_role() = 'admin' );

create policy "sos_events: admin update"
  on public.sos_events
  for update
  to authenticated
  using ( public.current_user_role() = 'admin' )
  with check ( public.current_user_role() = 'admin' );

-- ── 4. location_pings ───────────────────────────────────────
alter table public.location_pings enable row level security;

-- Victim: insert and read their own pings.
create policy "location_pings: victim insert"
  on public.location_pings
  for insert
  to authenticated
  with check ( (select auth.uid()) = user_id );

create policy "location_pings: victim select own"
  on public.location_pings
  for select
  to authenticated
  using ( (select auth.uid()) = user_id );

-- Admin: read all pings (for map view and timeline).
create policy "location_pings: admin select all"
  on public.location_pings
  for select
  to authenticated
  using ( public.current_user_role() = 'admin' );

-- ── 5. responders ───────────────────────────────────────────
alter table public.responders enable row level security;

-- Admin: full CRUD on responder assignments.
create policy "responders: admin insert"
  on public.responders
  for insert
  to authenticated
  with check ( public.current_user_role() = 'admin' );

create policy "responders: admin select"
  on public.responders
  for select
  to authenticated
  using ( public.current_user_role() = 'admin' );

create policy "responders: admin update"
  on public.responders
  for update
  to authenticated
  using ( public.current_user_role() = 'admin' )
  with check ( public.current_user_role() = 'admin' );

create policy "responders: admin delete"
  on public.responders
  for delete
  to authenticated
  using ( public.current_user_role() = 'admin' );

-- Victim: read which admins are assigned to their event.
create policy "responders: victim read own event"
  on public.responders
  for select
  to authenticated
  using (
    exists (
      select 1 from public.sos_events e
      where e.id = responders.event_id
        and e.user_id = (select auth.uid())
    )
  );

-- ── 6. sms_inbox ────────────────────────────────────────────
-- sms_inbox is written by the SMS gateway using service_role.
-- Authenticated clients (victim/admin) have NO access.
-- Admins can read raw SMS for debugging via a separate view (optional).
alter table public.sms_inbox enable row level security;

-- No policies: table is only accessible via service_role (bypasses RLS).
-- service_role is used by the gateway server and Postgres triggers only —
-- it is never embedded in any mobile app.

-- ── Realtime publications ────────────────────────────────────
-- Enable Realtime for the tables that need live updates.
-- Supabase Realtime respects RLS: subscribers only receive rows
-- their session is permitted to see.
begin;
  -- sos_events: admins subscribe to see new/updated events.
  alter publication supabase_realtime add table public.sos_events;
  -- location_pings: admins subscribe per event_id for live tracking.
  alter publication supabase_realtime add table public.location_pings;
commit;
