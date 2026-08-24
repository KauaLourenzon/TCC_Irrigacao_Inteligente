import { createFileRoute, Outlet, useNavigate } from "@tanstack/react-router";
import { useEffect, useState } from "react";
import type { Session } from "@supabase/supabase-js";

import { supabase } from "@/integrations/supabase/client";

export const Route = createFileRoute("/_authed")({
  component: AuthedLayout,
});

/**
 * Gate de autenticação no cliente: enquanto verifica a sessão mostra um
 * loading simples; sem sessão, manda pra /login; com sessão, libera as
 * rotas filhas (lista de plantas, dashboard de cada planta, assistente).
 */
function AuthedLayout() {
  const navigate = useNavigate();
  const [session, setSession] = useState<Session | null | undefined>(undefined);

  useEffect(() => {
    let active = true;

    supabase.auth.getSession().then(({ data }) => {
      if (!active) return;
      setSession(data.session);
      if (!data.session) void navigate({ to: "/login" });
    });

    const { data: subscription } = supabase.auth.onAuthStateChange((_event, nextSession) => {
      setSession(nextSession);
      if (!nextSession) void navigate({ to: "/login" });
    });

    return () => {
      active = false;
      subscription.subscription.unsubscribe();
    };
  }, [navigate]);

  if (session === undefined) {
    return (
      <div className="grid min-h-screen place-items-center text-sm text-muted-foreground">
        Carregando…
      </div>
    );
  }

  if (!session) {
    // navigate("/login") já foi disparado; evita piscar conteúdo protegido.
    return null;
  }

  return <Outlet />;
}
