import { createFileRoute } from "@tanstack/react-router";
import { useQuery, useQueryClient } from "@tanstack/react-query";
import { useEffect, useMemo, useState } from "react";
import { Droplets, Thermometer, Clock, CalendarClock, Moon, Sun, SunMoon, Sprout } from "lucide-react";
import { toast } from "sonner";

import { PotMascot } from "@/components/PotMascot";
import { supabase } from "@/integrations/supabase/client";
import { useTheme } from "@/hooks/use-theme";
import { resolveMood } from "@/lib/plant-mood";
import {
  MODE_LABEL,
  WEEK_DAYS,
  estimateNextWatering,
  fetchPlant,
  fetchReadings,
  fetchWaterings,
  formatDateTime,
  relativeFromNow,
  triggerWatering,
  updatePlant,
  type WateringMode,
} from "@/lib/plant-data";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Slider } from "@/components/ui/slider";
import { Switch } from "@/components/ui/switch";

export const Route = createFileRoute("/")({
  head: () => ({
    meta: [
      { title: "Plantinha — Monitor de umidade e rega da sua planta" },
      {
        name: "description",
        content:
          "Acompanhe umidade do solo, temperatura e regas da sua planta em tempo real com sensor ESP32, e deixe o vasinho contar como está se sentindo.",
      },
      { property: "og:title", content: "Plantinha — Monitor da sua planta" },
      {
        property: "og:description",
        content:
          "Dashboard fofo para monitorar umidade, temperatura e rega automática da sua planta com ESP32.",
      },
      { property: "og:type", content: "website" },
      { name: "twitter:card", content: "summary_large_image" },
    ],
  }),
  component: Dashboard,
});

function useClock() {
  const [now, setNow] = useState(() => new Date());
  useEffect(() => {
    const id = window.setInterval(() => setNow(new Date()), 1000);
    return () => window.clearInterval(id);
  }, []);
  return now;
}

function Card({
  icon,
  label,
  children,
  accent,
}: {
  icon: React.ReactNode;
  label: string;
  children: React.ReactNode;
  accent?: string;
}) {
  return (
    <section className="card-soft p-5">
      <header className="flex items-center gap-2 text-sm text-muted-foreground">
        <span
          className="grid size-8 shrink-0 place-items-center rounded-full"
          style={{ backgroundColor: `color-mix(in oklab, ${accent ?? "var(--color-primary)"} 18%, transparent)`, color: accent ?? "var(--color-primary)" }}
        >
          {icon}
        </span>
        <span className="truncate font-semibold">{label}</span>
      </header>
      <div className="mt-3">{children}</div>
    </section>
  );
}

function Gauge({ value, color }: { value: number; color: string }) {
  const r = 42;
  const c = 2 * Math.PI * r;
  const pct = Math.max(0, Math.min(100, value));
  return (
    <div className="relative mx-auto size-32">
      <svg viewBox="0 0 100 100" className="size-full -rotate-90">
        <circle cx="50" cy="50" r={r} fill="none" stroke="var(--color-muted)" strokeWidth="10" />
        <circle
          cx="50"
          cy="50"
          r={r}
          fill="none"
          stroke={color}
          strokeWidth="10"
          strokeLinecap="round"
          strokeDasharray={c}
          strokeDashoffset={c - (c * pct) / 100}
          style={{ transition: "stroke-dashoffset 600ms ease" }}
        />
      </svg>
      <div className="absolute inset-0 grid place-items-center">
        <span className="font-display text-2xl font-bold">{Math.round(pct)}%</span>
      </div>
    </div>
  );
}

function Dashboard() {
  const queryClient = useQueryClient();
  const now = useClock();
  const { choice, setChoice } = useTheme();

  const plantQuery = useQuery({ queryKey: ["plant"], queryFn: fetchPlant });
  const readingsQuery = useQuery({ queryKey: ["readings"], queryFn: () => fetchReadings(24) });
  const wateringsQuery = useQuery({ queryKey: ["waterings"], queryFn: () => fetchWaterings(10) });

  const plant = plantQuery.data;
  const readings = readingsQuery.data ?? [];
  const waterings = wateringsQuery.data ?? [];
  const latest = readings[0] ?? null;

  const [nameDraft, setNameDraft] = useState("");
  const [thresholdDraft, setThresholdDraft] = useState(35);
  const [timeDraft, setTimeDraft] = useState("08:00");

  useEffect(() => {
    if (plant) {
      setNameDraft(plant.name);
      setThresholdDraft(plant.moisture_threshold);
    }
  }, [plant?.id, plant?.name, plant?.moisture_threshold]);

  // Leituras e regas em tempo real (o ESP32 escreve, o painel reage)
  useEffect(() => {
    const channel = supabase
      .channel("plant-live")
      .on("postgres_changes", { event: "*", schema: "public", table: "readings" }, () => {
        queryClient.invalidateQueries({ queryKey: ["readings"] });
      })
      .on("postgres_changes", { event: "*", schema: "public", table: "waterings" }, () => {
        queryClient.invalidateQueries({ queryKey: ["waterings"] });
      })
      .on("postgres_changes", { event: "*", schema: "public", table: "plant" }, () => {
        queryClient.invalidateQueries({ queryKey: ["plant"] });
      })
      .subscribe();
    return () => {
      supabase.removeChannel(channel);
    };
  }, [queryClient]);

  const mood = useMemo(
    () =>
      resolveMood(
        latest ? Number(latest.soil_moisture) : null,
        latest?.temperature != null ? Number(latest.temperature) : null,
        plant?.moisture_threshold ?? 35,
      ),
    [latest, plant?.moisture_threshold],
  );

  const nextWatering = useMemo(() => estimateNextWatering(waterings), [waterings]);

  async function savePlant(patch: Parameters<typeof updatePlant>[1], message: string) {
    if (!plant) return;
    try {
      await updatePlant(plant.id, patch);
      await queryClient.invalidateQueries({ queryKey: ["plant"] });
      toast.success(message);
    } catch {
      toast.error("Não conseguimos salvar agora. Tente de novo.");
    }
  }

  async function waterNow() {
    if (!plant) return;
    try {
      await triggerWatering(plant.id, "manual", latest ? Number(latest.soil_moisture) : null);
      await Promise.all([
        queryClient.invalidateQueries({ queryKey: ["waterings"] }),
        queryClient.invalidateQueries({ queryKey: ["plant"] }),
      ]);
      toast.success("Rega enviada para o vasinho 💧");
    } catch {
      toast.error("Não foi possível acionar a rega.");
    }
  }

  const moistureColor =
    mood.key === "thirsty"
      ? "var(--color-sun)"
      : mood.key === "soggy"
        ? "var(--color-water)"
        : "var(--color-leaf)";

  const themeOptions: { key: typeof choice; icon: React.ReactNode; label: string }[] = [
    { key: "auto", icon: <SunMoon className="size-4" />, label: "Automático" },
    { key: "light", icon: <Sun className="size-4" />, label: "Claro" },
    { key: "dark", icon: <Moon className="size-4" />, label: "Escuro" },
  ];

  return (
    <main className="mx-auto w-full max-w-5xl px-4 pb-16 pt-6 sm:px-6 lg:px-8">
      <header className="grid grid-cols-[minmax(0,1fr)_auto] items-center gap-4 sm:flex sm:justify-between">
        <div className="flex min-w-0 items-center gap-3">
          <span className="grid size-11 shrink-0 place-items-center rounded-2xl bg-secondary text-primary">
            <Sprout className="size-6" />
          </span>
          <div className="min-w-0">
            <p className="text-xs font-semibold uppercase tracking-wide text-muted-foreground">
              Minha plantinha
            </p>
            <h1 className="truncate text-2xl font-bold sm:text-3xl">
              {plant?.name ?? "Carregando…"}
            </h1>
          </div>
        </div>
        <div className="flex shrink-0 items-center gap-1 rounded-full border bg-card p-1">
          {themeOptions.map((option) => (
            <button
              key={option.key}
              onClick={() => setChoice(option.key)}
              aria-label={`Tema ${option.label}`}
              className={`grid size-8 place-items-center rounded-full transition-colors ${
                choice === option.key
                  ? "bg-primary text-primary-foreground"
                  : "text-muted-foreground hover:bg-secondary"
              }`}
            >
              {option.icon}
            </button>
          ))}
        </div>
      </header>

      {/* Mascote + estado */}
      <section className="card-soft mt-6 grid gap-6 p-6 sm:grid-cols-[200px_minmax(0,1fr)] sm:items-center">
        <PotMascot mood={mood.key} className="animate-bob mx-auto w-40 sm:w-full" />
        <div>
          <span className="inline-flex items-center gap-2 rounded-full bg-secondary px-3 py-1 text-xs font-bold text-secondary-foreground">
            {MODE_LABEL[(plant?.mode ?? "auto") as WateringMode]}
          </span>
          <h2 className="mt-3 text-2xl font-bold">{mood.title}</h2>
          <p className="mt-1 text-muted-foreground">{mood.message}</p>
          <Button onClick={waterNow} className="mt-5 rounded-full px-6" disabled={!plant}>
            <Droplets className="size-4" /> Regar agora
          </Button>
        </div>
      </section>

      {/* Dados */}
      <div className="mt-6 grid gap-4 sm:grid-cols-2 lg:grid-cols-4">
        <Card icon={<Droplets className="size-4" />} label="Umidade do solo" accent={moistureColor}>
          <Gauge value={latest ? Number(latest.soil_moisture) : 0} color={moistureColor} />
          <p className="mt-2 text-center text-xs text-muted-foreground">
            {latest ? `Leitura ${relativeFromNow(latest.recorded_at)}` : "Sem leituras"}
          </p>
        </Card>

        <Card icon={<Thermometer className="size-4" />} label="Temperatura" accent="var(--color-terracotta)">
          <p className="font-display text-4xl font-bold">
            {latest?.temperature != null ? `${Number(latest.temperature).toFixed(1)}°C` : "—"}
          </p>
          <p className="mt-2 text-xs text-muted-foreground">Ambiente medido pelo sensor</p>
        </Card>

        <Card icon={<Clock className="size-4" />} label="Horário atual" accent="var(--color-water)">
          <p className="font-display text-4xl font-bold tabular-nums">
            {now.toLocaleTimeString("pt-BR", { hour: "2-digit", minute: "2-digit" })}
          </p>
          <p className="mt-2 text-xs text-muted-foreground">
            {now.toLocaleDateString("pt-BR", { weekday: "long", day: "2-digit", month: "long" })}
          </p>
        </Card>

        <Card icon={<CalendarClock className="size-4" />} label="Regamentos" accent="var(--color-sun)">
          <p className="text-xs font-semibold uppercase text-muted-foreground">Último</p>
          <p className="font-display text-xl font-bold">
            {formatDateTime(waterings[0]?.watered_at ?? null)}
          </p>
          <p className="mt-3 text-xs font-semibold uppercase text-muted-foreground">Previsão</p>
          <p className="font-display text-xl font-bold">{formatDateTime(nextWatering)}</p>
          <p className="text-xs text-muted-foreground">{relativeFromNow(nextWatering)}</p>
        </Card>
      </div>

      {/* Configurações */}
      <div className="mt-6 grid gap-4 lg:grid-cols-2">
        <section className="card-soft p-6">
          <h3 className="text-lg font-bold">Identidade</h3>
          <p className="text-sm text-muted-foreground">Dê um nome carinhoso à sua planta.</p>
          <form
            className="mt-4 flex flex-wrap gap-2"
            onSubmit={(event) => {
              event.preventDefault();
              const name = nameDraft.trim();
              if (name) void savePlant({ name }, "Nome atualizado!");
            }}
          >
            <Input
              value={nameDraft}
              onChange={(event) => setNameDraft(event.target.value)}
              placeholder="Ex.: Verdinha"
              className="min-w-0 flex-1 rounded-full"
              maxLength={40}
            />
            <Button type="submit" variant="secondary" className="rounded-full">
              Salvar
            </Button>
          </form>
        </section>

        <section className="card-soft p-6">
          <h3 className="text-lg font-bold">Modo de rega</h3>
          <p className="text-sm text-muted-foreground">
            Escolha como o vasinho deve ser regado. O modo ativo aparece no topo.
          </p>
          <div className="mt-4 grid gap-2">
            {(["manual", "scheduled", "auto"] as WateringMode[]).map((mode) => (
              <button
                key={mode}
                onClick={() => void savePlant({ mode }, `Modo ${MODE_LABEL[mode]} ativado`)}
                className={`rounded-2xl border px-4 py-3 text-left text-sm font-semibold transition-colors ${
                  plant?.mode === mode
                    ? "border-primary bg-secondary text-secondary-foreground"
                    : "hover:bg-muted"
                }`}
              >
                {MODE_LABEL[mode]}
              </button>
            ))}
          </div>
        </section>

        <section className="card-soft p-6">
          <h3 className="text-lg font-bold">Limite de umidade</h3>
          <p className="text-sm text-muted-foreground">
            No modo automático, a rega dispara abaixo de {thresholdDraft}%.
          </p>
          <Slider
            value={[thresholdDraft]}
            min={10}
            max={80}
            step={1}
            onValueChange={(value) => setThresholdDraft(value[0] ?? 35)}
            onValueCommit={(value) =>
              void savePlant({ moisture_threshold: value[0] ?? 35 }, "Limite salvo!")
            }
            className="mt-6"
          />
          <div className="mt-2 flex justify-between text-xs text-muted-foreground">
            <span>10%</span>
            <span>80%</span>
          </div>
        </section>

        <section className="card-soft p-6">
          <h3 className="text-lg font-bold">Rega programada</h3>
          <p className="text-sm text-muted-foreground">Horários e dias da semana.</p>
          <div className="mt-4 flex flex-wrap gap-2">
            {(plant?.schedule_times ?? []).map((time) => (
              <span
                key={time}
                className="inline-flex items-center gap-2 rounded-full bg-secondary px-3 py-1 text-sm font-semibold text-secondary-foreground"
              >
                {time}
                <button
                  aria-label={`Remover horário ${time}`}
                  onClick={() =>
                    void savePlant(
                      {
                        schedule_times: (plant?.schedule_times ?? []).filter((t) => t !== time),
                      },
                      "Horário removido",
                    )
                  }
                  className="text-muted-foreground hover:text-destructive"
                >
                  ×
                </button>
              </span>
            ))}
          </div>
          <form
            className="mt-4 flex flex-wrap gap-2"
            onSubmit={(event) => {
              event.preventDefault();
              const times = Array.from(
                new Set([...(plant?.schedule_times ?? []), timeDraft]),
              ).sort();
              void savePlant({ schedule_times: times }, "Horário adicionado");
            }}
          >
            <Input
              type="time"
              value={timeDraft}
              onChange={(event) => setTimeDraft(event.target.value)}
              className="w-36 rounded-full"
            />
            <Button type="submit" variant="secondary" className="rounded-full">
              Adicionar
            </Button>
          </form>
          <div className="mt-4 flex flex-wrap gap-2">
            {WEEK_DAYS.map((label, index) => {
              const active = (plant?.schedule_days ?? []).includes(index);
              return (
                <button
                  key={label}
                  onClick={() => {
                    const days = active
                      ? (plant?.schedule_days ?? []).filter((d) => d !== index)
                      : [...(plant?.schedule_days ?? []), index].sort();
                    void savePlant({ schedule_days: days }, "Dias atualizados");
                  }}
                  className={`size-10 rounded-full border text-xs font-bold transition-colors ${
                    active ? "border-primary bg-primary text-primary-foreground" : "hover:bg-muted"
                  }`}
                >
                  {label}
                </button>
              );
            })}
          </div>
          <div className="mt-5 flex items-center justify-between gap-4 rounded-2xl bg-muted/60 px-4 py-3">
            <div className="min-w-0">
              <p className="text-sm font-semibold">Modo automático por umidade</p>
              <p className="text-xs text-muted-foreground">Rega quando o solo secar demais.</p>
            </div>
            <Switch
              checked={plant?.mode === "auto"}
              onCheckedChange={(checked) =>
                void savePlant(
                  { mode: checked ? "auto" : "scheduled" },
                  checked ? "Automático ativado" : "Modo programado ativado",
                )
              }
            />
          </div>
        </section>
      </div>

      <section className="card-soft mt-6 p-6">
        <h3 className="text-lg font-bold">Histórico de regas</h3>
        <ul className="mt-4 divide-y">
          {waterings.length === 0 && (
            <li className="py-3 text-sm text-muted-foreground">Nenhuma rega registrada ainda.</li>
          )}
          {waterings.map((watering) => (
            <li key={watering.id} className="flex items-center justify-between gap-3 py-3 text-sm">
              <span className="min-w-0 truncate font-semibold">
                {MODE_LABEL[(watering.source as WateringMode) ?? "manual"] ?? watering.source}
              </span>
              <span className="shrink-0 text-muted-foreground">
                {formatDateTime(watering.watered_at)}
              </span>
            </li>
          ))}
        </ul>
      </section>

      <footer className="mt-8 text-center text-xs text-muted-foreground">
        Sensor ESP32 envia leituras em <code>/api/public/esp32/telemetry</code>
      </footer>
    </main>
  );
}
