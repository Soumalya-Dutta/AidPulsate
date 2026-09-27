-- ============================================================
-- AidPulsate — Migration 006: Demo Data
--
-- Paste into Supabase SQL Editor and click "Run".
-- Idempotent — safe to run more than once.
--
-- Demo accounts (all password: Demo@1234)
--   admin@aidpulsate.com    — admin
--   responder@aidpulsate.com — admin
--   maria@example.com       — victim
--   aisha@example.com       — victim
--   lin@example.com         — victim
--   priya@example.com       — victim
--   fatima@example.com      — victim
-- ============================================================

-- ── Step 1: auth.users ───────────────────────────────────────
-- Insert directly into auth.users (the only way in the SQL Editor).
-- crypt() hashes the plain-text password with bcrypt.
insert into auth.users (
  id, instance_id, aud, role,
  email, encrypted_password,
  email_confirmed_at, confirmation_sent_at,
  raw_user_meta_data,
  created_at, updated_at,
  is_sso_user, is_anonymous
) values
  -- admins
  ('a1000000-0000-0000-0000-000000000001',
   '00000000-0000-0000-0000-000000000000',
   'authenticated', 'authenticated',
   'admin@aidpulsate.com',
   crypt('Demo@1234', gen_salt('bf')),
   now(), now(),
   '{"full_name":"Alex Admin","role":"admin"}'::jsonb,
   now(), now(), false, false),

  ('a1000000-0000-0000-0000-000000000002',
   '00000000-0000-0000-0000-000000000000',
   'authenticated', 'authenticated',
   'responder@aidpulsate.com',
   crypt('Demo@1234', gen_salt('bf')),
   now(), now(),
   '{"full_name":"Ryan Responder","role":"admin"}'::jsonb,
   now(), now(), false, false),

  -- victims
  ('b2000000-0000-0000-0000-000000000001',
   '00000000-0000-0000-0000-000000000000',
   'authenticated', 'authenticated',
   'maria@example.com',
   crypt('Demo@1234', gen_salt('bf')),
   now(), now(),
   '{"full_name":"Maria Garcia","role":"victim"}'::jsonb,
   now(), now(), false, false),

  ('b2000000-0000-0000-0000-000000000002',
   '00000000-0000-0000-0000-000000000000',
   'authenticated', 'authenticated',
   'aisha@example.com',
   crypt('Demo@1234', gen_salt('bf')),
   now(), now(),
   '{"full_name":"Aisha Thompson","role":"victim"}'::jsonb,
   now(), now(), false, false),

  ('b2000000-0000-0000-0000-000000000003',
   '00000000-0000-0000-0000-000000000000',
   'authenticated', 'authenticated',
   'lin@example.com',
   crypt('Demo@1234', gen_salt('bf')),
   now(), now(),
   '{"full_name":"Lin Wei","role":"victim"}'::jsonb,
   now(), now(), false, false),

  ('b2000000-0000-0000-0000-000000000004',
   '00000000-0000-0000-0000-000000000000',
   'authenticated', 'authenticated',
   'priya@example.com',
   crypt('Demo@1234', gen_salt('bf')),
   now(), now(),
   '{"full_name":"Priya Kapoor","role":"victim"}'::jsonb,
   now(), now(), false, false),

  ('b2000000-0000-0000-0000-000000000005',
   '00000000-0000-0000-0000-000000000000',
   'authenticated', 'authenticated',
   'fatima@example.com',
   crypt('Demo@1234', gen_salt('bf')),
   now(), now(),
   '{"full_name":"Fatima Hassan","role":"victim"}'::jsonb,
   now(), now(), false, false)

on conflict (id) do nothing;

-- ── Step 2: profiles ─────────────────────────────────────────
-- Upsert in case handle_new_user trigger already ran.
insert into public.profiles (id, full_name, role, phone) values
  ('a1000000-0000-0000-0000-000000000001', 'Alex Admin',      'admin',  '+1-555-0101'),
  ('a1000000-0000-0000-0000-000000000002', 'Ryan Responder',  'admin',  '+1-555-0102'),
  ('b2000000-0000-0000-0000-000000000001', 'Maria Garcia',    'victim', '+1-555-0201'),
  ('b2000000-0000-0000-0000-000000000002', 'Aisha Thompson',  'victim', '+1-555-0202'),
  ('b2000000-0000-0000-0000-000000000003', 'Lin Wei',         'victim', '+1-555-0203'),
  ('b2000000-0000-0000-0000-000000000004', 'Priya Kapoor',    'victim', '+1-555-0204'),
  ('b2000000-0000-0000-0000-000000000005', 'Fatima Hassan',   'victim', '+1-555-0205')
on conflict (id) do update
  set full_name  = excluded.full_name,
      role       = excluded.role,
      phone      = excluded.phone,
      updated_at = now();

-- ── Step 3: devices ──────────────────────────────────────────
insert into public.devices (id, user_id, fcm_token, phone_number, platform) values
  ('d0000000-0000-0000-0001-000000000001','b2000000-0000-0000-0000-000000000001','fcm_maria_android', '+15550201','android'),
  ('d0000000-0000-0000-0001-000000000002','b2000000-0000-0000-0000-000000000001','fcm_maria_web',      null,      'web'),
  ('d0000000-0000-0000-0001-000000000003','b2000000-0000-0000-0000-000000000002','fcm_aisha_android', '+15550202','android'),
  ('d0000000-0000-0000-0001-000000000004','b2000000-0000-0000-0000-000000000003','fcm_lin_android',   '+15550203','android'),
  ('d0000000-0000-0000-0001-000000000005','b2000000-0000-0000-0000-000000000004','fcm_priya_android', '+15550204','android'),
  ('d0000000-0000-0000-0001-000000000006','b2000000-0000-0000-0000-000000000005','fcm_fatima_android','+15550205','android')
on conflict (id) do nothing;

-- ── Step 4: sos_events ───────────────────────────────────────
insert into public.sos_events
  (id, user_id, status, transmission, initial_lat, initial_lng,
   started_at, resolved_at, ref_id, resolution_note)
values
  ('e0000000-0000-0000-0000-000000000001',
   'b2000000-0000-0000-0000-000000000001',
   'active','online', 40.712800,-74.006000,
   now()-interval '8 minutes', null, 'AP-DEMO1', null),

  ('e0000000-0000-0000-0000-000000000002',
   'b2000000-0000-0000-0000-000000000002',
   'active','sms', 34.052200,-118.243700,
   now()-interval '3 minutes', null, 'AP-DEMO2', null),

  ('e0000000-0000-0000-0000-000000000003',
   'b2000000-0000-0000-0000-000000000003',
   'resolved','online', 51.507400,-0.127800,
   now()-interval '2 hours', now()-interval '1 hour 45 minutes',
   'AP-DEMO3','Victim confirmed safe by responding officer.'),

  ('e0000000-0000-0000-0000-000000000004',
   'b2000000-0000-0000-0000-000000000004',
   'resolved','sms', 19.432600,-99.133200,
   now()-interval '5 hours', now()-interval '4 hours 30 minutes',
   'AP-DEMO4','Resolved via SMS fallback. Victim called in safe.'),

  ('e0000000-0000-0000-0000-000000000005',
   'b2000000-0000-0000-0000-000000000005',
   'cancelled','online', 48.856600,2.352200,
   now()-interval '1 day', now()-interval '23 hours 50 minutes',
   'AP-DEMO5','False alarm — victim accidentally triggered SOS.'),

  ('e0000000-0000-0000-0000-000000000006',
   'b2000000-0000-0000-0000-000000000001',
   'resolved','online', 40.714000,-74.009000,
   now()-interval '3 days', now()-interval '2 days 23 hours',
   'AP-DEMO6','Incident resolved. Police report filed.')
on conflict (id) do nothing;

-- ── Step 5: location_pings ───────────────────────────────────
insert into public.location_pings
  (event_id, user_id, lat, lng, accuracy, altitude, speed, heading, source, seq, created_at)
values
  -- e1 Maria active — GPS drifting north
  ('e0000000-0000-0000-0000-000000000001','b2000000-0000-0000-0000-000000000001',40.712800,-74.006000,5.0,10.0,0.5,0.0,  'gps',1,now()-interval '7 minutes'),
  ('e0000000-0000-0000-0000-000000000001','b2000000-0000-0000-0000-000000000001',40.713100,-74.005800,4.5,10.1,0.8,15.0, 'gps',2,now()-interval '6 minutes'),
  ('e0000000-0000-0000-0000-000000000001','b2000000-0000-0000-0000-000000000001',40.713500,-74.005500,4.2,10.3,1.2,20.0, 'gps',3,now()-interval '5 minutes'),
  ('e0000000-0000-0000-0000-000000000001','b2000000-0000-0000-0000-000000000001',40.713900,-74.005200,4.8,10.5,0.9,18.0, 'gps',4,now()-interval '4 minutes'),
  -- e2 Aisha active — SMS pings
  ('e0000000-0000-0000-0000-000000000002','b2000000-0000-0000-0000-000000000002',34.052200,-118.243700,20.0,85.0,0.0,0.0,'sms_payload',1,now()-interval '2 minutes'),
  ('e0000000-0000-0000-0000-000000000002','b2000000-0000-0000-0000-000000000002',34.052400,-118.243500,22.0,85.0,0.3,5.0,'sms_payload',2,now()-interval '1 minute'),
  -- e3 Lin resolved
  ('e0000000-0000-0000-0000-000000000003','b2000000-0000-0000-0000-000000000003',51.507400,-0.127800,6.0,12.0,1.5,90.0, 'gps',1,now()-interval '2 hours'),
  ('e0000000-0000-0000-0000-000000000003','b2000000-0000-0000-0000-000000000003',51.507600,-0.127600,5.5,12.1,1.3,88.0, 'gps',2,now()-interval '1 hour 55 minutes'),
  ('e0000000-0000-0000-0000-000000000003','b2000000-0000-0000-0000-000000000003',51.507800,-0.127300,5.0,12.2,0.0,0.0,  'gps',3,now()-interval '1 hour 50 minutes'),
  -- e4 Priya resolved via SMS
  ('e0000000-0000-0000-0000-000000000004','b2000000-0000-0000-0000-000000000004',19.432600,-99.133200,25.0,2240.0,0.0,0.0, 'sms_payload',1,now()-interval '5 hours'),
  ('e0000000-0000-0000-0000-000000000004','b2000000-0000-0000-0000-000000000004',19.432700,-99.133000,24.0,2240.0,0.2,10.0,'sms_payload',2,now()-interval '4 hours 45 minutes'),
  -- e6 Maria older resolved
  ('e0000000-0000-0000-0000-000000000006','b2000000-0000-0000-0000-000000000001',40.714000,-74.009000,5.0,10.0,2.0,45.0,'gps',1,now()-interval '3 days'),
  ('e0000000-0000-0000-0000-000000000006','b2000000-0000-0000-0000-000000000001',40.714500,-74.008500,4.8,10.2,1.8,44.0,'gps',2,now()-interval '2 days 23 hours 50 minutes')
on conflict (id) do nothing;

-- ── Step 6: responders ───────────────────────────────────────
insert into public.responders (event_id, admin_id, status, notes) values
  ('e0000000-0000-0000-0000-000000000001','a1000000-0000-0000-0000-000000000001','on_route','Dispatched unit 4. ETA 6 minutes.'),
  ('e0000000-0000-0000-0000-000000000003','a1000000-0000-0000-0000-000000000001','closed',  'Officer arrived. Victim safe, escorted home.'),
  ('e0000000-0000-0000-0000-000000000004','a1000000-0000-0000-0000-000000000002','closed',  'SMS coordination. Local unit confirmed safe.'),
  ('e0000000-0000-0000-0000-000000000006','a1000000-0000-0000-0000-000000000002','closed',  'Responded and filed report.')
on conflict on constraint responders_event_admin_unique do nothing;

-- ── Step 7: sms_inbox ────────────────────────────────────────
insert into public.sms_inbox
  (id, raw_body, from_number, received_at, processed, processed_at, parse_error)
values
  ('f0000000-0000-0000-0000-000000000001',
   'AP|DEMO2|1720000000|34.052400|-118.243500|2|a4f2',
   '+15550202', now()-interval '1 minute',
   true, now()-interval '59 seconds', null),

  ('f0000000-0000-0000-0000-000000000002',
   'AP|DEMO2|1720000060|34.052600|-118.243300|3|b7c9',
   '+15550202', now()-interval '10 seconds',
   false, null, null),

  ('f0000000-0000-0000-0000-000000000003',
   'INVALID_PAYLOAD',
   '+15559999', now()-interval '30 minutes',
   true, now()-interval '29 minutes 50 seconds',
   'Invalid format: expected AP|ref|ts|lat|lng|seq|hmac')
on conflict (id) do nothing;

-- ── Verify ───────────────────────────────────────────────────
select 'auth.users'     as tbl, count(*) from auth.users            union all
select 'profiles'       as tbl, count(*) from public.profiles       union all
select 'devices'        as tbl, count(*) from public.devices        union all
select 'sos_events'     as tbl, count(*) from public.sos_events     union all
select 'location_pings' as tbl, count(*) from public.location_pings union all
select 'responders'     as tbl, count(*) from public.responders     union all
select 'sms_inbox'      as tbl, count(*) from public.sms_inbox;
