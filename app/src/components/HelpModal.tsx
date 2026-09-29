"use client";

import { useState } from "react";
import { useTranslations } from "next-intl";

export default function HelpModal({ phase }: { phase: 1 | 2 }) {
  const t = useTranslations("help");
  const [open, setOpen] = useState(false);

  return (
    <>
      <button
        type="button"
        onClick={() => setOpen(true)}
        aria-label={t("buttonLabel")}
        className="flex h-8 w-8 shrink-0 items-center justify-center rounded-full bg-white/80 text-sm font-bold text-emerald-700 shadow-sm ring-1 ring-neutral-200 hover:bg-emerald-50"
      >
        ?
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
            <h2 className="text-lg font-bold text-neutral-900">{t("title")}</h2>
            <p className="mt-2 text-sm text-neutral-700">
              {phase === 1 ? t("phase1Body") : t("phase2Body")}
            </p>
            <button
              type="button"
              onClick={() => setOpen(false)}
              className="mt-4 w-full rounded-xl bg-emerald-600 px-4 py-2.5 text-sm font-semibold text-white transition-colors hover:bg-emerald-700"
            >
              {t("close")}
            </button>
          </div>
        </div>
      )}
    </>
  );
}
