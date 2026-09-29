import { NextRequest, NextResponse } from "next/server";
import { db } from "@/db/client";
import { usageLogs, nudgeResponses, householdProfiles } from "@/db/schema";
import { isAdmin } from "@/lib/auth";
import { toCsv } from "@/lib/csv";

const TABLES = {
  usage_logs: usageLogs,
  nudge_responses: nudgeResponses,
  household_profiles: householdProfiles,
} as const;

type TableName = keyof typeof TABLES;

function isValidTable(value: string): value is TableName {
  return value in TABLES;
}

export async function GET(
  _req: NextRequest,
  { params }: { params: Promise<{ table: string }> },
) {
  if (!(await isAdmin())) {
    return NextResponse.json({ error: "unauthorized" }, { status: 401 });
  }

  const { table } = await params;
  if (!isValidTable(table)) {
    return NextResponse.json({ error: "unknown_table" }, { status: 404 });
  }

  const rows = await db.select().from(TABLES[table]);
  const csv = toCsv(rows as Record<string, unknown>[]);

  return new NextResponse(csv, {
    headers: {
      "Content-Type": "text/csv; charset=utf-8",
      "Content-Disposition": `attachment; filename="${table}.csv"`,
    },
  });
}
