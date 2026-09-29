import { NextResponse } from "next/server";
import { eq } from "drizzle-orm";
import { db } from "@/db/client";
import { households } from "@/db/schema";
import { getHouseholdId } from "@/lib/auth";

export async function POST() {
  const householdId = await getHouseholdId();
  if (!householdId) {
    return NextResponse.json({ error: "unauthorized" }, { status: 401 });
  }

  const [household] = await db
    .select({ ineligibleAt: households.ineligibleAt })
    .from(households)
    .where(eq(households.id, householdId))
    .limit(1);

  if (household?.ineligibleAt) {
    return NextResponse.json({ error: "ineligible" }, { status: 403 });
  }

  await db
    .update(households)
    .set({ consentedAt: new Date() })
    .where(eq(households.id, householdId));

  return NextResponse.json({ ok: true });
}
