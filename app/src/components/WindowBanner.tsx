"use client";

import type { Window } from "@/lib/schedule";

const WINDOW_STYLES: Record<Window, string> = {
  great: "bg-emerald-50 text-emerald-800 ring-emerald-200",
  ok: "bg-amber-50 text-amber-800 ring-amber-200",
  bad: "bg-neutral-100 text-neutral-600 ring-neutral-200",
};

const WINDOW_ICONS: Record<Window, string> = {
  great: "☀️",
  ok: "🙂",
  bad: "🔌",
};

export default function WindowBanner({ window, message }: { window: Window; message: string }) {
  return (
    <div className={`rounded-2xl px-4 py-3 text-sm font-medium ring-1 ${WINDOW_STYLES[window]}`}>
      <div className="flex items-start gap-2">
        <span className="text-lg">{WINDOW_ICONS[window]}</span>
        <span>{message}</span>
      </div>
    </div>
  );
}
