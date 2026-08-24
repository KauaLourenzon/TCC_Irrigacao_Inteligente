import { createFileRoute, Link } from "@tanstack/react-router";
import { useQuery, useQueryClient } from "@tanstack/react-query";
import { useEffect, useRef, useState } from "react";
import { ArrowLeft, Send, Sprout } from "lucide-react";
import { toast } from "sonner";

import { fetchChatMessages, fetchPlant } from "@/lib/plant-data";
import { askPlantAssistant } from "@/lib/plant-assistant";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";

export const Route = createFileRoute("/_authed/plantas/$plantId/assistente")({
  component: PlantAssistant,
});

function PlantAssistant() {
  const { plantId } = Route.useParams();
  const queryClient = useQueryClient();

  const plantQuery = useQuery({ queryKey: ["plant", plantId], queryFn: () => fetchPlant(plantId) });
  const messagesQuery = useQuery({
    queryKey: ["plant-chat", plantId],
    queryFn: () => fetchChatMessages(plantId),
  });

  const plant = plantQuery.data;
  const messages = messagesQuery.data ?? [];

  const [draft, setDraft] = useState("");
  const [sending, setSending] = useState(false);
  const bottomRef = useRef<HTMLDivElement>(null);

  useEffect(() => {
    bottomRef.current?.scrollIntoView({ behavior: "smooth" });
  }, [messages.length, sending]);

  async function handleSend(event: React.FormEvent) {
    event.preventDefault();
    const message = draft.trim();
    if (!message || sending) return;

    setDraft("");
    setSending(true);
    // Otimista: mostra a mensagem do usuário na hora, sem esperar o servidor.
    queryClient.setQueryData(["plant-chat", plantId], (prev: typeof messages = []) => [
      ...prev,
      {
        id: `local-${Date.now()}`,
        plant_id: plantId,
        role: "user" as const,
        content: message,
        created_at: new Date().toISOString(),
      },
    ]);

    try {
      await askPlantAssistant({ data: { plantId, message } });
      await queryClient.invalidateQueries({ queryKey: ["plant-chat", plantId] });
    } catch (err) {
      toast.error(err instanceof Error ? err.message : "Não consegui responder agora.");
      await queryClient.invalidateQueries({ queryKey: ["plant-chat", plantId] });
    } finally {
      setSending(false);
    }
  }

  return (
    <main className="mx-auto flex h-screen w-full max-w-2xl flex-col px-4 pb-4 pt-6 sm:px-6">
      <header className="flex items-center gap-3">
        <Link
          to="/plantas/$plantId"
          params={{ plantId }}
          className="grid size-11 shrink-0 place-items-center rounded-2xl bg-secondary text-primary"
          aria-label="Voltar para o painel da planta"
        >
          <ArrowLeft className="size-5" />
        </Link>
        <div className="min-w-0">
          <p className="text-xs font-semibold uppercase tracking-wide text-muted-foreground">
            Assistente
          </p>
          <h1 className="truncate text-2xl font-bold">{plant?.name ?? "Carregando…"}</h1>
        </div>
      </header>

      <div className="mt-4 flex-1 space-y-3 overflow-y-auto rounded-3xl border bg-card/50 p-4">
        {messages.length === 0 && !messagesQuery.isLoading && (
          <div className="flex h-full flex-col items-center justify-center gap-2 text-center text-muted-foreground">
            <Sprout className="size-8" />
            <p className="text-sm">
              Oi! Pergunte como {plant?.name ?? "eu"} está, ou peça dicas de cuidado. 🌱
            </p>
          </div>
        )}

        {messages.map((message) => (
          <div
            key={message.id}
            className={`flex ${message.role === "user" ? "justify-end" : "justify-start"}`}
          >
            <div
              className={`max-w-[85%] rounded-2xl px-4 py-2 text-sm ${
                message.role === "user"
                  ? "bg-primary text-primary-foreground"
                  : "bg-secondary text-secondary-foreground"
              }`}
            >
              {message.content}
            </div>
          </div>
        ))}

        {sending && (
          <div className="flex justify-start">
            <div className="max-w-[85%] rounded-2xl bg-secondary px-4 py-2 text-sm text-secondary-foreground">
              <span className="inline-flex items-center gap-1">
                <span className="animate-pulse">●</span>
                <span className="animate-pulse [animation-delay:150ms]">●</span>
                <span className="animate-pulse [animation-delay:300ms]">●</span>
              </span>
            </div>
          </div>
        )}
        <div ref={bottomRef} />
      </div>

      <form onSubmit={handleSend} className="mt-3 flex gap-2">
        <Input
          value={draft}
          onChange={(event) => setDraft(event.target.value)}
          placeholder={`Fale com ${plant?.name ?? "a planta"}…`}
          className="min-w-0 flex-1 rounded-full"
          disabled={sending}
        />
        <Button type="submit" className="rounded-full" disabled={sending || !draft.trim()}>
          <Send className="size-4" />
        </Button>
      </form>

      <p className="mt-2 text-center text-[11px] text-muted-foreground">
        Assistente local via Ollama — funciona sem internet.
      </p>
    </main>
  );
}
