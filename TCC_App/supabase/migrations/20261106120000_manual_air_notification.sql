-- A notificação de umidade do ar também só é válida no modo manual.

create or replace function public.disable_dry_soil_notification_for_non_manual()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.irrigation_mode <> 'manual' then
    update public.plant_notification_preferences
    set dry_soil = false,
        dry_air = false
    where plant_id = new.plant_id;
  end if;
  return new;
end;
$$;
