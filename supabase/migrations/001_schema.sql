-- ============================================================
-- AidPulsate — Migration 001: Schema
-- Tables: profiles, devices, sos_events, location_pings,
--         responders, sms_inbox
-- ============================================================

-- ── Extensions ─────────────────────────────────────────────
-- uuid_generate_v4() for primary keys
create extension if not exists "uuid-ossp";

-- ── 1. profiles ────────────────────────────────────────────
-- One row per auth.users entry.
-- Role is stored here (server-side) after being promoted from
-- user_metadata by the trigger in 003_triggers.sql.
create table if not exists public.profiles (
  id           uuid primary key references auth.users(id) on delete cascade,
  full_name    text not null default '',
  role         text not null default 'victim'
                 check (role in ('victim', 'admin')),
  phone        text,
  avatar_url   text,
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now()
);

comment on table public.profiles is
  'Extended user profile. role is promoted from auth.users user_metadata by trigger.';

-- ── 2. devices ─────────────────────────────────────────────
-- Registered push-notification / SMS gateway tokens per user.
create table if not exists public.devices (
  id           uuid primary key default uuid_generate_v4(),
  user_id      uuid not null references public.profiles(id) on delete cascade,
  fcm_token    text,                  -- Firebase Cloud Messaging (push)
  phone_number text,                  -- for SMS fallback
  platform     text not null default 'android'
                 check (platform in ('android', 'ios', 'web')),
  last_seen_at timestamptz not null default now(),
  created_at   timestamptz not null default now()
);

comment on table public.devices is
  'Device tokens for push notifications and SMS fallback numbers.';

-- ── 3. sos_events ──────────────────────────────────────────
-- One row per SOS activation. Status lifecycle:
--   active → resolved | cancelled
create table if not exists public.sos_events (
  id              uuid primary key default uuid_generate_v4(),
  user_id         uuid not null references public.profiles(id) on delete cascade,
  status          text not null default 'active'
                    check (status in ('active', 'resolved', 'cancelled')),
  transmission    text not null default 'online'
                    check (transmission in ('online', 'sms', 'mixed')),
  -- Location at the moment of activation (snapshot).
  initial_lat     double precision,
  initial_lng     double precision,
  -- Timestamps.
  started_at      timestamptz not null default now(),
  resolved_at     timestamptz,
  -- Reference ID shown in the UI (e.g. AP-8829-X).
  ref_id          text not null
                    default 'AP-' || upper(substring(uuid_generate_v4()::text, 1, 5)),
  -- Optional note added on resolution.
  resolution_note text
);

comment on table public.sos_events is
  'Each SOS activation by a victim. Admins subscribe via Realtime.';

-- ── 4. location_pings ──────────────────────────────────────
-- One row per GPS update during an active SOS.
create table if not exists public.location_pings (
  id          uuid primary key default uuid_generate_v4(),
  event_id    uuid not null references public.sos_events(id) on delete cascade,
  user_id     uuid not null references public.profiles(id) on delete cascade,
  lat         double precision not null,
  lng         double precision not null,
  accuracy    double precision,         -- metres
  altitude    double precision,         -- metres
  speed       double precision,         -- m/s
  heading     double precision,         -- degrees
  source      text not null default 'gps'
                check (source in ('gps', 'network', 'sms_payload')),
  seq         integer not null default 0,  -- sequence within the event
  created_at  timestamptz not null default now()
);

comment on table public.location_pings is
  'GPS pings captured during an active SOS event.';

-- ── 5. responders ──────────────────────────────────────────
-- Junction: which admin is handling which SOS event.
create table if not exists public.responders (
  id          uuid primary key default uuid_generate_v4(),
  event_id    uuid not null references public.sos_events(id) on delete cascade,
  admin_id    uuid not null references public.profiles(id) on delete cascade,
  assigned_at timestamptz not null default now(),
  status      text not null default 'assigned'
                check (status in ('assigned', 'on_route', 'arrived', 'closed')),
  notes       text,
  unique (event_id, admin_id)
);

comment on table public.responders is
  'Tracks which admin responders are assigned to an SOS event.';

-- ── 6. sms_inbox ───────────────────────────────────────────
-- Raw inbound SMS messages received by the SMS gateway.
-- The gateway writes here (service_role); a database function
-- parses and upserts the corresponding sos_event / location_ping.
create table if not exists public.sms_inbox (
  id             uuid primary key default uuid_generate_v4(),
  raw_body       text not null,
  from_number    text not null,
  gateway_ref    text,                  -- gateway-assigned delivery ID
  received_at    timestamptz not null default now(),
  processed      boolean not null default false,
  processed_at   timestamptz,
  parse_error    text                   -- set if parsing failed
);

comment on table public.sms_inbox is
  'Raw inbound SMS from the gateway. Processed into sos_events/location_pings.';

-- ============================================================
-- Indexes
-- ============================================================

-- profiles — role-based lookups
create index if not exists idx_profiles_role
  on public.profiles (role);

-- devices — all devices for a user
create index if not exists idx_devices_user_id
  on public.devices (user_id);

-- sos_events — victim's events, active events
create index if not exists idx_sos_events_user_id
  on public.sos_events (user_id);

create index if not exists idx_sos_events_status
  on public.sos_events (status)
  where status = 'active';           -- partial: only active events queried at scale

create index if not exists idx_sos_events_started_at
  on public.sos_events (started_at desc);

-- location_pings — time-ordered pings per event (the hottest query)
create index if not exists idx_location_pings_event_time
  on public.location_pings (event_id, created_at desc);

-- location_pings — user-scoped RLS check
create index if not exists idx_location_pings_user_id
  on public.location_pings (user_id);

-- responders — admin's assignments
create index if not exists idx_responders_admin_id
  on public.responders (admin_id);

create index if not exists idx_responders_event_id
  on public.responders (event_id);

-- sms_inbox — unprocessed rows (gateway processor polls this)
create index if not exists idx_sms_inbox_unprocessed
  on public.sms_inbox (received_at)
  where processed = false;           -- partial: only unprocessed rows

-- ============================================================
-- updated_at auto-maintenance
-- ============================================================
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

create or replace trigger trg_profiles_updated_at
  before update on public.profiles
  for each row execute function public.set_updated_at();
