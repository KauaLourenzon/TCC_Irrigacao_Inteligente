import { createServerFn } from "@tanstack/react-start";
import { z } from "zod";

import { requireSupabaseAuth } from "@/integrations/supabase/auth-middleware";

const OLLAMA_BASE_URL = process.env["OLLAMA_BASE_URL"] ?? "http://localhost:11434";
const OLLAMA_MODEL = process.env["OLLAMA_MODEL"] ?? "llama3.1";

const askInput = z.object({
  plantId: z.string().uuid(),
  message: z.string().trim().min(1).max(2000),
});

type OllamaMessage = { role: "system" | "user" | "assistant"; content: string };

function buildSystemPrompt(
  plant: { name: string; species: string | null; mode: string; moisture_threshold: number },
  latestReading: { soil_moisture: number; temperature: number | null; recorded_at: string } | null,
  recentWaterings: { source: string; watered_at: string }[],
) {
  const especie = plant.species ? ` (espécie: ${plant.species})` : "";
  const leitura = latestReading
    ? `Última leitura: ${latestReading.soil_moisture}% de umidade do solo${
        latestReading.temperature != null ? `, ${latestReading.temperature}°C` : ""
      }, registrada em ${latestReading.recorded_at}.`
    : "Ainda não há nenhuma leitura de sensor registrada para esta planta.";
  const regas =
    recentWaterings.length > 0
      ? `Últimas regas: ${recentWaterings.map((w) => `${w.source} em ${w.watered_at}`).join("; ")}.`
      : "Ainda não há histórico de regas.";

  return [
    `Você é o assistente virtual da planta "${plant.name}"${especie}, parte do app Plantinha.`,
    `Fale em português do Brasil, em primeira pessoa como se fosse a própria planta (de forma fofa e simpática, mas sem exagerar), dando conselhos de cuidado reais e úteis baseados nos dados do sensor.`,
    `Modo de rega atual: ${plant.mode}. Limite de umidade configurado: ${plant.moisture_threshold}%.`,
    leitura,
    regas,
    `Se os dados indicarem solo seco, encharcado, muito quente ou muito frio, avise e sugira uma ação concreta.`,
    `Se não tiver certeza sobre algo específico da espécie, seja honesto em vez de inventar.`,
    `Responda de forma curta (poucos parágrafos), a não ser que o usuário peça mais detalhes.`,
  ].join("\n");
}

/**
 * Conversa com o assistente de UMA planta específica, usando um modelo
 * rodando localmente via Ollama (sem depender de internet/API paga).
 * Precisa que o usuário esteja logado (auth middleware) e que a planta
 * pertença a ele (garantido pelas policies de RLS do Supabase).
 */
export const askPlantAssistant = createServerFn({ method: "POST" })
  .middleware([requireSupabaseAuth])
  .validator((input: unknown) => askInput.parse(input))
  .handler(async ({ data, context }) => {
    const { supabase, userId } = context;

    const { data: plant, error: plantError } = await supabase
      .from("plants")
      .select("id, owner_id, name, species, mode, moisture_threshold")
      .eq("id", data.plantId)
      .maybeSingle();

    if (plantError || !plant) {
      throw new Error("Planta não encontrada.");
    }
    if (plant.owner_id !== userId) {
      throw new Error("Você não tem permissão para falar com essa planta.");
    }

    const [{ data: readings }, { data: waterings }, { data: history }] = await Promise.all([
      supabase
        .from("readings")
        .select("soil_moisture, temperature, recorded_at")
        .eq("plant_id", data.plantId)
        .order("recorded_at", { ascending: false })
        .limit(1),
      supabase
        .from("waterings")
        .select("source, watered_at")
        .eq("plant_id", data.plantId)
        .order("watered_at", { ascending: false })
        .limit(3),
      supabase
        .from("plant_chat_messages")
        .select("role, content")
        .eq("plant_id", data.plantId)
        .order("created_at", { ascending: true })
        .limit(20),
    ]);

    await supabase
      .from("plant_chat_messages")
      .insert({ plant_id: data.plantId, role: "user", content: data.message });

    const messages: OllamaMessage[] = [
      { role: "system", content: buildSystemPrompt(plant, readings?.[0] ?? null, waterings ?? []) },
      ...(history ?? []).map((m) => ({ role: m.role as "user" | "assistant", content: m.content })),
      { role: "user", content: data.message },
    ];

    let reply: string;
    try {
      const response = await fetch(`${OLLAMA_BASE_URL}/api/chat`, {
        method: "POST",
        headers: { "content-type": "application/json" },
        body: JSON.stringify({ model: OLLAMA_MODEL, messages, stream: false }),
      });
      if (!response.ok) {
        throw new Error(`Ollama respondeu ${response.status}`);
      }
      const json = (await response.json()) as { message?: { content?: string } };
      reply = json.message?.content?.trim() || "Hmm, não consegui pensar em nada agora. 🌱";
    } catch (err) {
      console.error("[plant-assistant] Falha ao chamar o Ollama:", err);
      reply = `Não consegui falar com o Ollama agora. Confira se ele está rodando (comando \`ollama serve\`) em ${OLLAMA_BASE_URL} e se o modelo "${OLLAMA_MODEL}" foi baixado (\`ollama pull ${OLLAMA_MODEL}\`).`;
    }

    await supabase
      .from("plant_chat_messages")
      .insert({ plant_id: data.plantId, role: "assistant", content: reply });

    return { reply };
  });
