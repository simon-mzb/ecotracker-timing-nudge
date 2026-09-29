import { desc } from "drizzle-orm";
import { getTranslations } from "next-intl/server";
import { requireAdmin } from "@/lib/auth";
import { db } from "@/db/client";
import { households, usageLogs, nudgeResponses } from "@/db/schema";
import { getPhase } from "@/lib/phase";
import AdminTable, { type AdminHouseholdRow } from "@/components/AdminTable";
import AdminOverview, {
  type ActivityEvent,
  type OverviewStats,
} from "@/components/AdminOverview";
import AdminResetPanel from "@/components/AdminResetPanel";
import LanguageSwitcher from "@/components/LanguageSwitcher";

type DashboardData = {
  stats: OverviewStats;
  recentActivity: ActivityEvent[];
  initialRows: AdminHouseholdRow[];
};

async function loadDashboardData(): Promise<
  { ok: true; data: DashboardData } | { ok: false; error: string }
> {
  try {
    const [rows, usageLogRows, nudgeResponseRows] = await Promise.all([
      db.select().from(households).orderBy(households.id),
      db.select().from(usageLogs).orderBy(desc(usageLogs.createdAt)).limit(200),
      db.select().from(nudgeResponses).orderBy(desc(nudgeResponses.createdAt)).limit(200),
    ]);

    const realHouseholds = rows.filter((h) => !h.isTest && !h.ineligibleAt);

    const stats: OverviewStats = {
      totalHouseholds: realHouseholds.length,
      consentedHouseholds: realHouseholds.filter((h) => h.consentedAt).length,
      ineligibleHouseholds: rows.filter((h) => !h.isTest && h.ineligibleAt).length,
      totalUsageLogs: usageLogRows.length,
      totalNudgeResponses: nudgeResponseRows.length,
      acceptCount: nudgeResponseRows.filter((r) => r.response === "accept").length,
      declineCount: nudgeResponseRows.filter((r) => r.response === "decline").length,
    };

    const recentActivity: ActivityEvent[] = [
      ...usageLogRows.map((r) => ({
        householdId: r.householdId,
        type: "usage" as const,
        appliance: r.appliance,
        detail: `${r.windowAtUse ?? "—"}${r.isBackdated ? " (backdated)" : ""}`,
        createdAt: r.createdAt.toISOString(),
      })),
      ...nudgeResponseRows.map((r) => ({
        householdId: r.householdId,
        type: "nudge" as const,
        appliance: r.appliance,
        detail: `${r.response} (${r.window})`,
        createdAt: r.createdAt.toISOString(),
      })),
    ]
      .sort((a, b) => (a.createdAt < b.createdAt ? 1 : -1))
      .slice(0, 25);

    const initialRows: AdminHouseholdRow[] = rows.map((h) => ({
      id: h.id,
      phaseOverride: h.phaseOverride,
      phase: getPhase(h),
      firstLoginAt: h.firstLoginAt ? h.firstLoginAt.toISOString() : null,
      consentedAt: h.consentedAt ? h.consentedAt.toISOString() : null,
      ineligibleAt: h.ineligibleAt ? h.ineligibleAt.toISOString() : null,
      isTest: h.isTest,
    }));

    return { ok: true, data: { stats, recentActivity, initialRows } };
  } catch (err) {
    return {
      ok: false,
      error: err instanceof Error ? err.message : "Unknown error loading dashboard data.",
    };
  }
}

export default async function AdminPage() {
  await requireAdmin();

  const t = await getTranslations("admin");
  const result = await loadDashboardData();

  return (
    <main className="mx-auto flex min-h-full w-full max-w-4xl flex-1 flex-col gap-8 px-5 py-8">
      <div className="flex items-center justify-between">
        <h1 className="text-xl font-bold text-neutral-800">{t("title")}</h1>
        <LanguageSwitcher />
      </div>
      {!result.ok && (
        <div className="rounded-xl bg-amber-50 p-4 text-sm text-amber-800 ring-1 ring-amber-200">
          <p className="font-semibold">Couldn&apos;t load dashboard data.</p>
          <p className="mt-1">
            This usually means the database schema is out of date. Use &quot;Wipe &amp;
            reseed&quot; below to reset it to match the current app.
          </p>
          <p className="mt-2 font-mono text-xs opacity-70">{result.error}</p>
        </div>
      )}
      <AdminResetPanel />
      {result.ok && (
        <>
          <AdminOverview stats={result.data.stats} recentActivity={result.data.recentActivity} />
          <AdminTable initialRows={result.data.initialRows} />
        </>
      )}
    </main>
  );
}
