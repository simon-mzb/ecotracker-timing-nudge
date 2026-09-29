import { NextRequest, NextResponse } from "next/server";
import { z } from "zod";
import { eq } from "drizzle-orm";
import { db } from "@/db/client";
import { households } from "@/db/schema";
import { getHouseholdId } from "@/lib/auth";

const bodySchema = z.object({ day: z.number().int().min(1).max(60).nullable() });

export async function POST(req: NextRequest) {
  const householdId = await getHouseholdId();
  if (!householdId) {
    return NextResponse.json({ error: "unauthorized" }, { status: 401 });
  }

  const [household] = await db
    .select({ isTest: households.isTest })
    .from(households)
    .where(eq(households.id, householdId))
    .limit(1);

  if (!household?.isTest) {
    return NextResponse.json({ error: "forbidden" }, { status: 403 });
  }

  const parsed = bodySchema.safeParse(await req.json().catch(() => null));
  if (!parsed.success) {
    return NextResponse.json({ error: "invalid_request" }, { status: 400 });
  }

  await db
    .update(households)
    .set({ dayOverride: parsed.data.day })
    .where(eq(households.id, householdId));

  return NextResponse.json({ ok: true });
}
