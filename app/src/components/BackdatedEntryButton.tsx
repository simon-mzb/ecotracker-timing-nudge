"use client";

import { useState } from "react";
import { useTranslations } from "next-intl";
import ConfirmTapButton from "./ConfirmTapButton";
import { toDatetimeLocalValue } from "@/lib/format";
import type { Appliance } from "@/lib/appliances";
import type { Window } from "@/lib/schedule";

export default function BackdatedEntryButton({
  appliance,
  phase,
}: {
  appliance: Appliance;
  phase: 1 | 2;
}) {
  const t = useTranslations("backdated");
  const [open, setOpen] = useState(false);
  const [value, setValue] = useState(() => toDatetimeLocalValue(new Date()));
  const [error, setError] = useState<string | null>(null);
  const [result, setResult] = useState<"logged" | Window | null>(null);

  const now = new Date();
  const maxValue = toDatetimeLocalValue(now);
  const minValue = toDatetimeLocalValue(new Date(now.getTime() - 24 * 60 * 60 * 1000));

  async function handleSubmit() {
    setError(null);
    const chosen = new Date(value);
    if (Number.isNaN(chosen.getTime())) {
      setError(t("errorGeneric"));
      return;
    }

    const res = await fetch("/api/usage/backdated", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        appliance,
        chosenAt: chosen.toISOString(),
        localHour: chosen.getHours(),
      }),
    });

    if (!res.ok) {
      const body = await res.json().catch(() => ({}));
      if (body.error === "time_in_future") setError(t("errorFuture"));
      else if (body.error === "time_too_old") setError(t("errorTooOld"));
      else setError(t("errorGeneric"));
      return;
    }

    const data = await res.json();
    setOpen(false);
    setResult(phase === 2 ? (data.window as Window) : "logged");
  }

  return (
    <div>
      <button
        type="button"
        onClick={() => setOpen(true)}
        aria-label={t("buttonLabel")}
        className="flex h-9 w-9 shrink-0 items-center justify-center rounded-xl bg-neutral-100 text-base text-neutral-600 hover:bg-neutral-200"
      >
        🕐
      </button>

      {open && (
        <div
          className="fixed inset-0 z-50 flex items-end justify-center bg-black/40 p-4 sm:items-center"
          onClick={() => setOpen(false)}
        >
          <div
            className="w-full max-w-sm rounded-2xl bg-white p-5 shadow-lg"
            onClick={(e) => e.stopPropagation()}
          >
            <h2 className="text-base font-bold text-neutral-900">{t("title")}</h2>
            <label htmlFor="backdated-time" className="mt-3 block text-sm font-medium text-neutral-700">
              {t("timeLabel")}
            </label>
            <input
              id="backdated-time"
              type="datetime-local"
              value={value}
              max={maxValue}
              min={minValue}
              onChange={(e) => setValue(e.target.value)}
              className="mt-1 w-full rounded-xl border border-neutral-300 px-3 py-2.5 text-base focus:border-emerald-500 focus:outline-none focus:ring-2 focus:ring-emerald-200"
            />
            {error && <p className="mt-2 text-sm text-red-600">{error}</p>}
            <div className="mt-4 flex gap-2">
              <ConfirmTapButton
                onConfirm={handleSubmit}
                idleLabel={t("submitIdle")}
                confirmLabel={t("submitConfirm")}
                className="flex-1 rounded-xl bg-emerald-600 px-4 py-2.5 text-sm font-semibold text-white transition-colors hover:bg-emerald-700"
              />
              <button
                type="button"
                onClick={() => setOpen(false)}
                className="rounded-xl bg-neutral-100 px-4 py-2.5 text-sm font-semibold text-neutral-600 hover:bg-neutral-200"
              >
                {t("cancel")}
              </button>
            </div>
          </div>
        </div>
      )}

      {result && (
        <p className="mt-1 max-w-[8rem] text-xs text-neutral-500">
          {result === "logged" ? t("loggedConfirmation") : t(`retrospective${capitalize(result)}`)}
        </p>
      )}
    </div>
  );
}

function capitalize(s: string): string {
  return s.charAt(0).toUpperCase() + s.slice(1);
}
