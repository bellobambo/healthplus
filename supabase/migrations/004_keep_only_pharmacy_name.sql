-- Run after migration 003 if your database was created with the earlier pharmacy fields.
alter table public.pharmacies
  drop column company_name,
  drop column pcn_license_number,
  drop column phone,
  drop column address;

create or replace function public.handle_new_user()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  insert into public.profiles (id, full_name, phone, role)
  values (new.id, coalesce(new.raw_user_meta_data ->> 'full_name', ''), new.raw_user_meta_data ->> 'phone',
    case when new.raw_user_meta_data ->> 'role' in ('PATIENT', 'PHARMACY')
      then (new.raw_user_meta_data ->> 'role')::public.user_role else 'PATIENT'::public.user_role end);
  if new.raw_user_meta_data ->> 'role' = 'PHARMACY' then
    insert into public.pharmacies (owner_id, pharmacy_name)
    values (new.id, new.raw_user_meta_data ->> 'pharmacy_name');
  end if;
  return new;
end;
$$;
