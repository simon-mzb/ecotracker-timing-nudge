import { NextRequest, NextResponse } from "next/server";
import { z } from "zod";
import { db } from "@/db/client";
import { usageLogs } from "@/db/schema";
import { getHouseholdId } from "@/lib/auth";
import { getWindow } from "@/lib/schedule";
import { APPLIANCES } from "@/lib/appliances";

const MAX_LOOKBACK_MS = 24 * 60 * 60 * 1000;
const FUTURE_TOLERANCE_MS = 2 * 60 * 1000;

const bodySchema = z.object({
  appliance: z.enum(APPLIANCES),
  chosenAt: z.string(),
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

  const chosenAt = new Date(parsed.data.chosenAt);
  if (Number.isNaN(chosenAt.getTime())) {
    return NextResponse.json({ error: "invalid_time" }, { status: 400 });
  }

  const now = Date.now();
  if (chosenAt.getTime() > now + FUTURE_TOLERANCE_MS) {
    return NextResponse.json({ error: "time_in_future" }, { status: 400 });
  }
  if (chosenAt.getTime() < now - MAX_LOOKBACK_MS) {
    return NextResponse.json({ error: "time_too_old" }, { status: 400 });
  }

  const window = getWindow(parsed.data.localHour);

  await db.insert(usageLogs).values({
    householdId,
    appliance: parsed.data.appliance,
    startedAt: chosenAt,
    windowAtUse: window,
    isBackdated: true,
  });

  return NextResponse.json({ ok: true, window });
}
