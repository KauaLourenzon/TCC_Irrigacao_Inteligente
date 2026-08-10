import { createFileRoute } from "@tanstack/react-router";
import { createClient } from "@supabase/supabase-js";
import { z } from "zod";

const telemetrySchema = z.object({
  soil_moisture: z.number().min(0).max(100),
  temperature: z.number().min(-50).max(100).optional(),
  recorded_at: z.string().optional(),
});

function serverClient() {
  const key = process.env["SUPABASE_PUBLISHABLE_KEY"]!;
  return createClient(process.env["SUPABASE_URL"]!, key, {
    auth: { persistSession: false },
    global: {
      fetch: (input, init) => {
        const h = new Headers(init?.headers);
        if (key.startsWith("sb_") && h.get("Authorization") === `Bearer ${key}`)
          h.delete("Authorization");
        h.set("apikey", key);
        return fetch(input, { ...init, headers: h });
      },
    },
  });
}

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "content-type",
  "Access-Control-Allow-Methods": "GET, POST, OPTIONS",
};

/**
 * Camada de integração com o ESP32 (desacoplada do front):
 *  POST -> envia leitura { soil_moisture, temperature }
 *  GET  -> devolve o estado desejado: se deve regar agora, modo e limite
 */
export const Route = createFileRoute("/api/public/esp32/telemetry")({
  server: {
    handlers: {
      OPTIONS: async () => new Response(null, { status: 204, headers: cors }),

      POST: async ({ request }) => {
        const parsed = telemetrySchema.safeParse(await request.json().catch(() => null));
        if (!parsed.success) {
          return Response.json(
            { ok: false, error: "payload inválido" },
            { status: 400, headers: cors },
          );
        }
        const supabase = serverClient();
        const { error } = await supabase.from("readings").insert({
          soil_moisture: parsed.data.soil_moisture,
          temperature: parsed.data.temperature ?? null,
          recorded_at: parsed.data.recorded_at ?? new Date().toISOString(),
        });
        if (error) {
          return Response.json({ ok: false, error: error.message }, { status: 500, headers: cors });
        }
        return Response.json({ ok: true }, { headers: cors });
      },

      GET: async () => {
        const supabase = serverClient();
        const { data } = await supabase
          .from("plant")
          .select("mode, moisture_threshold, water_requested_at, schedule_times, schedule_days")
          .order("created_at", { ascending: true })
          .limit(1)
          .maybeSingle();

        const requestedAt = data?.water_requested_at
          ? new Date(data.water_requested_at).getTime()
          : 0;
        const shouldWater = requestedAt > 0 && Date.now() - requestedAt < 60_000;

        return Response.json(
          {
            should_water: shouldWater,
            mode: data?.mode ?? "auto",
            moisture_threshold: data?.moisture_threshold ?? 35,
            schedule_times: data?.schedule_times ?? [],
            schedule_days: data?.schedule_days ?? [],
          },
          { headers: cors },
        );
      },
    },
  },
});
