-- ============================================================
-- AidPulsate — Migration 004: Admin Setup
--
-- Run this in the Supabase SQL Editor if you have already run
-- migrations 001–003.  If you are starting fresh, run ALL of
-- 001 → 004 in order.
--
-- What this migration does:
--   1. Creates a helper view  public.admin_users  so you can
--      easily list / manage admin accounts in the dashboard.
--   2. Adds a secure function  public.promote_to_admin(email)
--      so you can grant admin rights to an existing user
--      without touching the raw auth.users table.
--   3. Adds a function  public.demote_from_admin(email)  to
--      revoke admin rights.
--   4. Grants execute on both functions to the postgres role
--      only (never to authenticated / anon).
-- ============================================================

-- ── 1. admin_users view ─────────────────────────────────────
-- Convenience view: lists every user who has role = 'admin'.
-- Joins profiles ↔ auth.users so you get the email too.
-- Access: visible only to superuser / service_role in the
-- Supabase dashboard (RLS on profiles protects client access).
create or replace view public.admin_users
  with (security_invoker = true)
as
select
  p.id,
  u.email,
  p.full_name,
  p.phone,
  p.created_at,
  p.updated_at
from public.profiles p
join auth.users u on u.id = p.id
where p.role = 'admin';

comment on view public.admin_users is
  'All users with role=admin. Visible in the Supabase dashboard only (service_role).';

-- ── 2. promote_to_admin(email) ──────────────────────────────
-- Elevates an existing user to admin by email.
-- Must be called from the Supabase SQL Editor or a server-side
-- Edge Function — never from the Flutter client directly.
--
-- Usage:
--   select public.promote_to_admin('responder@example.com');
create or replace function public.promote_to_admin(p_email text)
returns text
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id uuid;
begin
  -- Look up the auth user by email.
  select id into v_user_id
  from auth.users
  where email = lower(trim(p_email))
  limit 1;

  if v_user_id is null then
    return 'ERROR: no user found with email ' || p_email;
  end if;

  -- Upsert the profile row with role = 'admin'.
  insert into public.profiles (id, role)
  values (v_user_id, 'admin')
  on conflict (id) do update
    set role       = 'admin',
        updated_at = now();

  return 'OK: ' || p_email || ' is now an admin (id=' || v_user_id || ')';
end;
$$;

comment on function public.promote_to_admin(text) is
  'Elevate a user to admin by email. Run in Supabase SQL Editor only.';

-- ── 3. demote_from_admin(email) ─────────────────────────────
-- Revokes admin rights, returning the user to role = 'victim'.
--
-- Usage:
--   select public.demote_from_admin('responder@example.com');
create or replace function public.demote_from_admin(p_email text)
returns text
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id uuid;
begin
  select id into v_user_id
  from auth.users
  where email = lower(trim(p_email))
  limit 1;

  if v_user_id is null then
    return 'ERROR: no user found with email ' || p_email;
  end if;

  update public.profiles
  set role       = 'victim',
      updated_at = now()
  where id = v_user_id;

  return 'OK: ' || p_email || ' has been demoted to victim (id=' || v_user_id || ')';
end;
$$;

comment on function public.demote_from_admin(text) is
  'Revoke admin rights from a user by email. Run in Supabase SQL Editor only.';

-- ── 4. Lock down function execution ─────────────────────────
-- Only the postgres / service_role may call these functions.
-- The authenticated and anon roles cannot call them directly.
revoke execute on function public.promote_to_admin(text)  from public, authenticated, anon;
revoke execute on function public.demote_from_admin(text) from public, authenticated, anon;
