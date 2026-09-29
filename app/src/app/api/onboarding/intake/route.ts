import { NextRequest, NextResponse } from "next/server";
import { z } from "zod";
import { eq } from "drizzle-orm";
import { db } from "@/db/client";
import { householdProfiles } from "@/db/schema";
import { getHouseholdId } from "@/lib/auth";

const bodySchema = z.object({
  householdSize: z.number().int().min(1).max(20),
  dwellingType: z.enum(["house", "apartment", "other"]),
  ageBracket: z.string().trim().optional(),
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

  await db
    .update(householdProfiles)
    .set({
      householdSize: data.householdSize,
      dwellingType: data.dwellingType,
      ageBracket: data.ageBracket || null,
    })
    .where(eq(householdProfiles.householdId, householdId));

  return NextResponse.json({ ok: true });
}
