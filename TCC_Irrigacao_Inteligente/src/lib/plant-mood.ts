export type MoodKey = "thirsty" | "happy" | "soggy" | "hot" | "cold" | "unknown";

export type Mood = {
  key: MoodKey;
  title: string;
  message: string;
};

/**
 * Combina umidade e temperatura, priorizando o estado mais crítico.
 * Ordem de prioridade: solo encharcado > sede > calor extremo > frio > feliz.
 */
export function resolveMood(
  moisture: number | null,
  temperature: number | null,
  threshold: number,
): Mood {
  if (moisture === null) {
    return {
      key: "unknown",
      title: "Sem leitura ainda",
      message: "Esperando o primeiro sinal do sensor…",
    };
  }

  const hot = temperature !== null && temperature >= 30;
  const cold = temperature !== null && temperature <= 12;
  const extra = hot ? " E está um calorão aqui!" : cold ? " E está um friozinho!" : "";

  if (moisture > 80) {
    return {
      key: "soggy",
      title: "Encharcada",
      message: `Ai… muita água no vaso (${Math.round(moisture)}%).${extra}`,
    };
  }
  if (moisture < threshold) {
    return {
      key: "thirsty",
      title: "Com sede",
      message: `Umidade em ${Math.round(moisture)}%, abaixo do seu limite de ${threshold}%.${extra}`,
    };
  }
  if (hot) {
    return {
      key: "hot",
      title: "Calor demais",
      message: `Solo ok, mas ${Math.round(temperature!)}°C é quente pra mim.`,
    };
  }
  if (cold) {
    return {
      key: "cold",
      title: "Friozinho",
      message: `Solo ok, mas ${Math.round(temperature!)}°C me deixa tremendo.`,
    };
  }
  return {
    key: "happy",
    title: "Tudo certinho",
    message: `Umidade em ${Math.round(moisture)}% — do jeitinho que eu gosto.`,
  };
}
