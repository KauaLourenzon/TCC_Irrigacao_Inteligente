import { createServerFn } from "@tanstack/react-start";
import { z } from "zod";

import { requireSupabaseAuth } from "@/integrations/supabase/auth-middleware";

const evaluateInput = z.object({ plantId: z.string().uuid() });

/** Chamado pelo cliente logo após gravar uma leitura nova (reativo). */
export const evaluatePlantNow = createServerFn({ method: "POST" })
  .middleware([requireSupabaseAuth])
  .validator((input: unknown) => evaluateInput.parse(input))
  .handler(async ({ data, context }) => {
    const { data: plant } = await context.supabase
      .from("plants")
      .select("id")
      .eq("id", data.plantId)
      .maybeSingle();
    if (!plant) return { checked: false };

    // Import dinâmico: este arquivo (plant-proactive-actions.ts) é importado
    // estaticamente por código de CLIENTE (push-client.ts, use-serial-sensor.ts).
    // plant-proactive.server.ts usa supabaseAdmin e chama o Ollama, então não
    // pode aparecer no import estático de um arquivo client-safe. Importando
    // dinamicamente aqui dentro do handler, o código só roda (e só é
    // bundlado) no servidor.
    const { processPlant } = await import("@/lib/plant-proactive.server");
    await processPlant(data.plantId, { includeCheckin: false });
    return { checked: true };
  });

const subscribeInput = z.object({
  endpoint: z.string().url(),
  keys: z.object({ p256dh: z.string(), auth: z.string() }),
});

/** Salva a inscrição de push notification do usuário logado. */
export const savePushSubscription = createServerFn({ method: "POST" })
  .middleware([requireSupabaseAuth])
  .validator((input: unknown) => subscribeInput.parse(input))
  .handler(async ({ data, context }) => {
    const { error } = await context.supabase.from("push_subscriptions").upsert(
      {
        owner_id: context.userId,
        endpoint: data.endpoint,
        p256dh: data.keys.p256dh,
        auth_key: data.keys.auth,
      },
      { onConflict: "endpoint" },
    );
    if (error) throw error;
    return { ok: true };
  });