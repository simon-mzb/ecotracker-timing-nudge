import { NextRequest, NextResponse } from "next/server";
import { timingSafeEqual } from "crypto";
import { z } from "zod";
import { createAdminSession } from "@/lib/auth";

const bodySchema = z.object({ passcode: z.string().min(1) });

function safeCompare(a: string, b: string): boolean {
  const bufA = Buffer.from(a);
  const bufB = Buffer.from(b);
  if (bufA.length !== bufB.length) return false;
  return timingSafeEqual(bufA, bufB);
}

export async function POST(req: NextRequest) {
  const adminPasscode = process.env.ADMIN_PASSCODE;
  if (!adminPasscode) {
    return NextResponse.json({ error: "not_configured" }, { status: 500 });
  }

  const parsed = bodySchema.safeParse(await req.json().catch(() => null));
  if (!parsed.success) {
    return NextResponse.json({ error: "invalid_request" }, { status: 400 });
  }

  if (!safeCompare(parsed.data.passcode, adminPasscode)) {
    return NextResponse.json({ error: "invalid_credentials" }, { status: 401 });
  }

  await createAdminSession();
  return NextResponse.json({ ok: true });
}
