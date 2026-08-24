-- =========================================================================
-- Assistente proativo: catálogo de espécies, controle de proatividade,
-- categorização de mensagens e assinaturas de push.
-- =========================================================================

-- Catálogo de espécies com perfil de cuidado, usado pelo assistente pra
-- saber o que é "normal" pra cada planta sem depender só do threshold
-- manual configurado pelo usuário.
create table public.species_profiles (
  id uuid primary key default gen_random_uuid(),
  common_name text not null,
  scientific_name text,
  ideal_moisture_min integer not null default 30,
  ideal_moisture_max integer not null default 60,
  ideal_temp_min numeric not null default 15,
  ideal_temp_max numeric not null default 28,
  watering_frequency_days integer not null default 3,
  light_needs text not null default 'indirect' check (light_needs in ('low','indirect','direct')),
  care_notes text,
  created_at timestamptz not null default now()
);

grant select on public.species_profiles to anon, authenticated;
grant all on public.species_profiles to service_role;
alter table public.species_profiles enable row level security;
create policy "species_profiles: leitura pública" on public.species_profiles
  for select to anon, authenticated using (true);

insert into public.species_profiles
  (common_name, scientific_name, ideal_moisture_min, ideal_moisture_max, ideal_temp_min, ideal_temp_max, watering_frequency_days, light_needs, care_notes)
values
  ('Jiboia', 'Epipremnum aureum', 30, 60, 18, 30, 5, 'indirect', 'Tolerante, deixe o solo secar bem entre regas.'),
  ('Espada-de-são-jorge', 'Sansevieria trifasciata', 15, 40, 15, 32, 10, 'low', 'Muito resistente, regue pouco e espaçado.'),
  ('Samambaia', 'Nephrolepis exaltata', 50, 75, 16, 26, 2, 'indirect', 'Gosta de umidade alta, não deixe secar.'),
  ('Suculenta', 'Echeveria spp.', 10, 30, 15, 30, 12, 'direct', 'Regue só quando o solo estiver bem seco.'),
  ('Costela-de-adão', 'Monstera deliciosa', 35, 65, 18, 29, 6, 'indirect', 'Gosta de luz indireta forte, evite sol direto.'),
  ('Zamioculca', 'Zamioculcas zamiifolia', 15, 40, 18, 30, 12, 'low', 'Extremamente tolerante a esquecimento e pouca luz.'),
  ('Orquídea', 'Phalaenopsis spp.', 40, 65, 18, 27, 7, 'indirect', 'Regue com moderação, raízes não podem ficar encharcadas.'),
  ('Manjericão', 'Ocimum basilicum', 45, 70, 18, 30, 1, 'direct', 'Gosta de sol e de solo sempre levemente úmido.');

-- Cada planta passa a apontar pra um perfil de espécie e ganha controle
-- de proatividade.
alter table public.plants
  add column species_id uuid references public.species_profiles (id),
  add column proactive_enabled boolean not null default true;

-- Sincroniza automaticamente o campo de texto `species` (já usado no
-- resto do app: cards, prompt do assistente) a partir do perfil
-- escolhido, pra não precisar tocar em mais nada que já lê `species`.
create or replace function public.sync_plant_species_name()
returns trigger
language plpgsql
as $$
begin
  if new.species_id is not null then
    select common_name into new.species
    from public.species_profiles
    where id = new.species_id;
  end if;
  return new;
end;
$$;

create trigger plants_sync_species_name
  before insert or update of species_id on public.plants
  for each row execute function public.sync_plant_species_name();

-- Mensagens do assistente passam a poder ser marcadas como "proativas"
-- (a planta puxou assunto sozinha) e categorizadas por tipo de alerta,
-- pra permitir cooldown (não repetir o mesmo aviso toda hora).
alter table public.plant_chat_messages
  add column is_proactive boolean not null default false,
  add column alert_kind text;

create index chat_plant_proactive_idx
  on public.plant_chat_messages (plant_id, alert_kind, created_at desc)
  where is_proactive;

-- Assinaturas de push (Web Push API) por usuário, pra notificar mesmo
-- com o app fechado.
create table public.push_subscriptions (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references auth.users (id) on delete cascade,
  endpoint text not null unique,
  p256dh text not null,
  auth_key text not null,
  created_at timestamptz not null default now()
);

grant select, insert, delete on public.push_subscriptions to authenticated;
grant all on public.push_subscriptions to service_role;
alter table public.push_subscriptions enable row level security;

create policy "push_subscriptions: dono tem acesso total" on public.push_subscriptions
  for all to authenticated
  using (owner_id = auth.uid())
  with check (owner_id = auth.uid());