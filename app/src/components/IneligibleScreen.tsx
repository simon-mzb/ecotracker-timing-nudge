"use client";

import { useTranslations } from "next-intl";

export default function IneligibleScreen() {
  const t = useTranslations("onboarding.ineligible");

  return (
    <div className="flex flex-col gap-4">
      <p className="text-3xl">🙏</p>
      <h1 className="text-xl font-bold text-neutral-900">{t("title")}</h1>
      <p className="text-sm text-neutral-700">{t("body")}</p>
    </div>
  );
}
