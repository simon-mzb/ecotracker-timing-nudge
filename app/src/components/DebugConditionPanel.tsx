"use client";

import { useState } from "react";
import { useRouter } from "next/navigation";
import type { Window } from "@/lib/schedule";

const OPTIONS: { key: Window; label: string }[] = [
  { key: "great", label: "☀️ Great" },
  { key: "ok", label: "🙂 Ok" },
  { key: "bad", label: "🔌 Bad" },
];

export default function DebugConditionPanel({
  currentDay,
  onSelect,
  onReset,
}: {
  currentDay: number;
  onSelect: (window: Window) => void;
  onReset: () => void;
}) {
  const router = useRouter();
  const [day, setDay] = useState(currentDay);
  const [applying, setApplying] = useState(false);

  async function applyDay(value: number | null) {
    setApplying(true);
    await fetch("/api/debug/set-day", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ day: value }),
    });
    setApplying(false);
    router.refresh();
  }

  return (
    <div className="rounded-2xl border-2 border-dashed border-fuchsia-300 bg-fuchsia-50 p-3">
      <p className="mb-2 text-xs font-semibold uppercase tracking-wide text-fuchsia-700">
        Debug: study day (day 8+ = phase 2)
      </p>
      <div className="mb-3 flex items-center gap-2">
        <input
          type="number"
          min={1}
          max={30}
          value={day}
          onChange={(e) => setDay(Number(e.target.value))}
          className="w-20 rounded-lg border border-fuchsia-300 px-2 py-1.5 text-sm"
        />
        <button
          type="button"
          onClick={() => applyDay(day)}
          disabled={applying}
          className="rounded-lg bg-fuchsia-700 px-2.5 py-1.5 text-xs font-medium text-white hover:bg-fuchsia-800 disabled:opacity-60"
        >
          Set day
        </button>
        <button
          type="button"
          onClick={() => applyDay(null)}
          disabled={applying}
          className="rounded-lg bg-white px-2.5 py-1.5 text-xs font-medium text-fuchsia-800 ring-1 ring-fuchsia-300 hover:bg-fuchsia-100"
        >
          Real time
        </button>
      </div>

      <p className="mb-2 text-xs font-semibold uppercase tracking-wide text-fuchsia-700">
        Debug: force window
      </p>
      <div className="flex flex-wrap gap-2">
        {OPTIONS.map((opt) => (
          <button
            key={opt.key}
            type="button"
            onClick={() => onSelect(opt.key)}
            className="rounded-lg bg-white px-2.5 py-1.5 text-xs font-medium text-fuchsia-800 ring-1 ring-fuchsia-300 hover:bg-fuchsia-100"
          >
            {opt.label}
          </button>
        ))}
        <button
          type="button"
          onClick={onReset}
          className="rounded-lg bg-fuchsia-700 px-2.5 py-1.5 text-xs font-medium text-white hover:bg-fuchsia-800"
        >
          ↻ Real time
        </button>
      </div>
    </div>
  );
}
