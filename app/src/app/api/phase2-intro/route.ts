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

  await db
    .update(households)
    .set({ phase2IntroSeenAt: new Date() })
    .where(eq(households.id, householdId));

  return NextResponse.json({ ok: true });
}
