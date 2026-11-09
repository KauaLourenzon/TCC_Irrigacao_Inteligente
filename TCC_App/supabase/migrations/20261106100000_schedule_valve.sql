-- Permite escolher a válvula individualmente em cada horário de rega.

alter table public.irrigation_schedule_times
  add column if not exists valve text not null default 'valve_2';

alter table public.irrigation_schedule_times
  drop constraint if exists irrigation_schedule_times_valve_check;

alter table public.irrigation_schedule_times
  add constraint irrigation_schedule_times_valve_check
  check (valve in ('valve_1', 'valve_2'));
