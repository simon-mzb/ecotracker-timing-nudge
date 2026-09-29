import { NextRequest, NextResponse } from "next/server";
import { z } from "zod";
import { eq } from "drizzle-orm";
import { db } from "@/db/client";
import { households } from "@/db/schema";
import { createHouseholdSession, verifyPasscode } from "@/lib/auth";

const bodySchema = z.object({
  householdId: z.string().trim().min(1),
  passcode: z.string().min(1),
});

export async function POST(req: NextRequest) {
  const parsed = bodySchema.safeParse(await req.json().catch(() => null));
  if (!parsed.success) {
    return NextResponse.json({ error: "invalid_request" }, { status: 400 });
  }

  const householdId = parsed.data.householdId.trim().toUpperCase();

  const [household] = await db
    .select()
    .from(households)
    .where(eq(households.id, householdId))
    .limit(1);

  if (!household) {
    return NextResponse.json({ error: "invalid_credentials" }, { status: 401 });
  }

  const valid = await verifyPasscode(parsed.data.passcode, household.passcodeHash);
  if (!valid) {
    return NextResponse.json({ error: "invalid_credentials" }, { status: 401 });
  }

  if (!household.firstLoginAt) {
    await db
      .update(households)
      .set({ firstLoginAt: new Date() })
      .where(eq(households.id, householdId));
  }

  await createHouseholdSession(householdId);

  return NextResponse.json({
    ok: true,
    needsOnboarding: !household.consentedAt,
  });
}
