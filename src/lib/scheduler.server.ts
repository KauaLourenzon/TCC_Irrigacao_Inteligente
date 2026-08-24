import cron from "node-cron";

import { runProactiveSweep } from "@/lib/plant-proactive.server";

// server.ts recarrega em dev (HMR) — sem essa trava global, cada reload
// registraria um novo cron e duplicaria os avisos proativos.
const GLOBAL_KEY = "__plantinha_proactive_scheduler__";
const g = globalThis as unknown as Record<string, boolean>;

export function startProactiveScheduler() {
  if (g[GLOBAL_KEY]) return;
  g[GLOBAL_KEY] = true;

  const minutes = Number(process.env["PROACTIVE_SWEEP_MINUTES"] ?? "20");
  const expression = `*/${Math.max(1, minutes)} * * * *`;

  cron.schedule(expression, () => {
    runProactiveSweep().catch((err) =>
      console.error("[scheduler] Falha na varredura proativa:", err),
    );
  });

  console.log(`[scheduler] Assistente proativo agendado a cada ${minutes} min.`);
}