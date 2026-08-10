import type { MoodKey } from "@/lib/plant-mood";

type Props = {
  mood: MoodKey;
  className?: string;
};

function Eyes({ mood }: { mood: MoodKey }) {
  if (mood === "soggy") {
    // olhinhos apertados de desconforto
    return (
      <g stroke="currentColor" strokeWidth="4" strokeLinecap="round" fill="none">
        <path d="M62 96 q10 -8 20 0" />
        <path d="M118 96 q10 -8 20 0" />
      </g>
    );
  }
  if (mood === "cold") {
    return (
      <g stroke="currentColor" strokeWidth="4" strokeLinecap="round" fill="none">
        <path d="M62 92 q10 10 20 0" />
        <path d="M118 92 q10 10 20 0" />
      </g>
    );
  }
  if (mood === "unknown") {
    return (
      <g stroke="currentColor" strokeWidth="4" strokeLinecap="round">
        <path d="M64 96 h16" />
        <path d="M120 96 h16" />
      </g>
    );
  }
  return (
    <g fill="currentColor">
      <circle cx="72" cy="94" r="7" />
      <circle cx="128" cy="94" r="7" />
      <circle cx="74.5" cy="91.5" r="2.4" className="text-card" fill="var(--color-card)" />
      <circle cx="130.5" cy="91.5" r="2.4" className="text-card" fill="var(--color-card)" />
    </g>
  );
}

function Mouth({ mood }: { mood: MoodKey }) {
  const common = {
    stroke: "currentColor",
    strokeWidth: 4,
    strokeLinecap: "round" as const,
    fill: "none",
  };
  switch (mood) {
    case "happy":
      return <path d="M86 112 q14 14 28 0" {...common} />;
    case "thirsty":
      return <path d="M88 118 q12 -12 24 0" {...common} />;
    case "soggy":
      return <path d="M86 118 q14 -10 28 0" {...common} />;
    case "hot":
      return <path d="M88 110 q12 16 24 0 q-12 4 -24 0" {...common} fill="currentColor" />;
    case "cold":
      return <path d="M86 114 h28 M92 110 v8 M100 110 v8 M108 110 v8" {...common} />;
    default:
      return <path d="M88 114 h24" {...common} />;
  }
}

export function PotMascot({ mood, className }: Props) {
  const leafTone =
    mood === "thirsty" ? "var(--color-sun)" : mood === "soggy" ? "var(--color-water)" : "var(--color-leaf)";

  return (
    <svg
      viewBox="0 0 200 230"
      role="img"
      aria-label={`Mascote do vasinho com expressão: ${mood}`}
      className={className}
    >
      {/* folhas */}
      <g className="animate-sway" style={{ color: leafTone }}>
        <path
          d="M100 74 C100 46 84 30 62 24 C58 48 72 68 100 74 Z"
          fill={leafTone}
          opacity={mood === "thirsty" ? 0.75 : 1}
        />
        <path
          d="M100 74 C100 42 118 26 142 22 C146 48 130 68 100 74 Z"
          fill={leafTone}
        />
        <path d="M100 78 V56" stroke={leafTone} strokeWidth="5" strokeLinecap="round" />
      </g>

      {/* vaso */}
      <path
        d="M46 86 H154 L140 202 A14 14 0 0 1 126 214 H74 A14 14 0 0 1 60 202 Z"
        fill="var(--color-terracotta)"
      />
      <rect x="38" y="74" width="124" height="26" rx="13" fill="var(--color-terracotta)" />
      <rect
        x="38"
        y="74"
        width="124"
        height="26"
        rx="13"
        fill="var(--color-foreground)"
        opacity="0.07"
      />

      {/* rostinho */}
      <g style={{ color: "var(--color-terracotta-foreground)" }}>
        <Eyes mood={mood} />
        <Mouth mood={mood} />
        <circle cx="56" cy="112" r="9" fill="currentColor" opacity="0.12" />
        <circle cx="144" cy="112" r="9" fill="currentColor" opacity="0.12" />
      </g>

      {/* detalhes por humor */}
      {mood === "hot" && (
        <g fill="var(--color-water)">
          <path d="M160 92 q7 12 0 16 q-7 -4 0 -16 Z" />
          <path d="M40 104 q6 10 0 14 q-6 -4 0 -14 Z" opacity="0.8" />
        </g>
      )}
      {mood === "thirsty" && (
        <path d="M148 118 q6 12 0 16 q-6 -4 0 -16 Z" fill="var(--color-water)" opacity="0.9" />
      )}
      {mood === "soggy" && (
        <g fill="var(--color-water)" opacity="0.9">
          <path d="M74 214 q5 10 0 13 q-5 -3 0 -13 Z" />
          <path d="M100 216 q5 10 0 13 q-5 -3 0 -13 Z" />
          <path d="M126 214 q5 10 0 13 q-5 -3 0 -13 Z" />
        </g>
      )}
      {mood === "cold" && (
        <g stroke="var(--color-water)" strokeWidth="3" strokeLinecap="round">
          <path d="M166 60 v14 M159 67 h14 M161 62 l10 10 M171 62 l-10 10" />
        </g>
      )}
    </svg>
  );
}
