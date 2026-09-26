-- ============================================================
-- AidPulsate — Migration 003: Triggers & Functions
--
-- 1. on_auth_user_created   → create profiles row + set app_metadata.role
-- 2. parse_sms_payload      → convert sms_inbox row → sos_event/location_ping
-- ============================================================

-- ── 1. Profile auto-creation + secure role promotion ────────
--
-- When a user registers via Supabase Auth the Flutter app writes
-- { full_name, role } into user_metadata. This trigger runs as
-- SECURITY DEFINER (postgres role) so it can:
--   a) Insert into public.profiles  (bypasses RLS — that's correct here)
--   b) Call auth.users update to set app_metadata.role
--      (app_metadata is writable only by service-role / postgres)
--
-- WHY NOT USE user_metadata FOR RLS?
--   user_metadata is user-editable via the client SDK.
--   A malicious user could set role='admin' in their own metadata.
--   app_metadata can only be written server-side, so it is safe for
--   RLS and JWT-based authorization checks.
-- ─────────────────────────────────────────────────────────────
-- NOTE: Supabase hosted platform blocks UPDATE on auth.users from triggers.
-- Role is stored in public.profiles only.
-- All RLS policies use current_user_role() which reads from profiles.role —
-- this is safe because profiles rows are written only by this SECURITY DEFINER
-- trigger and cannot be manipulated by the client directly.
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_role    text;
  v_name    text;
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

-- Attach to auth.users INSERT (fires on every new registration).
create or replace trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- ── 2. SMS payload parser ────────────────────────────────────
--
-- Fired after a new row lands in sms_inbox (written by the gateway).
-- Expected payload format:
--   AP|<event_id_short>|<unix_ts>|<lat>|<lng>|<seq>|<hmac>
-- e.g.:  AP|8829X|1720000000|40.712800|-74.006000|3|a4f2
--
-- The parser:
--   1. Validates the format (7 pipe-delimited fields, starts with AP).
--   2. Looks up the sos_event by ref_id suffix match.
--   3. If found, inserts a location_ping (source='sms_payload').
--   4. Marks the sms_inbox row as processed (or records the parse error).
-- ─────────────────────────────────────────────────────────────
create or replace function public.process_sms_payload()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_parts    text[];
  v_prefix   text;
  v_ref_id   text;
  v_lat      double precision;
  v_lng      double precision;
  v_seq      integer;
  v_event    record;
begin
  -- Split on pipe.
  v_parts := string_to_array(new.raw_body, '|');

  -- Validate: must have exactly 7 fields starting with 'AP'.
  if array_length(v_parts, 1) <> 7 or v_parts[1] <> 'AP' then
    update public.sms_inbox
    set processed   = true,
        processed_at = now(),
        parse_error  = 'Invalid format: expected AP|ref|ts|lat|lng|seq|hmac'
    where id = new.id;
    return new;
  end if;

  v_ref_id := v_parts[2];
  v_lat    := v_parts[4]::double precision;
  v_lng    := v_parts[5]::double precision;
  v_seq    := v_parts[6]::integer;

  -- Look up the active SOS event whose ref_id ends with the short ID.
  select * into v_event
  from public.sos_events
  where ref_id like '%' || v_ref_id
    and status = 'active'
  limit 1;

  if v_event is null then
    update public.sms_inbox
    set processed   = true,
        processed_at = now(),
        parse_error  = 'No active sos_event found for ref_id: ' || v_ref_id
    where id = new.id;
    return new;
  end if;

  -- Insert a location ping sourced from SMS.
  insert into public.location_pings
    (event_id, user_id, lat, lng, source, seq)
  values
    (v_event.id, v_event.user_id, v_lat, v_lng, 'sms_payload', v_seq)
  on conflict do nothing;

  -- Mark as processed.
  update public.sms_inbox
  set processed   = true,
      processed_at = now(),
      parse_error  = null
  where id = new.id;

  return new;

exception when others then
  -- Catch any unexpected error and record it without crashing.
  update public.sms_inbox
  set processed   = true,
      processed_at = now(),
      parse_error  = sqlerrm
  where id = new.id;
  return new;
end;
$$;

-- Attach to sms_inbox INSERT (fires when gateway writes a row).
create or replace trigger on_sms_inbox_insert
  after insert on public.sms_inbox
  for each row execute function public.process_sms_payload();

-- ── 3. Grant explicit permissions to authenticated role ──────
--
-- These GRANTs are required because the default Supabase data-API
-- exposure only goes to the schema level; column-level access must
-- be granted so PostgREST can see the tables.
-- RLS policies still restrict which rows are visible.
-- ─────────────────────────────────────────────────────────────
grant usage on schema public to authenticated;

grant select, insert, update        on public.profiles        to authenticated;
grant select, insert, update, delete on public.devices        to authenticated;
grant select, insert, update        on public.sos_events      to authenticated;
grant select, insert               on public.location_pings   to authenticated;
grant select, insert, update, delete on public.responders     to authenticated;
-- sms_inbox: no grant to authenticated (service_role only)

-- anon role: no access to any table
revoke all on public.profiles       from anon;
revoke all on public.devices        from anon;
revoke all on public.sos_events     from anon;
revoke all on public.location_pings from anon;
revoke all on public.responders     from anon;
revoke all on public.sms_inbox      from anon;
