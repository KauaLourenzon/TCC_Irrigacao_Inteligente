-- Etapa 3: preferências de notificações por planta.

create table if not exists public.plant_notification_preferences (
  id uuid primary key default gen_random_uuid(),
  plant_id uuid not null unique references public.plants(id) on delete cascade,
  irrigation_completed boolean not null default true,
  excessive_light boolean not null default true,
  excessive_light_limit numeric(10, 2) not null default 80,
  thermal_stress boolean not null default true,
  thermal_min numeric(6, 2),
  thermal_max numeric(6, 2) not null default 30,
  dry_soil boolean not null default true,
  dry_soil_limit numeric(5, 2) not null default 35,
  dry_air boolean not null default false,
  dry_air_limit numeric(5, 2) not null default 35,
  manual_completed boolean not null default true,
  safety_watchdog boolean not null default true,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  constraint notification_light_limit_check
    check (excessive_light_limit between 0 and 100),
  constraint notification_thermal_max_check
    check (thermal_max between -20 and 80),
  constraint notification_dry_soil_limit_check
    check (dry_soil_limit between 0 and 100),
  constraint notification_dry_air_limit_check
    check (dry_air_limit between 0 and 100)
);

drop trigger if exists plant_notification_preferences_set_updated_at
  on public.plant_notification_preferences;
create trigger plant_notification_preferences_set_updated_at
before update on public.plant_notification_preferences
for each row execute function public.set_updated_at();

alter table public.plant_notification_preferences enable row level security;

create policy plant_notification_preferences_select_own
on public.plant_notification_preferences
for select to authenticated
using (exists (
  select 1 from public.plants p
  where p.id = plant_notification_preferences.plant_id
    and p.user_id = auth.uid()
    and p.deleted_at is null
));

create policy plant_notification_preferences_insert_own
on public.plant_notification_preferences
for insert to authenticated
with check (exists (
  select 1 from public.plants p
  where p.id = plant_notification_preferences.plant_id
    and p.user_id = auth.uid()
));

create policy plant_notification_preferences_update_own
on public.plant_notification_preferences
for update to authenticated
using (exists (
  select 1 from public.plants p
  where p.id = plant_notification_preferences.plant_id
    and p.user_id = auth.uid()
))
with check (exists (
  select 1 from public.plants p
  where p.id = plant_notification_preferences.plant_id
    and p.user_id = auth.uid()
));

create policy plant_notification_preferences_delete_own
on public.plant_notification_preferences
for delete to authenticated
using (exists (
  select 1 from public.plants p
  where p.id = plant_notification_preferences.plant_id
    and p.user_id = auth.uid()
));
