import { redirect } from "next/navigation";
import { eq } from "drizzle-orm";
import { requireHouseholdId } from "@/lib/auth";
import { db } from "@/db/client";
import { households, householdProfiles } from "@/db/schema";
import { getPhase, getStudyDay } from "@/lib/phase";
import { APPLIANCES, type Appliance } from "@/lib/appliances";
import HomeClient from "@/components/HomeClient";
import Phase2Intro from "@/components/Phase2Intro";

export default async function HomePage() {
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

  const [profile] = await db
    .select()
    .from(householdProfiles)
    .where(eq(householdProfiles.householdId, householdId))
    .limit(1);

  let appliances: Appliance[] = [];
  if (profile) {
    if (profile.ownsDishwasher) appliances.push("dishwasher");
    if (profile.ownsWashingMachine) appliances.push("washing_machine");
    if (profile.ownsPhoneChargingHabit) appliances.push("phone_charging");
  }
  if (appliances.length === 0) {
    appliances = [...APPLIANCES];
  }

  const phase = getPhase(household);
  const studyDay = getStudyDay(household);

  if (phase === 2 && !household.phase2IntroSeenAt && !household.isTest) {
    return <Phase2Intro />;
  }

  return (
    <HomeClient
      phase={phase}
      studyDay={studyDay}
      appliances={appliances}
      isTest={household.isTest}
      greenScore={household.greenScore}
    />
  );
}
