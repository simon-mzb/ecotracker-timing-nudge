"use client";

import { useLocale, useTranslations } from "next-intl";
import { useRouter } from "next/navigation";
import { useTransition } from "react";
import { setLanguageCookie } from "@/lib/language-cookie";

const LOCALES = ["en", "de"] as const;

export default function LanguageSwitcher() {
  const locale = useLocale();
  const t = useTranslations("common");
  const router = useRouter();
  const [isPending, startTransition] = useTransition();

  function setLocale(next: string) {
    if (next === locale) return;
    setLanguageCookie(next);
    startTransition(() => {
      router.refresh();
    });
  }

  return (
    <div
      className="inline-flex items-center gap-1 rounded-full bg-white/80 p-1 text-xs font-medium shadow-sm ring-1 ring-neutral-200"
      aria-label={t("language")}
    >
      {LOCALES.map((l) => (
        <button
          key={l}
          type="button"
          disabled={isPending}
          onClick={() => setLocale(l)}
          className={`rounded-full px-2.5 py-1 transition-colors ${
            locale === l
              ? "bg-emerald-600 text-white"
              : "text-neutral-500 hover:text-neutral-800"
          }`}
        >
          {l.toUpperCase()}
        </button>
      ))}
    </div>
  );
}
