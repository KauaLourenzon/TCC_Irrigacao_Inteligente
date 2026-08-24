import { supabase } from "@/integrations/supabase/client";

export type WateringMode = "manual" | "scheduled" | "auto";

export type Plant = {
  id: string;
  owner_id: string;
  name: string;
  species: string | null; // continua sincronizado automaticamente pelo trigger
  species_id: string | null;
  mode: WateringMode;
  moisture_threshold: number;
  schedule_times: string[];
  schedule_days: number[];
  water_requested_at: string | null;
  created_at: string;
};


export type Reading = {
  id: string;
  plant_id: string;
  soil_moisture: number;
  temperature: number | null;
  recorded_at: string;
};

export type Watering = {
  id: string;
  plant_id: string;
  source: string;
  soil_moisture: number | null;
  watered_at: string;
};

export type ChatMessage = {
  id: string;
  plant_id: string;
  role: "user" | "assistant";
  content: string;
  created_at: string;
};


const PLANT_COLUMNS =
  "id, owner_id, name, species, species_id, mode, moisture_threshold, schedule_times, schedule_days, water_requested_at, created_at";

/** Todas as plantas do usuário logado (RLS garante que só vêm as dele). */
export async function fetchPlants(): Promise<Plant[]> {
  const { data, error } = await supabase
    .from("plants")
    .select(PLANT_COLUMNS)
    .order("created_at", { ascending: true });
  if (error) throw error;
  return (data ?? []) as Plant[];
}

export async function fetchPlant(plantId: string): Promise<Plant> {
  const { data, error } = await supabase
    .from("plants")
    .select(PLANT_COLUMNS)
    .eq("id", plantId)
    .maybeSingle();
  if (error) throw error;
  if (!data) throw new Error("Planta não encontrada");
  return data as Plant;
}

export async function createPlant(input: { name: string; speciesId: string }): Promise<Plant> {
  const {
    data: { user },
  } = await supabase.auth.getUser();
  if (!user) throw new Error("Você precisa estar logado para cadastrar uma planta.");

  const { data, error } = await supabase
    .from("plants")
    .insert({ owner_id: user.id, name: input.name, species_id: input.speciesId })
    .select(PLANT_COLUMNS)
    .single();
  if (error) throw error;
  return data as Plant;
}

export async function deletePlant(plantId: string) {
  const { error } = await supabase.from("plants").delete().eq("id", plantId);
  if (error) throw error;
}

export async function fetchReadings(plantId: string, limit = 24): Promise<Reading[]> {
  const { data, error } = await supabase
    .from("readings")
    .select("id, plant_id, soil_moisture, temperature, recorded_at")
    .eq("plant_id", plantId)
    .order("recorded_at", { ascending: false })
    .limit(limit);
  if (error) throw error;
  return (data ?? []) as Reading[];
}

/** Usado pelo hook de sensor USB para gravar uma leitura vinda do ESP32. */
export async function insertReading(
  plantId: string,
  reading: { soil_moisture: number; temperature?: number | null; recorded_at?: string },
) {
  const { error } = await supabase.from("readings").insert({
    plant_id: plantId,
    soil_moisture: reading.soil_moisture,
    temperature: reading.temperature ?? null,
    recorded_at: reading.recorded_at ?? new Date().toISOString(),
  });
  if (error) throw error;
}

export async function fetchWaterings(plantId: string, limit = 10): Promise<Watering[]> {
  const { data, error } = await supabase
    .from("waterings")
    .select("id, plant_id, source, soil_moisture, watered_at")
    .eq("plant_id", plantId)
    .order("watered_at", { ascending: false })
    .limit(limit);
  if (error) throw error;
  return (data ?? []) as Watering[];
}

export async function updatePlant(id: string, patch: Partial<Plant>) {
  const { error } = await supabase
    .from("plants")
    .update({ ...patch, updated_at: new Date().toISOString() })
    .eq("id", id);
  if (error) throw error;
}

/** Registra uma rega e envia o pedido de acionamento para o ESP32 conectado. */
export async function triggerWatering(
  plantId: string,
  source: WateringMode,
  soilMoisture: number | null,
) {
  const { error } = await supabase
    .from("waterings")
    .insert({ plant_id: plantId, source, soil_moisture: soilMoisture });
  if (error) throw error;
  await updatePlant(plantId, { water_requested_at: new Date().toISOString() });
}

/**
 * Estimativa do próximo regamento: usa o intervalo médio entre as últimas
 * regas. Sem histórico suficiente, cai para um intervalo padrão de 3 dias.
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

/**
 * Acha a planta certa a partir de um texto livre com o nome dela.
 * Usado pela busca "falar com uma planta pelo nome" e pelo assistente
 * global. Prioriza correspondência exata; se houver mais de uma planta
 * cujo nome contém o termo digitado, retorna null (ambíguo).
 */
export function findPlantByName(plants: Plant[], query: string): Plant | null {
  const q = query.trim().toLowerCase();
  if (!q) return null;

  const exact = plants.find((p) => p.name.toLowerCase() === q);
  if (exact) return exact;

  const partial = plants.filter(
    (p) => p.name.toLowerCase().includes(q) || q.includes(p.name.toLowerCase()),
  );
  return partial.length === 1 ? partial[0]! : null;
}

export async function fetchChatMessages(plantId: string, limit = 50): Promise<ChatMessage[]> {
  const { data, error } = await supabase
    .from("plant_chat_messages")
    .select("id, plant_id, role, content, created_at")
    .eq("plant_id", plantId)
    .order("created_at", { ascending: true })
    .limit(limit);
  if (error) throw error;
  return (data ?? []) as ChatMessage[];
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
