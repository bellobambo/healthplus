-- Health + database setup
-- Run this whole file once in Supabase Dashboard -> SQL Editor.
-- It is safe to rerun: it creates/repairs the app schema, backfills profiles
-- for existing Auth users, and reinstalls the profile-creation trigger.

do $$
begin
  create type public.user_role as enum ('PATIENT', 'PHARMACY', 'ADMIN');
exception
  when duplicate_object then null;
end $$;

alter type public.user_role add value if not exists 'PATIENT';
alter type public.user_role add value if not exists 'PHARMACY';
alter type public.user_role add value if not exists 'ADMIN';

create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  full_name text not null,
  phone text,
  role public.user_role not null default 'PATIENT',
  created_at timestamptz not null default now()
);

create table if not exists public.pharmacies (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null unique references public.profiles(id) on delete cascade,
  pharmacy_name text not null,
  verified boolean not null default false,
  created_at timestamptz not null default now()
);

alter table public.profiles enable row level security;
alter table public.pharmacies enable row level security;

drop policy if exists "Users can read their own profile" on public.profiles;
create policy "Users can read their own profile"
  on public.profiles for select to authenticated
  using ((select auth.uid()) = id);

drop policy if exists "Pharmacy owners can read their own pharmacy" on public.pharmacies;
create policy "Pharmacy owners can read their own pharmacy"
  on public.pharmacies for select to authenticated
  using ((select auth.uid()) = owner_id);

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer set search_path = public
as $$
begin
  insert into public.profiles (id, full_name, phone, role)
  values (
    new.id,
    coalesce(new.raw_user_meta_data ->> 'full_name', ''),
    new.raw_user_meta_data ->> 'phone',
    case
      when new.raw_user_meta_data ->> 'role' in ('PATIENT', 'PHARMACY')
        then (new.raw_user_meta_data ->> 'role')::public.user_role
      else 'PATIENT'::public.user_role
    end
  ) on conflict (id) do nothing;

  if new.raw_user_meta_data ->> 'role' = 'PHARMACY' then
    insert into public.pharmacies (owner_id, pharmacy_name)
    values (new.id, coalesce(nullif(new.raw_user_meta_data ->> 'pharmacy_name', ''), 'Unspecified pharmacy'))
    on conflict (owner_id) do nothing;
  end if;
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute procedure public.handle_new_user();

-- Repair accounts created before the trigger was installed.
insert into public.profiles (id, full_name, phone, role)
select
  id,
  coalesce(raw_user_meta_data ->> 'full_name', ''),
  raw_user_meta_data ->> 'phone',
  case
    when raw_user_meta_data ->> 'role' in ('PATIENT', 'PHARMACY')
      then (raw_user_meta_data ->> 'role')::public.user_role
    else 'PATIENT'::public.user_role
  end
from auth.users
on conflict (id) do nothing;

insert into public.pharmacies (owner_id, pharmacy_name)
select
  u.id,
  coalesce(nullif(u.raw_user_meta_data ->> 'pharmacy_name', ''), 'Unspecified pharmacy')
from auth.users u
join public.profiles p on p.id = u.id and p.role = 'PHARMACY'
on conflict (owner_id) do nothing;
