import { NextRequest, NextResponse } from "next/server";
import { z } from "zod";
import { eq } from "drizzle-orm";
import { db } from "@/db/client";
import { households, usageLogs } from "@/db/schema";
import { getHouseholdId } from "@/lib/auth";
import { getPhase } from "@/lib/phase";
import { getWindow } from "@/lib/schedule";
import { APPLIANCES } from "@/lib/appliances";

const bodySchema = z.object({
  appliance: z.enum(APPLIANCES),
  localHour: z.number().int().min(0).max(23),
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

  const [household] = await db
    .select()
    .from(households)
    .where(eq(households.id, householdId))
    .limit(1);

  if (!household) {
    return NextResponse.json({ error: "not_found" }, { status: 404 });
  }

  const phase = getPhase(household);
  if (phase !== 1) {
    return NextResponse.json({ error: "wrong_phase" }, { status: 403 });
  }

  const window = getWindow(parsed.data.localHour);

  await db.insert(usageLogs).values({
    householdId,
    appliance: parsed.data.appliance,
    windowAtUse: window,
  });

  return NextResponse.json({ ok: true });
}
