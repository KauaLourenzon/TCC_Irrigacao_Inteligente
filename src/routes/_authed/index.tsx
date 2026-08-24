import { createFileRoute, Link, useNavigate } from "@tanstack/react-router";
import { useQuery, useQueryClient } from "@tanstack/react-query";
import { useState } from "react";
import { LogOut, MessageCircle, Plus, Sprout } from "lucide-react";
import { toast } from "sonner";
import { fetchSpeciesProfiles } from "@/lib/species";
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select";
import { supabase } from "@/integrations/supabase/client";
import { createPlant, fetchPlants, findPlantByName } from "@/lib/plant-data";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";

export const Route = createFileRoute("/_authed/")({
  head: () => ({
    meta: [{ title: "Minhas plantas — Plantinha" }],
  }),
  component: PlantsList,
});

function PlantsList() {
  const queryClient = useQueryClient();
  const navigate = useNavigate();
  const plantsQuery = useQuery({ queryKey: ["plants"], queryFn: fetchPlants });
  const plants = plantsQuery.data ?? [];

  const [newName, setNewName] = useState("");
  const [creating, setCreating] = useState(false);
  const [searchName, setSearchName] = useState("");

  // dentro do componente:
  const speciesQuery = useQuery({ queryKey: ["species"], queryFn: fetchSpeciesProfiles });
  const [newSpeciesId, setNewSpeciesId] = useState("");

  async function handleCreate(event: React.FormEvent) {
    event.preventDefault();
    const name = newName.trim();
    if (!name) return;
    if (!newSpeciesId) {
      toast.error("Escolha a espécie da planta.");
      return;
    }
    setCreating(true);
    try {
      const plant = await createPlant({ name, speciesId: newSpeciesId });
      await queryClient.invalidateQueries({ queryKey: ["plants"] });
      setNewName("");
      setNewSpeciesId("");
      toast.success(`${plant.name} cadastrada! Agora é só conectar o sensor USB dela.`);
      await navigate({ to: "/plantas/$plantId", params: { plantId: plant.id } });
    } catch (err) {
      toast.error(err instanceof Error ? err.message : "Não foi possível cadastrar a planta.");
    } finally {
      setCreating(false);
    }
  }



  function handleSearch(event: React.FormEvent) {
    event.preventDefault();
    const found = findPlantByName(plants, searchName);
    if (found) {
      void navigate({
        to: "/plantas/$plantId/assistente",
        params: { plantId: found.id },
      });
      return;
    }
    toast.error("Não achei nenhuma planta sua com esse nome.");
  }

  async function handleSignOut() {
    await supabase.auth.signOut();
  }

  return (
    <main className="mx-auto w-full max-w-3xl px-4 pb-16 pt-6 sm:px-6 lg:px-8">
      <header className="flex items-center justify-between gap-4">
        <div className="flex items-center gap-3">
          <span className="grid size-11 shrink-0 place-items-center rounded-2xl bg-secondary text-primary">
            <Sprout className="size-6" />
          </span>
          <h1 className="text-2xl font-bold sm:text-3xl">Minhas plantas</h1>
        </div>
        <Button variant="ghost" size="icon" onClick={handleSignOut} aria-label="Sair">
          <LogOut className="size-4" />
        </Button>
      </header>

      {/* Falar com uma planta pelo nome */}
      <form
        onSubmit={handleSearch}
        className="card-soft mt-6 flex flex-wrap items-center gap-2 p-4"
      >
        <MessageCircle className="size-4 shrink-0 text-muted-foreground" />
        <Input
          value={searchName}
          onChange={(event) => setSearchName(event.target.value)}
          placeholder="Digite o nome de uma planta pra falar com ela…"
          className="min-w-0 flex-1 rounded-full"
        />
        <Button type="submit" variant="secondary" className="rounded-full">
          Conversar
        </Button>
      </form>

      {/* Lista */}
      <div className="mt-6 grid gap-3 sm:grid-cols-2">
        {plants.map((plant) => (
          <Link
            key={plant.id}
            to="/plantas/$plantId"
            params={{ plantId: plant.id }}
            className="card-soft flex items-center justify-between gap-3 p-5 transition-transform hover:-translate-y-0.5"
          >
            <div className="min-w-0">
              <p className="truncate text-lg font-bold">{plant.name}</p>
              <p className="truncate text-sm text-muted-foreground">
                {plant.species || "Espécie não informada"}
              </p>
            </div>
            <span className="shrink-0 rounded-full bg-secondary px-3 py-1 text-xs font-semibold text-secondary-foreground">
              {plant.mode}
            </span>
          </Link>
        ))}

        {plants.length === 0 && !plantsQuery.isLoading && (
          <p className="text-sm text-muted-foreground">
            Você ainda não tem nenhuma planta cadastrada. Cadastre a primeira abaixo!
          </p>
        )}
      </div>

      {/* Nova planta */}
      <section className="card-soft mt-6 p-6">
        <h2 className="flex items-center gap-2 text-lg font-bold">
          <Plus className="size-4" /> Nova planta
        </h2>
        <p className="text-sm text-muted-foreground">
          Cada planta cadastrada aqui vira um sensor ESP32 e um assistente próprios.
        </p>
        <form className="mt-4 flex flex-wrap gap-2" onSubmit={handleCreate}>
          <Input
            value={newName}
            onChange={(event) => setNewName(event.target.value)}
            placeholder="Nome (ex.: Verdinha)"
            className="min-w-[160px] flex-1 rounded-full"
            maxLength={40}
            required
          />
          <Select value={newSpeciesId} onValueChange={setNewSpeciesId}>
            <SelectTrigger className="min-w-[160px] flex-1 rounded-full">
              <SelectValue placeholder="Espécie (obrigatório)" />
            </SelectTrigger>
            <SelectContent>
              {(speciesQuery.data ?? []).map((s) => (
                <SelectItem key={s.id} value={s.id}>
                  {s.common_name}
                </SelectItem>
              ))}
            </SelectContent>
          </Select>
          <Button type="submit" className="rounded-full" disabled={creating}>
            {creating ? "Criando…" : "Cadastrar"}
          </Button>
        </form>
      </section>
    </main>
  );
}
