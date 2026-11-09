-- Etapa 2: leituras dos sensores e eventos reais de irrigação.

create table if not exists public.sensor_readings (
  id uuid primary key default gen_random_uuid(),
  plant_id uuid not null references public.plants(id) on delete cascade,
  device_id text,
  soil_moisture numeric(5, 2),
  temperature numeric(6, 2),
  air_humidity numeric(5, 2),
  illuminance numeric(10, 2),
  recorded_at timestamptz not null default timezone('utc', now()),
  created_at timestamptz not null default timezone('utc', now()),
  constraint sensor_readings_soil_check
    check (soil_moisture is null or soil_moisture between 0 and 100),
  constraint sensor_readings_air_check
    check (air_humidity is null or air_humidity between 0 and 100)
);

create table if not exists public.irrigation_events (
  id uuid primary key default gen_random_uuid(),
  plant_id uuid not null references public.plants(id) on delete cascade,
  device_id text,
  valve text not null,
  mode text not null,
  started_at timestamptz not null,
  finished_at timestamptz,
  duration_seconds integer,
  soil_moisture_before numeric(5, 2),
  soil_moisture_after numeric(5, 2),
  status text not null default 'completed',
  cancellation_reason text,
  created_at timestamptz not null default timezone('utc', now()),
  constraint irrigation_events_valve_check
    check (valve in ('valve_1', 'valve_2')),
  constraint irrigation_events_status_check
    check (status in ('completed', 'cancelled', 'interrupted', 'failed')),
  constraint irrigation_events_duration_check
    check (duration_seconds is null or duration_seconds >= 0),
  constraint irrigation_events_before_check
    check (soil_moisture_before is null or soil_moisture_before between 0 and 100),
  constraint irrigation_events_after_check
    check (soil_moisture_after is null or soil_moisture_after between 0 and 100)
);

create index if not exists sensor_readings_plant_recorded_idx
  on public.sensor_readings(plant_id, recorded_at desc);
create index if not exists irrigation_events_plant_started_idx
  on public.irrigation_events(plant_id, started_at desc);

alter table public.sensor_readings enable row level security;
alter table public.irrigation_events enable row level security;

create policy sensor_readings_select_own on public.sensor_readings
for select to authenticated
using (exists (
  select 1 from public.plants p
  where p.id = sensor_readings.plant_id
    and p.user_id = auth.uid()
    and p.deleted_at is null
));

create policy sensor_readings_insert_own on public.sensor_readings
for insert to authenticated
with check (exists (
  select 1 from public.plants p
  where p.id = sensor_readings.plant_id
    and p.user_id = auth.uid()
));

create policy irrigation_events_select_own on public.irrigation_events
for select to authenticated
using (exists (
  select 1 from public.plants p
  where p.id = irrigation_events.plant_id
    and p.user_id = auth.uid()
    and p.deleted_at is null
));

create policy irrigation_events_insert_own on public.irrigation_events
for insert to authenticated
with check (exists (
  select 1 from public.plants p
  where p.id = irrigation_events.plant_id
    and p.user_id = auth.uid()
));
