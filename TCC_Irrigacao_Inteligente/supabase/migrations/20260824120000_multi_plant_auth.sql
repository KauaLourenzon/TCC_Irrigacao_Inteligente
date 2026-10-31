-- =========================================================================
-- Migração: multi-usuário + múltiplas plantas + assistente por planta
-- =========================================================================
-- Isso substitui o schema antigo de "1 planta só, aberta pra todo mundo"
-- por um schema multi-tenant: cada usuário autenticado só enxerga e
-- mexe nas próprias plantas (via Row Level Security).
--
-- ATENÇÃO: como é ambiente de desenvolvimento/TCC com dados de exemplo,
-- esta migration APAGA as tabelas antigas (plant, readings, waterings) e
-- recria tudo do zero já com dono (owner_id). Se você já tiver dados reais
-- que precisa manter, faça backup antes de rodar.
-- =========================================================================

drop table if exists public.waterings cascade;
drop table if exists public.readings cascade;
drop table if exists public.plant cascade;

-- ---------------------------------------------------------------------
-- plants: agora múltiplas por usuário. Cada planta = 1 sensor ESP32
-- conectado via USB/Serial, identificado no navegador (não mais por
-- token de rede — a conexão é local, feita pelo dono na hora de usar).
-- ---------------------------------------------------------------------
create table public.plants (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references auth.users (id) on delete cascade,
  name text not null default 'Minha plantinha',
  species text,
  mode text not null default 'auto' check (mode in ('manual', 'scheduled', 'auto')),
  moisture_threshold integer not null default 35,
  schedule_times text[] not null default array['08:00']::text[],
  schedule_days integer[] not null default array[0, 1, 2, 3, 4, 5, 6]::integer[],
  water_requested_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- Facilita achar a planta "pelo nome" pra abrir o assistente certo,
-- e evita duas plantas com o mesmo nome pro mesmo dono.
create unique index plants_owner_name_key on public.plants (owner_id, lower(name));

create table public.readings (
  id uuid primary key default gen_random_uuid(),
  plant_id uuid not null references public.plants (id) on delete cascade,
  soil_moisture numeric not null,
  temperature numeric,
  recorded_at timestamptz not null default now()
);

create table public.waterings (
  id uuid primary key default gen_random_uuid(),
  plant_id uuid not null references public.plants (id) on delete cascade,
  source text not null default 'manual',
  soil_moisture numeric,
  watered_at timestamptz not null default now()
);

-- Histórico de conversa do assistente de cada planta (fica salvo por
-- planta, então cada uma "lembra" o que já foi dito pra ela).
create table public.plant_chat_messages (
  id uuid primary key default gen_random_uuid(),
  plant_id uuid not null references public.plants (id) on delete cascade,
  role text not null check (role in ('user', 'assistant')),
  content text not null,
  created_at timestamptz not null default now()
);

create index readings_plant_recorded_idx on public.readings (plant_id, recorded_at desc);
create index waterings_plant_watered_idx on public.waterings (plant_id, watered_at desc);
create index chat_plant_created_idx on public.plant_chat_messages (plant_id, created_at asc);

-- ---------------------------------------------------------------------
-- RLS: cada usuário só vê/mexe no que é dele
-- ---------------------------------------------------------------------
alter table public.plants enable row level security;
alter table public.readings enable row level security;
alter table public.waterings enable row level security;
alter table public.plant_chat_messages enable row level security;

grant select, insert, update, delete on public.plants to authenticated;
grant select, insert on public.readings to authenticated;
grant select, insert on public.waterings to authenticated;
grant select, insert on public.plant_chat_messages to authenticated;
grant all on public.plants, public.readings, public.waterings, public.plant_chat_messages to service_role;

create policy "plants: dono tem acesso total" on public.plants
  for all to authenticated
  using (owner_id = auth.uid())
  with check (owner_id = auth.uid());

create policy "readings: dono pode ler" on public.readings
  for select to authenticated
  using (exists (
    select 1 from public.plants p where p.id = readings.plant_id and p.owner_id = auth.uid()
  ));

create policy "readings: dono pode inserir" on public.readings
  for insert to authenticated
  with check (exists (
    select 1 from public.plants p where p.id = readings.plant_id and p.owner_id = auth.uid()
  ));

create policy "waterings: dono pode ler" on public.waterings
  for select to authenticated
  using (exists (
    select 1 from public.plants p where p.id = waterings.plant_id and p.owner_id = auth.uid()
  ));

create policy "waterings: dono pode inserir" on public.waterings
  for insert to authenticated
  with check (exists (
    select 1 from public.plants p where p.id = waterings.plant_id and p.owner_id = auth.uid()
  ));

create policy "chat: dono pode ler" on public.plant_chat_messages
  for select to authenticated
  using (exists (
    select 1 from public.plants p where p.id = plant_chat_messages.plant_id and p.owner_id = auth.uid()
  ));

create policy "chat: dono pode inserir" on public.plant_chat_messages
  for insert to authenticated
  with check (exists (
    select 1 from public.plants p where p.id = plant_chat_messages.plant_id and p.owner_id = auth.uid()
  ));

alter publication supabase_realtime add table public.readings;
alter publication supabase_realtime add table public.waterings;
alter publication supabase_realtime add table public.plants;
alter publication supabase_realtime add table public.plant_chat_messages;

-- Nenhum dado de exemplo é inserido aqui de propósito: como agora toda
-- planta precisa de um owner_id (usuário real), cadastre suas plantas
-- pela própria interface depois de criar sua conta.
