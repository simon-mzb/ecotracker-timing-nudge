"use client";

import { useTranslations } from "next-intl";

export default function GreenScoreTracker({
  score,
  lastDelta,
}: {
  score: number;
  lastDelta: number | null;
}) {
  const t = useTranslations("greenScore");

  return (
    <div className="flex items-center justify-between rounded-2xl bg-white px-4 py-3 ring-1 ring-neutral-200">
      <div className="flex items-center gap-2">
        <span className="text-lg">🌿</span>
        <div>
          <p className="text-xs font-medium uppercase tracking-wide text-neutral-500">
            {t("title")}
          </p>
          <p className="text-lg font-bold text-neutral-800">{score}</p>
        </div>
      </div>
      {lastDelta !== null && (
        <span
          className={`rounded-full px-2.5 py-1 text-sm font-semibold ${
            lastDelta > 0
              ? "bg-emerald-100 text-emerald-700"
              : "bg-red-100 text-red-700"
          }`}
        >
          {lastDelta > 0 ? `+${lastDelta}` : lastDelta}
        </span>
      )}
    </div>
  );
}
