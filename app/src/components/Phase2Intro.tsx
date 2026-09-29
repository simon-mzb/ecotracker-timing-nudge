"use client";

import { useState } from "react";
import { useRouter } from "next/navigation";
import { useTranslations } from "next-intl";
import LanguageSwitcher from "./LanguageSwitcher";

export default function Phase2Intro() {
  const t = useTranslations("phase2Intro");
  const router = useRouter();
  const [submitting, setSubmitting] = useState(false);

  async function handleContinue() {
    setSubmitting(true);
    await fetch("/api/phase2-intro", { method: "POST" });
    router.refresh();
  }

  return (
    <main className="mx-auto flex min-h-full w-full max-w-sm flex-1 flex-col gap-6 px-6 py-10">
      <div className="self-end">
        <LanguageSwitcher />
      </div>
      <div className="flex flex-1 flex-col justify-center gap-4">
        <p className="text-3xl">🌤️</p>
        <h1 className="text-xl font-bold text-neutral-900">{t("title")}</h1>
        <p className="text-sm text-neutral-700">{t("body1")}</p>
        <p className="text-sm text-neutral-700">{t("body2")}</p>
        <button
          type="button"
          onClick={handleContinue}
          disabled={submitting}
          className="mt-4 rounded-xl bg-emerald-600 px-4 py-3 text-base font-semibold text-white shadow-sm transition-colors hover:bg-emerald-700 disabled:opacity-60"
        >
          {t("continue")}
        </button>
      </div>
    </main>
  );
}
