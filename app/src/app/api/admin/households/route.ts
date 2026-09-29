import { NextResponse } from "next/server";
import { db } from "@/db/client";
import { households } from "@/db/schema";
import { isAdmin } from "@/lib/auth";
import { getPhase } from "@/lib/phase";

export async function GET() {
  if (!(await isAdmin())) {
    return NextResponse.json({ error: "unauthorized" }, { status: 401 });
  }

  const rows = await db.select().from(households).orderBy(households.id);

  const result = rows.map((h) => ({
    id: h.id,
    phaseOverride: h.phaseOverride,
    phase: getPhase(h),
    firstLoginAt: h.firstLoginAt,
    consentedAt: h.consentedAt,
    ineligibleAt: h.ineligibleAt,
    isTest: h.isTest,
  }));

  return NextResponse.json({ households: result });
}
