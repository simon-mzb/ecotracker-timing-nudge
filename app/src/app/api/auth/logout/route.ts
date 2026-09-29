import { NextResponse } from "next/server";
import { clearHouseholdSession } from "@/lib/auth";

export async function POST() {
  await clearHouseholdSession();
  return NextResponse.json({ ok: true });
}
