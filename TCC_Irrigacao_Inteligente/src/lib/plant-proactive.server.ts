import {
  checkinSignal,
  cooldownHoursFor,
  evaluatePlantSignals,
  fallbackMessage,
  type AlertKind,
} from "@/lib/plant-proactive";
import { supabaseAdmin } from "@/integrations/supabase/client.server";
import { sendPushToSubscriptions } from "@/lib/push.server";

const OLLAMA_BASE_URL = process.env["OLLAMA_BASE_URL"] ?? "http://localhost:11434";
const OLLAMA_MODEL = process.env["OLLAMA_MODEL"] ?? "llama3.1";

async function phraseSignalAsPlant(
  plantName: string,
  speciesName: string | null,
  summary: string,
  fallback: string,
): Promise<string> {
  const prompt = [
    `Você é a planta "${plantName}"${speciesName ? ` (${speciesName})` : ""} do app Plantinha.`,
    `Fale em português do Brasil, em primeira pessoa, de forma curta (1-2 frases), fofa mas objetiva.`,
    `Fato a comunicar ao seu dono, sem inventar nada além disso: ${summary}`,
  ].join("\n");

  try {
    const response = await fetch(`${OLLAMA_BASE_URL}/api/chat`, {
      method: "POST",
      headers: { "content-type": "application/json" },
      body: JSON.stringify({
        model: OLLAMA_MODEL,
        messages: [{ role: "user", content: prompt }],
        stream: false,
      }),
    });
    if (!response.ok) throw new Error(`Ollama respondeu ${response.status}`);
    const json = (await response.json()) as { message?: { content?: string } };
    return json.message?.content?.trim() || fallback;
  } catch (err) {
    console.error("[plant-proactive] Ollama indisponível, usando mensagem padrão:", err);
    return fallback;
  }
}

/**
 * Avalia uma planta, respeita cooldown por tipo de alerta, grava a
 * mensagem proativa e dispara push. Usa supabaseAdmin porque também
 * roda fora do contexto de uma requisição do usuário (varredura
 * periódica não tem token de autenticação).
 *
 * Exportado (não mais local) porque agora é chamado via import()
 * dinâmico a partir de plant-proactive-actions.ts, dentro do handler
 * de um createServerFn — assim o código client-safe nunca precisa
 * importar este módulo estaticamente.
 */
export async function processPlant(plantId: string, opts: { includeCheckin: boolean }) {
  const db = supabaseAdmin;

  const { data: plant } = await db
    .from("plants")
    .select("id, owner_id, name, species_id, moisture_threshold, proactive_enabled")
    .eq("id", plantId)
    .maybeSingle();
  if (!plant || !plant.proactive_enabled) return;

  const { data: species } = plant.species_id
    ? await db.from("species_profiles").select("*").eq("id", plant.species_id).maybeSingle()
    : { data: null };

  const [{ data: readings }, { data: waterings }] = await Promise.all([
    db
      .from("readings")
      .select("soil_moisture, temperature, recorded_at")
      .eq("plant_id", plantId)
      .order("recorded_at", { ascending: false })
      .limit(1),
    db
      .from("waterings")
      .select("watered_at")
      .eq("plant_id", plantId)
      .order("watered_at", { ascending: false })
      .limit(1),
  ]);

  const signals = evaluatePlantSignals({
    species: species ?? null,
    manualThreshold: plant.moisture_threshold,
    latestReading: readings?.[0] ?? null,
    lastWatering: waterings?.[0] ?? null,
  });

  const chosen = signals[0] ?? (opts.includeCheckin ? checkinSignal(species ?? null) : null);
  if (!chosen) return;

  const cooldownHours = cooldownHoursFor(chosen.kind as AlertKind);
  const { data: lastSameKind } = await db
    .from("plant_chat_messages")
    .select("created_at")
    .eq("plant_id", plantId)
    .eq("alert_kind", chosen.kind)
    .eq("is_proactive", true)
    .order("created_at", { ascending: false })
    .limit(1)
    .maybeSingle();

  if (lastSameKind) {
    const hoursSince = (Date.now() - new Date(lastSameKind.created_at).getTime()) / 3_600_000;
    if (hoursSince < cooldownHours) return; // já avisou recentemente
  }

  const fallback = fallbackMessage(chosen.kind as AlertKind, plant.name);
  const content = await phraseSignalAsPlant(
    plant.name,
    species?.common_name ?? null,
    chosen.summary,
    fallback,
  );

  await db.from("plant_chat_messages").insert({
    plant_id: plantId,
    role: "assistant",
    content,
    is_proactive: true,
    alert_kind: chosen.kind,
  });

  const { data: subs } = await db
    .from("push_subscriptions")
    .select("id, endpoint, p256dh, auth_key")
    .eq("owner_id", plant.owner_id);

  if (subs && subs.length > 0) {
    const { staleIds } = await sendPushToSubscriptions(subs, {
      title: plant.name,
      body: content,
      url: `/plantas/${plantId}/assistente`,
    });
    if (staleIds.length > 0) {
      await db.from("push_subscriptions").delete().in("id", staleIds);
    }
  }
}

/**
 * Varredura periódica (chamada pelo agendador do servidor) — cobre
 * plantas sem leitura recente e manda um "oi, tudo bem" ocasional.
 */
export async function runProactiveSweep() {
  const { data: plants } = await supabaseAdmin
    .from("plants")
    .select("id")
    .eq("proactive_enabled", true);

  for (const plant of plants ?? []) {
    try {
      await processPlant(plant.id, { includeCheckin: true });
    } catch (err) {
      console.error(`[plant-proactive] Falha ao processar planta ${plant.id}:`, err);
    }
  }
}