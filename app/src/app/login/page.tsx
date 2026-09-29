import { getTranslations } from "next-intl/server";
import { redirect } from "next/navigation";
import { eq } from "drizzle-orm";
import { getHouseholdId } from "@/lib/auth";
import { db } from "@/db/client";
import { households } from "@/db/schema";
import LoginForm from "@/components/LoginForm";
import LanguageSwitcher from "@/components/LanguageSwitcher";

export default async function LoginPage() {
  const householdId = await getHouseholdId();
  if (householdId) {
    const [household] = await db
      .select({ consentedAt: households.consentedAt })
      .from(households)
      .where(eq(households.id, householdId))
      .limit(1);
    redirect(household?.consentedAt ? "/" : "/onboarding");
  }

  const t = await getTranslations("login");
  const common = await getTranslations("common");

  return (
    <main className="flex min-h-full flex-1 flex-col items-center justify-center px-6 py-10">
      <div className="mb-6 self-end">
        <LanguageSwitcher />
      </div>
      <div className="w-full max-w-sm">
        <div className="mb-8 text-center">
          <p className="text-3xl">🌱</p>
          <h1 className="mt-2 text-2xl font-bold text-emerald-700">
            {common("appName")}
          </h1>
          <h2 className="mt-4 text-lg font-semibold text-neutral-800">
            {t("title")}
          </h2>
          <p className="mt-1 text-sm text-neutral-500">{t("subtitle")}</p>
        </div>
        <LoginForm />
      </div>
    </main>
  );
}
