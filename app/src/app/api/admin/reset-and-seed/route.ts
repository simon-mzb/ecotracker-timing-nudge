import { NextRequest, NextResponse } from "next/server";
import { z } from "zod";
import { sql } from "drizzle-orm";
import { db } from "@/db/client";
import { isAdmin } from "@/lib/auth";
import { RESET_SCHEMA_STATEMENTS } from "@/lib/reset-schema-sql";
import { seedHouseholds, credentialsToCsv } from "@/lib/seed";

const bodySchema = z.object({
  count: z.number().int().min(1).max(2000),
  confirmText: z.literal("RESET"),
});

export async function POST(req: NextRequest) {
  if (!(await isAdmin())) {
    return NextResponse.json({ error: "unauthorized" }, { status: 401 });
  }

  const parsed = bodySchema.safeParse(await req.json().catch(() => null));
  if (!parsed.success) {
    return NextResponse.json({ error: "invalid_request" }, { status: 400 });
  }

  await db.execute(sql.raw(`DROP SCHEMA public CASCADE`));
  await db.execute(sql.raw(`CREATE SCHEMA public`));
  for (const statement of RESET_SCHEMA_STATEMENTS) {
    await db.execute(sql.raw(statement));
  }

  const credentials = await seedHouseholds(parsed.data.count);
  const csv = credentialsToCsv(credentials);

  return new NextResponse(csv, {
    headers: {
      "Content-Type": "text/csv; charset=utf-8",
      "Content-Disposition": `attachment; filename="households-credentials.csv"`,
    },
  });
}
