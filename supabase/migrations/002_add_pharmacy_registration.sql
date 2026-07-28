-- Run this only when you already ran the original schema.sql.

create table public.pharmacies (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null unique references public.profiles(id) on delete cascade,
  pharmacy_name text not null,
  company_name text,
  pcn_license_number text not null unique,
  phone text,
  address text not null,
  city text not null,
  state text not null,
  latitude numeric(9, 6) not null check (latitude between -90 and 90),
  longitude numeric(9, 6) not null check (longitude between -180 and 180),
  verified boolean not null default false,
  created_at timestamptz not null default now()
);

alter table public.pharmacies enable row level security;

create policy "Pharmacy owners can read their own pharmacy"
  on public.pharmacies for select to authenticated using ((select auth.uid()) = owner_id);

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
      when new.raw_user_meta_data ->> 'role' in ('patient', 'pharmacy')
        then (new.raw_user_meta_data ->> 'role')::public.user_role
      else 'patient'::public.user_role
    end
  );

  if new.raw_user_meta_data ->> 'role' = 'pharmacy' then
    insert into public.pharmacies (
      owner_id, pharmacy_name, company_name, pcn_license_number, phone,
      address, city, state, latitude, longitude
    ) values (
      new.id,
      new.raw_user_meta_data ->> 'pharmacy_name',
      nullif(new.raw_user_meta_data ->> 'company_name', ''),
      new.raw_user_meta_data ->> 'pcn_license_number',
      nullif(new.raw_user_meta_data ->> 'phone', ''),
      new.raw_user_meta_data ->> 'address',
      new.raw_user_meta_data ->> 'city',
      new.raw_user_meta_data ->> 'state',
      (new.raw_user_meta_data ->> 'latitude')::numeric,
      (new.raw_user_meta_data ->> 'longitude')::numeric
    );
  end if;
  return new;
end;
$$;
