# AidPulsate — Supabase Backend

## How to apply migrations

Open the **Supabase SQL Editor** (Dashboard → SQL Editor) and run each file in order:

```
supabase/migrations/001_schema.sql   ← tables + indexes
supabase/migrations/002_rls.sql      ← RLS policies + Realtime
supabase/migrations/003_triggers.sql ← triggers + grants
```

Or use the Supabase CLI:

```bash
supabase db push
```

---

## Schema overview

```
auth.users  (managed by Supabase Auth)
    │
    ├─▶ profiles          one-to-one, created by trigger
    ├─▶ devices           one-to-many, push/SMS tokens
    ├─▶ sos_events        one-to-many, each SOS activation
    │       │
    │       ├─▶ location_pings   one-to-many, GPS updates
    │       └─▶ responders       many-to-many with profiles(admin)
    │
    └─▶ sms_inbox         written by SMS gateway (service_role only)
```

### Table descriptions

| Table | Purpose |
|---|---|
| `profiles` | Extended user data. `role` column is the server-enforced role. |
| `devices` | FCM tokens and phone numbers for push/SMS dispatch. |
| `sos_events` | Each SOS activation. Status: `active → resolved / cancelled`. |
| `location_pings` | GPS coordinates captured during an active SOS. |
| `responders` | Junction: admin assigned to a specific SOS event. |
| `sms_inbox` | Raw inbound SMS from the gateway. Parsed by trigger into pings. |

---

## Role model

| Role | Who | Access |
|---|---|---|
| `victim` | App users | Own profiles, own events, own pings |
| `admin` | Responders | Read all events + pings, assign responders, resolve events |
| `service_role` | Gateway server / triggers only | Bypass RLS — **never embed in mobile app** |

### How role is assigned securely

1. User signs up → Flutter writes `role` into `user_metadata`
2. `on_auth_user_created` trigger fires (runs as `postgres`, server-side)
3. Trigger copies `role` → `app_metadata.role` (service-role write, client cannot forge)
4. Trigger also creates the `profiles` row with the correct role
5. `current_user_role()` helper reads from `profiles.role` for RLS checks

`user_metadata` is **display-only** — it is user-editable and must never appear in RLS policies.

---

## RLS policy summary

### profiles
| Policy | Role | Operation |
|---|---|---|
| Owner select | victim | `id = auth.uid()` |
| Owner update | victim | `id = auth.uid()` |
| Admin select all | admin | `current_user_role() = 'admin'` |

### sos_events
| Policy | Role | Operation |
|---|---|---|
| Victim insert | victim | `user_id = auth.uid()` |
| Victim select own | victim | `user_id = auth.uid()` |
| Victim update own | victim | `user_id = auth.uid()` |
| Admin select all | admin | `current_user_role() = 'admin'` |
| Admin update | admin | `current_user_role() = 'admin'` |

### location_pings
| Policy | Role | Operation |
|---|---|---|
| Victim insert | victim | `user_id = auth.uid()` |
| Victim select own | victim | `user_id = auth.uid()` |
| Admin select all | admin | `current_user_role() = 'admin'` |

### sms_inbox
No RLS policies — accessible by `service_role` only (gateway + triggers).

---

## Realtime

Both `sos_events` and `location_pings` are added to the `supabase_realtime` publication. Supabase Realtime respects RLS — subscribers only receive rows they are permitted to see.

**Admin Flutter app** subscribes to:
```dart
supabase.from('sos_events').stream(primaryKey: ['id'])
supabase.from('location_pings').stream(primaryKey: ['id'])
  .eq('event_id', selectedEventId)
```

---

## SMS payload format

```
AP|<ref_id_short>|<unix_ts>|<lat>|<lng>|<seq>|<hmac4>
```

Example:
```
AP|8829X|1720000000|40.712800|-74.006000|3|a4f2
```

The `process_sms_payload` trigger fires on every `sms_inbox` INSERT and:
1. Validates the 7-field format
2. Looks up the matching active `sos_events` row by `ref_id`
3. Inserts a `location_pings` row with `source = 'sms_payload'`
4. Marks the `sms_inbox` row as `processed = true`

Parse errors are recorded in `sms_inbox.parse_error` and never crash the gateway.
