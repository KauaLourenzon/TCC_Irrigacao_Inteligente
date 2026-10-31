import { useCallback, useEffect, useState } from "react";

export type ThemeChoice = "auto" | "light" | "dark";

const STORAGE_KEY = "plant-theme";

function nightNow() {
  const hour = new Date().getHours();
  return hour >= 18 || hour < 6;
}

/** Tema automático pelo horário (claro de dia, escuro à noite) com override manual. */
export function useTheme() {
  const [choice, setChoice] = useState<ThemeChoice>("auto");
  const [isDark, setIsDark] = useState(false);

  useEffect(() => {
    const stored = window.localStorage.getItem(STORAGE_KEY) as ThemeChoice | null;
    if (stored === "light" || stored === "dark" || stored === "auto") setChoice(stored);
  }, []);

  useEffect(() => {
    const apply = () => {
      const dark = choice === "auto" ? nightNow() : choice === "dark";
      setIsDark(dark);
      document.documentElement.classList.toggle("dark", dark);
    };
    apply();
    if (choice !== "auto") return;
    const timer = window.setInterval(apply, 60_000);
    return () => window.clearInterval(timer);
  }, [choice]);

  const update = useCallback((next: ThemeChoice) => {
    setChoice(next);
    window.localStorage.setItem(STORAGE_KEY, next);
  }, []);

  return { choice, isDark, setChoice: update };
}
