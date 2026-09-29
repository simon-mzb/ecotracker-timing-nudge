import { NextRequest, NextResponse } from "next/server";
import { z } from "zod";
import { eq } from "drizzle-orm";
import { db } from "@/db/client";
import { households, householdProfiles } from "@/db/schema";
import { getHouseholdId } from "@/lib/auth";

const bodySchema = z.object({
  ownsDishwasher: z.boolean(),
  ownsWashingMachine: z.boolean(),
  ownsPhoneChargingHabit: z.boolean(),
});

export async function POST(req: NextRequest) {
  const householdId = await getHouseholdId();
  if (!householdId) {
    return NextResponse.json({ error: "unauthorized" }, { status: 401 });
  }

  const parsed = bodySchema.safeParse(await req.json().catch(() => null));
  if (!parsed.success) {
    return NextResponse.json({ error: "invalid_request" }, { status: 400 });
  }
  const data = parsed.data;

  const eligible = data.ownsDishwasher || data.ownsWashingMachine;

  await db
    .insert(householdProfiles)
    .values({
      householdId,
      ownsDishwasher: data.ownsDishwasher,
      ownsWashingMachine: data.ownsWashingMachine,
      ownsPhoneChargingHabit: data.ownsPhoneChargingHabit,
    })
    .onConflictDoUpdate({
      target: householdProfiles.householdId,
      set: {
        ownsDishwasher: data.ownsDishwasher,
        ownsWashingMachine: data.ownsWashingMachine,
        ownsPhoneChargingHabit: data.ownsPhoneChargingHabit,
      },
    });

  if (!eligible) {
    await db
      .update(households)
      .set({ ineligibleAt: new Date() })
      .where(eq(households.id, householdId));
  }

  return NextResponse.json({ ok: true, eligible });
}
