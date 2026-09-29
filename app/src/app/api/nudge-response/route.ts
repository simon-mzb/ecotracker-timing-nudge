import { NextRequest, NextResponse } from "next/server";
import { z } from "zod";
import { eq } from "drizzle-orm";
import { db } from "@/db/client";
import { households, nudgeResponses } from "@/db/schema";
import { getHouseholdId } from "@/lib/auth";
import { getPhase } from "@/lib/phase";
import { APPLIANCES } from "@/lib/appliances";
import { getWindow, getNextGreatWindow } from "@/lib/schedule";
import { scoreDeltaFor } from "@/lib/green-score";

const bodySchema = z.object({
  appliance: z.enum(APPLIANCES),
  localHour: z.number().int().min(0).max(23),
  response: z.enum(["accept", "decline"]),
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
  if (phase !== 2) {
    return NextResponse.json({ error: "wrong_phase" }, { status: 403 });
  }

  const data = parsed.data;
  const window = getWindow(data.localHour);
  const suggestedWaitHours =
    window === "bad" ? getNextGreatWindow(data.localHour).hoursUntil : null;

  await db.insert(nudgeResponses).values({
    householdId,
    appliance: data.appliance,
    window,
    response: data.response,
    suggestedWaitHours,
  });

  const delta = scoreDeltaFor({
    appliance: data.appliance,
    response: data.response,
    window,
  });

  let newScore = household.greenScore;
  if (delta !== 0) {
    newScore = household.greenScore + delta;
    await db
      .update(households)
      .set({ greenScore: newScore })
      .where(eq(households.id, householdId));
  }

  return NextResponse.json({ ok: true, window, delta, newScore, suggestedWaitHours });
}
