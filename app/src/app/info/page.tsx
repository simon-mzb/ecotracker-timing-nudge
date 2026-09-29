import { redirect } from "next/navigation";
import { eq } from "drizzle-orm";
import Link from "next/link";
import { getTranslations } from "next-intl/server";
import { requireHouseholdId } from "@/lib/auth";
import { db } from "@/db/client";
import { households } from "@/db/schema";
import { getPhase } from "@/lib/phase";
import LanguageSwitcher from "@/components/LanguageSwitcher";

export default async function InfoPage() {
  const householdId = await requireHouseholdId();

  const [household] = await db
    .select()
    .from(households)
    .where(eq(households.id, householdId))
    .limit(1);

  if (!household) {
    redirect("/login");
  }
  if (!household.consentedAt) {
    redirect("/onboarding");
  }
  if (getPhase(household) !== 2) {
    redirect("/");
  }

  const t = await getTranslations("info");

  return (
    <main className="mx-auto flex min-h-full w-full max-w-sm flex-1 flex-col gap-6 px-6 py-8">
      <div className="flex items-center justify-between">
        <Link href="/" className="text-sm font-medium text-neutral-500 hover:text-neutral-700">
          {t("back")}
        </Link>
        <LanguageSwitcher />
      </div>

      <div className="flex flex-col gap-4">
        <p className="text-3xl">💡</p>
        <h1 className="text-xl font-bold text-neutral-900">{t("title")}</h1>
        <p className="text-sm text-neutral-700">{t("body1")}</p>
        <div className="rounded-xl bg-emerald-50 p-4 ring-1 ring-emerald-100">
          <p className="text-sm font-semibold text-emerald-900">{t("statTitle")}</p>
          <div className="mt-2 flex items-center justify-between text-sm text-emerald-800">
            <span>{t("statEvening")}</span>
            <span className="font-bold">62.6%</span>
          </div>
          <div className="mt-1 flex items-center justify-between text-sm text-emerald-800">
            <span>{t("statNoon")}</span>
            <span className="font-bold">84.5%</span>
          </div>
          <p className="mt-2 text-xs text-emerald-700">{t("statSource")}</p>
        </div>
        <p className="text-sm text-neutral-700">{t("body2")}</p>
        <a
          href="https://www.smard.de/home/marktdaten/?marketDataAttributes=%7B%22resolution%22:%22hour%22,%22from%22:1785621600000,%22to%22:1786571999999,%22subcategoryIds%22:%5B1%5D,%22moduleIds%22:%5B1004066,1001226,1001225,1004067,1004068,1001228,1001224,1001223,1004069,1004071,1004070,1001227%5D,%22activeChart%22:true,%22style%22:%22color%22,%22region%22:%22DE%22,%22selectedCategory%22:1%7D"
          target="_blank"
          rel="noopener noreferrer"
          className="mt-2 inline-block rounded-xl bg-emerald-600 px-4 py-3 text-center text-sm font-semibold text-white shadow-sm transition-colors hover:bg-emerald-700"
        >
          {t("linkText")}
        </a>
      </div>
    </main>
  );
}
