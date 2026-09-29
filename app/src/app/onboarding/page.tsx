import { redirect } from "next/navigation";
import { eq } from "drizzle-orm";
import { requireHouseholdId } from "@/lib/auth";
import { db } from "@/db/client";
import { households } from "@/db/schema";
import OnboardingFlow from "@/components/OnboardingFlow";
import IneligibleScreen from "@/components/IneligibleScreen";
import LanguageSwitcher from "@/components/LanguageSwitcher";

export default async function OnboardingPage() {
  const householdId = await requireHouseholdId();

  const [household] = await db
    .select({ consentedAt: households.consentedAt, ineligibleAt: households.ineligibleAt })
    .from(households)
    .where(eq(households.id, householdId))
    .limit(1);

  if (household?.consentedAt) {
    redirect("/");
  }

  return (
    <main className="mx-auto flex min-h-full w-full max-w-sm flex-1 flex-col px-6 py-8">
      <div className="mb-6 self-end">
        <LanguageSwitcher />
      </div>
      {household?.ineligibleAt ? <IneligibleScreen /> : <OnboardingFlow />}
    </main>
  );
}
