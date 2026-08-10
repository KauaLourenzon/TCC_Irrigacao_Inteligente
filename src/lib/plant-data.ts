import { supabase } from "@/integrations/supabase/client";

export type WateringMode = "manual" | "scheduled" | "auto";

export type Plant = {
  id: string;
  name: string;
  mode: WateringMode;
  moisture_threshold: number;
  schedule_times: string[];
  schedule_days: number[];
  water_requested_at: string | null;
};

export type Reading = {
  id: string;
  soil_moisture: number;
  temperature: number | null;
  recorded_at: string;
};

export type Watering = {
  id: string;
  source: string;
  soil_moisture: number | null;
  watered_at: string;
};

export async function fetchPlant(): Promise<Plant> {
  const { data, error } = await supabase
    .from("plant")
    .select("id, name, mode, moisture_threshold, schedule_times, schedule_days, water_requested_at")
    .order("created_at", { ascending: true })
    .limit(1)
    .maybeSingle();
  if (error) throw error;
  if (!data) throw new Error("Nenhuma planta cadastrada");
  return data as Plant;
}

export async function fetchReadings(limit = 24): Promise<Reading[]> {
  const { data, error } = await supabase
    .from("readings")
    .select("id, soil_moisture, temperature, recorded_at")
    .order("recorded_at", { ascending: false })
    .limit(limit);
  if (error) throw error;
  return (data ?? []) as Reading[];
}

export async function fetchWaterings(limit = 10): Promise<Watering[]> {
  const { data, error } = await supabase
    .from("waterings")
    .select("id, source, soil_moisture, watered_at")
    .order("watered_at", { ascending: false })
    .limit(limit);
  if (error) throw error;
  return (data ?? []) as Watering[];
}

export async function updatePlant(id: string, patch: Partial<Plant>) {
  const { error } = await supabase
    .from("plant")
    .update({ ...patch, updated_at: new Date().toISOString() })
    .eq("id", id);
  if (error) throw error;
}

/** Registra uma rega e envia o pedido de acionamento para o ESP32. */
export async function triggerWatering(
  plantId: string,
  source: WateringMode,
  soilMoisture: number | null,
) {
  const { error } = await supabase
    .from("waterings")
    .insert({ source, soil_moisture: soilMoisture });
  if (error) throw error;
  await updatePlant(plantId, { water_requested_at: new Date().toISOString() });
}

/**
 * Estimativa do próximo regamento: usa o intervalo médio entre as últimas
 * regas. Sem histórico suficiente, cai para um intervalo padrão de 3 dias.
 * Pronto para receber uma lógica mais rica (taxa de secagem do solo) depois.
 */
export function estimateNextWatering(waterings: Watering[]): Date | null {
  if (waterings.length === 0) return null;
  const last = new Date(waterings[0]!.watered_at);
  const fallbackHours = 72;
  if (waterings.length < 2) {
    return new Date(last.getTime() + fallbackHours * 3600_000);
  }
  const gaps: number[] = [];
  for (let i = 0; i < waterings.length - 1; i += 1) {
    const a = new Date(waterings[i]!.watered_at).getTime();
    const b = new Date(waterings[i + 1]!.watered_at).getTime();
    gaps.push(a - b);
  }
  const avg = gaps.reduce((sum, g) => sum + g, 0) / gaps.length;
  return new Date(last.getTime() + avg);
}

export const MODE_LABEL: Record<WateringMode, string> = {
  manual: "Manual",
  scheduled: "Programado",
  auto: "Automático por umidade",
};

export const WEEK_DAYS = ["Dom", "Seg", "Ter", "Qua", "Qui", "Sex", "Sáb"];

export function formatDateTime(value: string | Date | null) {
  if (!value) return "—";
  const date = typeof value === "string" ? new Date(value) : value;
  return date.toLocaleString("pt-BR", {
    day: "2-digit",
    month: "2-digit",
    hour: "2-digit",
    minute: "2-digit",
  });
}

export function relativeFromNow(value: string | Date | null) {
  if (!value) return "";
  const date = typeof value === "string" ? new Date(value) : value;
  const diff = date.getTime() - Date.now();
  const abs = Math.abs(diff);
  const hours = Math.round(abs / 3600_000);
  const label =
    hours < 1
      ? `${Math.max(1, Math.round(abs / 60_000))} min`
      : hours < 48
        ? `${hours} h`
        : `${Math.round(hours / 24)} dias`;
  return diff >= 0 ? `em ${label}` : `há ${label}`;
}
