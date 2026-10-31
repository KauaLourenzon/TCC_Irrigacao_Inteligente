import type { SpeciesProfile } from "@/lib/species";

export type AlertKind =
  | "thirsty"
  | "soggy"
  | "hot"
  | "cold"
  | "stale_reading"
  | "overdue_watering"
  | "checkin";

export type ProactiveSignal = {
  kind: AlertKind;
  severity: "info" | "warning";
  summary: string; // fato objetivo, base do prompt pra IA
};

const COOLDOWN_HOURS: Record<AlertKind, number> = {
  thirsty: 6,
  soggy: 6,
  hot: 4,
  cold: 4,
  stale_reading: 12,
  overdue_watering: 12,
  checkin: 20,
};

export function cooldownHoursFor(kind: AlertKind) {
  return COOLDOWN_HOURS[kind];
}

type EvaluateInput = {
  species: SpeciesProfile | null;
  manualThreshold: number;
  latestReading: { soil_moisture: number; temperature: number | null; recorded_at: string } | null;
  lastWatering: { watered_at: string } | null;
  now?: Date;
};

/**
 * Regras determinísticas que decidem SE existe algo a avisar. A IA
 * (Ollama) entra só depois, pra redigir — a decisão não depende do
 * modelo, então o assistente continua proativo mesmo se o Ollama cair.
 */
export function evaluatePlantSignals(input: EvaluateInput): ProactiveSignal[] {
  const now = input.now ?? new Date();
  const signals: ProactiveSignal[] = [];
  const { species, latestReading, lastWatering } = input;

  if (!latestReading) return signals;

  const readingAgeHours =
    (now.getTime() - new Date(latestReading.recorded_at).getTime()) / 3_600_000;

  if (readingAgeHours >= 12) {
    signals.push({
      kind: "stale_reading",
      severity: "warning",
      summary: `Sem leitura do sensor há ${Math.round(readingAgeHours)} horas.`,
    });
    // dado velho demais pra confiar nos alertas de umidade/temperatura
    return signals;
  }

  const moistureMin = species?.ideal_moisture_min ?? input.manualThreshold;
  const moistureMax = species?.ideal_moisture_max ?? 80;
  const moisture = Number(latestReading.soil_moisture);

  if (moisture < moistureMin) {
    signals.push({
      kind: "thirsty",
      severity: moisture < moistureMin - 10 ? "warning" : "info",
      summary: `Umidade do solo em ${Math.round(moisture)}%, abaixo do ideal (${moistureMin}-${moistureMax}%)${
        species ? ` para ${species.common_name}` : ""
      }.`,
    });
  } else if (moisture > moistureMax) {
    signals.push({
      kind: "soggy",
      severity: moisture > moistureMax + 15 ? "warning" : "info",
      summary: `Umidade do solo em ${Math.round(moisture)}%, acima do ideal (${moistureMin}-${moistureMax}%)${
        species ? ` para ${species.common_name}` : ""
      }.`,
    });
  }

  if (latestReading.temperature != null && species) {
    const temp = Number(latestReading.temperature);
    if (temp > species.ideal_temp_max) {
      signals.push({
        kind: "hot",
        severity: "info",
        summary: `Temperatura em ${temp.toFixed(1)}°C, acima do ideal (até ${species.ideal_temp_max}°C).`,
      });
    } else if (temp < species.ideal_temp_min) {
      signals.push({
        kind: "cold",
        severity: "info",
        summary: `Temperatura em ${temp.toFixed(1)}°C, abaixo do ideal (mín. ${species.ideal_temp_min}°C).`,
      });
    }
  }

  if (species) {
    const expectedIntervalDays = species.watering_frequency_days;
    const daysSinceWatering = lastWatering
      ? (now.getTime() - new Date(lastWatering.watered_at).getTime()) / 86_400_000
      : null;
    if (daysSinceWatering != null && daysSinceWatering > expectedIntervalDays * 1.5) {
      signals.push({
        kind: "overdue_watering",
        severity: "warning",
        summary: `Já se passaram ${Math.round(daysSinceWatering)} dias desde a última rega; o esperado para ${species.common_name} é por volta de ${expectedIntervalDays} dias.`,
      });
    }
  }

  return signals;
}

/** "Tudo bem, só passando pra dizer oi" — usado no sweep periódico
 * quando nenhum problema é detectado, pra manter o assistente ativo. */
export function checkinSignal(species: SpeciesProfile | null): ProactiveSignal {
  return {
    kind: "checkin",
    severity: "info",
    summary: species
      ? `Está tudo dentro do esperado para ${species.common_name}.`
      : "Está tudo dentro do esperado.",
  };
}

export function fallbackMessage(kind: AlertKind, plantName: string): string {
  switch (kind) {
    case "thirsty":
      return `Ei, sou a ${plantName}! Meu solo está seco, dá uma regadinha em mim? 💧`;
    case "soggy":
      return `${plantName} aqui — acho que exagerou na água, meu solo está encharcado. Segura a rega por um tempo!`;
    case "hot":
      return `${plantName}: está bem quente por aqui, um pouco de sombra ajudaria.`;
    case "cold":
      return `${plantName}: estou sentindo frio, será que dá pra me colocar num lugar mais aquecido?`;
    case "stale_reading":
      return `Faz um tempo que não recebo notícias do meu sensor — está tudo bem com a conexão USB?`;
    case "overdue_watering":
      return `${plantName}: acho que já passou da hora da minha próxima rega, pode conferir?`;
    case "checkin":
      return `Oi, é a ${plantName}! Só passando pra avisar que está tudo tranquilo por aqui. 🌱`;
  }
}