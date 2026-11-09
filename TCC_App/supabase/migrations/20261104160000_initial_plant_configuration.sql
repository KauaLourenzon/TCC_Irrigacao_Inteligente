-- Etapa 1: autenticação, plantas e configurações iniciais.
-- Execute esta migration em um projeto Supabase novo ou controlado.

create extension if not exists pgcrypto;

create or replace function public.set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = timezone('utc', now());
  return new;
end;
$$;

create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  display_name text,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now())
);

create table if not exists public.plants (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  popular_name text not null,
  scientific_name text,
  photo_path text,
  ai_identified boolean not null default false,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  deleted_at timestamptz,
  constraint plants_popular_name_not_blank check (length(trim(popular_name)) > 0)
);

create table if not exists public.plant_care_configs (
  id uuid primary key default gen_random_uuid(),
  plant_id uuid not null unique references public.plants(id) on delete cascade,
  irrigation_mode text not null default 'intelligent',
  ai_suggestion_enabled boolean not null default true,
  light_min numeric(5, 2),
  light_max numeric(5, 2),
  soil_trigger numeric(5, 2),
  temperature_min numeric(5, 2),
  temperature_max numeric(5, 2),
  air_humidity_min numeric(5, 2),
  valve_2_mode text not null default 'drip',
  manual_auto_stop boolean not null default true,
  manual_duration_seconds integer,
  manual_safety_seconds integer,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  constraint plant_care_configs_mode_check
    check (irrigation_mode in ('manual', 'scheduled', 'intelligent')),
  constraint plant_care_configs_valve_2_check
    check (valve_2_mode in ('drip', 'micro_sprinkler')),
  constraint plant_care_configs_light_check
    check (light_min is null or light_min between 0 and 100),
  constraint plant_care_configs_light_max_check
    check (light_max is null or light_max between 0 and 100),
  constraint plant_care_configs_soil_check
    check (soil_trigger is null or soil_trigger between 0 and 100),
  constraint plant_care_configs_manual_duration_check
    check (manual_duration_seconds is null or manual_duration_seconds > 0),
  constraint plant_care_configs_manual_safety_check
    check (manual_safety_seconds is null or manual_safety_seconds > 0)
);

create table if not exists public.irrigation_schedules (
  id uuid primary key default gen_random_uuid(),
  plant_id uuid not null references public.plants(id) on delete cascade,
  frequency_days integer not null default 1,
  times_per_day integer not null default 1,
  finish_mode text not null default 'duration',
  duration_seconds integer,
  soil_humidity_target numeric(5, 2),
  active boolean not null default true,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  constraint irrigation_schedules_frequency_check check (frequency_days between 1 and 30),
  constraint irrigation_schedules_times_check check (times_per_day between 1 and 6),
  constraint irrigation_schedules_finish_mode_check
    check (finish_mode in ('duration', 'soil_humidity')),
  constraint irrigation_schedules_duration_check
    check (duration_seconds is null or duration_seconds > 0),
  constraint irrigation_schedules_soil_check
    check (soil_humidity_target is null or soil_humidity_target between 0 and 100)
);

create table if not exists public.irrigation_schedule_times (
  id uuid primary key default gen_random_uuid(),
  schedule_id uuid not null references public.irrigation_schedules(id) on delete cascade,
  time_of_day time not null,
  duration_seconds integer,
  sort_order integer not null default 0,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  constraint schedule_times_duration_check
    check (duration_seconds is null or duration_seconds > 0),
  unique (schedule_id, time_of_day)
);

create index if not exists plants_user_id_idx on public.plants(user_id);
create index if not exists plants_active_idx on public.plants(user_id, deleted_at);
create index if not exists irrigation_schedules_plant_id_idx
  on public.irrigation_schedules(plant_id);
create index if not exists irrigation_schedule_times_schedule_id_idx
  on public.irrigation_schedule_times(schedule_id, sort_order);

drop trigger if exists profiles_set_updated_at on public.profiles;
create trigger profiles_set_updated_at
before update on public.profiles
for each row execute function public.set_updated_at();

drop trigger if exists plants_set_updated_at on public.plants;
create trigger plants_set_updated_at
before update on public.plants
for each row execute function public.set_updated_at();

drop trigger if exists plant_care_configs_set_updated_at on public.plant_care_configs;
create trigger plant_care_configs_set_updated_at
before update on public.plant_care_configs
for each row execute function public.set_updated_at();

drop trigger if exists irrigation_schedules_set_updated_at on public.irrigation_schedules;
create trigger irrigation_schedules_set_updated_at
before update on public.irrigation_schedules
for each row execute function public.set_updated_at();

drop trigger if exists irrigation_schedule_times_set_updated_at on public.irrigation_schedule_times;
create trigger irrigation_schedule_times_set_updated_at
before update on public.irrigation_schedule_times
for each row execute function public.set_updated_at();

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer set search_path = public
as $$
begin
  insert into public.profiles (id, display_name)
  values (new.id, coalesce(new.raw_user_meta_data ->> 'display_name', new.email));
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
after insert on auth.users
for each row execute function public.handle_new_user();

alter table public.profiles enable row level security;
alter table public.plants enable row level security;
alter table public.plant_care_configs enable row level security;
alter table public.irrigation_schedules enable row level security;
alter table public.irrigation_schedule_times enable row level security;

create policy profiles_select_own on public.profiles
for select to authenticated using (id = auth.uid());

create policy profiles_update_own on public.profiles
for update to authenticated using (id = auth.uid()) with check (id = auth.uid());

create policy plants_select_own on public.plants
for select to authenticated
using (user_id = auth.uid() and deleted_at is null);

create policy plants_insert_own on public.plants
for insert to authenticated
with check (user_id = auth.uid());

create policy plants_update_own on public.plants
for update to authenticated
using (user_id = auth.uid()) with check (user_id = auth.uid());

create policy plants_delete_own on public.plants
for delete to authenticated
using (user_id = auth.uid());

create policy plant_care_configs_select_own on public.plant_care_configs
for select to authenticated
using (exists (
  select 1 from public.plants p
  where p.id = plant_care_configs.plant_id
    and p.user_id = auth.uid()
    and p.deleted_at is null
));

create policy plant_care_configs_insert_own on public.plant_care_configs
for insert to authenticated
with check (exists (
  select 1 from public.plants p
  where p.id = plant_care_configs.plant_id
    and p.user_id = auth.uid()
));

create policy plant_care_configs_update_own on public.plant_care_configs
for update to authenticated
using (exists (
  select 1 from public.plants p
  where p.id = plant_care_configs.plant_id and p.user_id = auth.uid()
))
with check (exists (
  select 1 from public.plants p
  where p.id = plant_care_configs.plant_id and p.user_id = auth.uid()
));

create policy plant_care_configs_delete_own on public.plant_care_configs
for delete to authenticated
using (exists (
  select 1 from public.plants p
  where p.id = plant_care_configs.plant_id and p.user_id = auth.uid()
));

create policy irrigation_schedules_all_own on public.irrigation_schedules
for all to authenticated
using (exists (
  select 1 from public.plants p
  where p.id = irrigation_schedules.plant_id
    and p.user_id = auth.uid()
    and p.deleted_at is null
))
with check (exists (
  select 1 from public.plants p
  where p.id = irrigation_schedules.plant_id
    and p.user_id = auth.uid()
));

create policy irrigation_schedule_times_all_own on public.irrigation_schedule_times
for all to authenticated
using (exists (
  select 1
  from public.irrigation_schedules s
  join public.plants p on p.id = s.plant_id
  where s.id = irrigation_schedule_times.schedule_id
    and p.user_id = auth.uid()
    and p.deleted_at is null
))
with check (exists (
  select 1
  from public.irrigation_schedules s
  join public.plants p on p.id = s.plant_id
  where s.id = irrigation_schedule_times.schedule_id
    and p.user_id = auth.uid()
));
