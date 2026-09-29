"use client";

import { useState } from "react";
import Link from "next/link";
import { useRouter } from "next/navigation";
import { useTranslations } from "next-intl";

export type AdminHouseholdRow = {
  id: string;
  phaseOverride: "1" | "2" | null;
  phase: 1 | 2;
  firstLoginAt: string | null;
  consentedAt: string | null;
  ineligibleAt: string | null;
  isTest: boolean;
};

export default function AdminTable({ initialRows }: { initialRows: AdminHouseholdRow[] }) {
  const t = useTranslations("admin");
  const router = useRouter();
  const [rows, setRows] = useState(initialRows);
  const [savingId, setSavingId] = useState<string | null>(null);
  const [savedId, setSavedId] = useState<string | null>(null);

  function updateRow(id: string, patch: Partial<AdminHouseholdRow>) {
    setRows((prev) => prev.map((r) => (r.id === id ? { ...r, ...patch } : r)));
  }

  async function saveRow(row: AdminHouseholdRow) {
    setSavingId(row.id);
    const res = await fetch(`/api/admin/households/${row.id}`, {
      method: "PATCH",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        phaseOverride: row.phaseOverride,
      }),
    });
    setSavingId(null);
    if (res.ok) {
      setSavedId(row.id);
      setTimeout(() => setSavedId((cur) => (cur === row.id ? null : cur)), 1500);
    }
  }

  async function handleLogout() {
    await fetch("/api/admin/logout", { method: "POST" });
    router.push("/admin/login");
    router.refresh();
  }

  return (
    <div className="flex flex-col gap-6">
      <div className="flex flex-wrap gap-2">
        <Link
          href="/api/admin/export/usage_logs"
          className="rounded-lg bg-emerald-600 px-3 py-2 text-sm font-medium text-white hover:bg-emerald-700"
        >
          {t("exportUsageLogs")}
        </Link>
        <Link
          href="/api/admin/export/nudge_responses"
          className="rounded-lg bg-emerald-600 px-3 py-2 text-sm font-medium text-white hover:bg-emerald-700"
        >
          {t("exportNudgeResponses")}
        </Link>
        <Link
          href="/api/admin/export/household_profiles"
          className="rounded-lg bg-emerald-600 px-3 py-2 text-sm font-medium text-white hover:bg-emerald-700"
        >
          {t("exportProfiles")}
        </Link>
        <button
          type="button"
          onClick={handleLogout}
          className="ml-auto rounded-lg bg-neutral-100 px-3 py-2 text-sm font-medium text-neutral-600 hover:bg-neutral-200"
        >
          {t("logout")}
        </button>
      </div>

      <div className="overflow-x-auto rounded-xl ring-1 ring-neutral-200">
        <table className="min-w-full divide-y divide-neutral-200 text-sm">
          <thead className="bg-neutral-50">
            <tr>
              <th className="px-3 py-2 text-left font-semibold text-neutral-600">{t("id")}</th>
              <th className="px-3 py-2 text-left font-semibold text-neutral-600">{t("phase")}</th>
              <th className="px-3 py-2 text-left font-semibold text-neutral-600">{t("phaseOverride")}</th>
              <th className="px-3 py-2 text-left font-semibold text-neutral-600">{t("consented")}</th>
              <th className="px-3 py-2 text-left font-semibold text-neutral-600">{t("firstLogin")}</th>
              <th className="px-3 py-2 text-left font-semibold text-neutral-600" />
            </tr>
          </thead>
          <tbody className="divide-y divide-neutral-100">
            {rows.map((row) => (
              <tr key={row.id}>
                <td className="px-3 py-2 font-medium text-neutral-800">
                  {row.id}
                  {row.isTest && (
                    <span className="ml-1.5 rounded-full bg-fuchsia-100 px-1.5 py-0.5 text-[10px] font-semibold text-fuchsia-700">
                      TEST
                    </span>
                  )}
                  {row.ineligibleAt && (
                    <span className="ml-1.5 rounded-full bg-neutral-200 px-1.5 py-0.5 text-[10px] font-semibold text-neutral-600">
                      INELIGIBLE
                    </span>
                  )}
                </td>
                <td className="px-3 py-2">{row.phase}</td>
                <td className="px-3 py-2">
                  <select
                    value={row.phaseOverride ?? ""}
                    onChange={(e) =>
                      updateRow(row.id, {
                        phaseOverride: (e.target.value || null) as "1" | "2" | null,
                      })
                    }
                    className="rounded-lg border border-neutral-300 px-2 py-1"
                  >
                    <option value="">{t("none")}</option>
                    <option value="1">1</option>
                    <option value="2">2</option>
                  </select>
                </td>
                <td className="px-3 py-2">{row.consentedAt ? "✅" : "—"}</td>
                <td className="px-3 py-2 text-neutral-600">
                  {row.firstLoginAt ? new Date(row.firstLoginAt).toLocaleDateString() : "—"}
                </td>
                <td className="px-3 py-2">
                  <button
                    type="button"
                    onClick={() => saveRow(row)}
                    disabled={savingId === row.id}
                    className="rounded-lg bg-neutral-800 px-3 py-1.5 text-xs font-semibold text-white hover:bg-neutral-700 disabled:opacity-60"
                  >
                    {savedId === row.id ? t("saved") : t("save")}
                  </button>
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
    </div>
  );
}
