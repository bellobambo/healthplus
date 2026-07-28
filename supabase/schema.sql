-- Run this in Supabase SQL Editor before starting the API.
-- Authentication credentials live in auth.users; this table stores app profile data only.

create type public.user_role as enum ('PATIENT', 'PHARMACY', 'ADMIN');

create table public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  full_name text not null,
  phone text,
  role public.user_role not null default 'PATIENT',
  created_at timestamptz not null default now()
);

create table public.pharmacies (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null unique references public.profiles(id) on delete cascade,
  pharmacy_name text not null,
  verified boolean not null default false,
  created_at timestamptz not null default now()
);

alter table public.profiles enable row level security;
alter table public.pharmacies enable row level security;

create policy "Users can read their own profile"
  on public.profiles for select to authenticated using ((select auth.uid()) = id);

create policy "Pharmacy owners can read their own pharmacy"
  on public.pharmacies for select to authenticated using ((select auth.uid()) = owner_id);

-- Profile creation is intentionally limited to the trigger below.
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
  );
  if new.raw_user_meta_data ->> 'role' = 'PHARMACY' then
    insert into public.pharmacies (owner_id, pharmacy_name) values (
      new.id,
      new.raw_user_meta_data ->> 'pharmacy_name'
    );
  end if;
  return new;
end;
$$;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute procedure public.handle_new_user();

-- Prevent patients/pharmacies from self-promoting by direct profile updates.
-- Add narrowly-scoped update policies later for editable name/phone fields.
