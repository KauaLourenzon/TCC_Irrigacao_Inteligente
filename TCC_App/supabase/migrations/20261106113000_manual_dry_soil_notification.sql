-- A notificação de solo seco só é válida no modo manual.

create or replace function public.disable_dry_soil_notification_for_non_manual()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.irrigation_mode <> 'manual' then
    update public.plant_notification_preferences
    set dry_soil = false
    where plant_id = new.plant_id;
  end if;
  return new;
end;
$$;

drop trigger if exists disable_dry_soil_notification_trigger
on public.plant_care_configs;

create trigger disable_dry_soil_notification_trigger
after insert or update of irrigation_mode on public.plant_care_configs
for each row
execute function public.disable_dry_soil_notification_for_non_manual();
