import { NextRequest, NextResponse } from "next/server";
import { z } from "zod";
import { eq } from "drizzle-orm";
import { db } from "@/db/client";
import { households } from "@/db/schema";
import { isAdmin } from "@/lib/auth";

const bodySchema = z.object({
  phaseOverride: z.enum(["1", "2"]).nullable().optional(),
});

export async function PATCH(
  req: NextRequest,
  { params }: { params: Promise<{ id: string }> },
) {
  if (!(await isAdmin())) {
    return NextResponse.json({ error: "unauthorized" }, { status: 401 });
  }

  const { id } = await params;
  const parsed = bodySchema.safeParse(await req.json().catch(() => null));
  if (!parsed.success) {
    return NextResponse.json({ error: "invalid_request" }, { status: 400 });
  }

  const update: Record<string, unknown> = {};
  if (parsed.data.phaseOverride !== undefined) {
    update.phaseOverride = parsed.data.phaseOverride;
  }

  if (Object.keys(update).length === 0) {
    return NextResponse.json({ error: "no_fields" }, { status: 400 });
  }

  await db.update(households).set(update).where(eq(households.id, id));

  return NextResponse.json({ ok: true });
}
