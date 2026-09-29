"use client";

import { useState } from "react";
import { useRouter } from "next/navigation";
import { useTranslations } from "next-intl";

export default function LoginForm() {
  const t = useTranslations("login");
  const router = useRouter();
  const [householdId, setHouseholdId] = useState("");
  const [passcode, setPasscode] = useState("");
  const [error, setError] = useState(false);
  const [submitting, setSubmitting] = useState(false);

  async function handleSubmit(e: React.FormEvent) {
    e.preventDefault();
    setSubmitting(true);
    setError(false);

    const res = await fetch("/api/auth/login", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ householdId, passcode }),
    });

    if (!res.ok) {
      setError(true);
      setSubmitting(false);
      return;
    }

    const data = await res.json();
    router.push(data.needsOnboarding ? "/onboarding" : "/");
    router.refresh();
  }

  return (
    <form onSubmit={handleSubmit} className="flex flex-col gap-4">
      <div className="flex flex-col gap-1">
        <label htmlFor="householdId" className="text-sm font-medium text-neutral-700">
          {t("householdId")}
        </label>
        <input
          id="householdId"
          value={householdId}
          onChange={(e) => setHouseholdId(e.target.value)}
          placeholder={t("householdIdPlaceholder")}
          autoCapitalize="characters"
          autoComplete="username"
          required
          className="rounded-xl border border-neutral-300 px-4 py-3 text-base focus:border-emerald-500 focus:outline-none focus:ring-2 focus:ring-emerald-200"
        />
      </div>
      <div className="flex flex-col gap-1">
        <label htmlFor="passcode" className="text-sm font-medium text-neutral-700">
          {t("passcode")}
        </label>
        <input
          id="passcode"
          type="password"
          value={passcode}
          onChange={(e) => setPasscode(e.target.value)}
          autoComplete="current-password"
          required
          className="rounded-xl border border-neutral-300 px-4 py-3 text-base focus:border-emerald-500 focus:outline-none focus:ring-2 focus:ring-emerald-200"
        />
      </div>
      {error && <p className="text-sm text-red-600">{t("invalid")}</p>}
      <button
        type="submit"
        disabled={submitting}
        className="mt-2 rounded-xl bg-emerald-600 px-4 py-3 text-base font-semibold text-white shadow-sm transition-colors hover:bg-emerald-700 disabled:opacity-60"
      >
        {t("submit")}
      </button>
    </form>
  );
}
