-- Run after the original schema + 002 migration only.
alter table public.pharmacies
  drop column city,
  drop column state,
  drop column latitude,
  drop column longitude;

alter type public.user_role rename value 'patient' to 'PATIENT';
alter type public.user_role rename value 'pharmacy' to 'PHARMACY';
alter type public.user_role rename value 'admin' to 'ADMIN';

create or replace function public.handle_new_user()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  insert into public.profiles (id, full_name, phone, role)
  values (new.id, coalesce(new.raw_user_meta_data ->> 'full_name', ''), new.raw_user_meta_data ->> 'phone',
    case when new.raw_user_meta_data ->> 'role' in ('PATIENT', 'PHARMACY')
      then (new.raw_user_meta_data ->> 'role')::public.user_role else 'PATIENT'::public.user_role end);
  if new.raw_user_meta_data ->> 'role' = 'PHARMACY' then
    insert into public.pharmacies (owner_id, pharmacy_name, company_name, pcn_license_number, phone, address)
    values (new.id, new.raw_user_meta_data ->> 'pharmacy_name', nullif(new.raw_user_meta_data ->> 'company_name', ''),
      new.raw_user_meta_data ->> 'pcn_license_number', nullif(new.raw_user_meta_data ->> 'phone', ''), new.raw_user_meta_data ->> 'address');
  end if;
  return new;
end;
$$;
