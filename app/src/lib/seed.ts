import { randomInt } from "crypto";
import bcrypt from "bcryptjs";
import { db } from "@/db/client";
import { households, householdProfiles } from "@/db/schema";

const PASSCODE_LETTERS = "ABCDEFGHIJKLMNOPQRSTUVWXYZ";

function randomPasscode(length = 4): string {
  let out = "";
  for (let i = 0; i < length; i++) {
    out += PASSCODE_LETTERS[randomInt(PASSCODE_LETTERS.length)];
  }
  return out;
}

export const TEST_HOUSEHOLD_ID = "000";
export const TEST_HOUSEHOLD_PASSCODE = "TEST";

async function seedTestHousehold() {
  const passcodeHash = await bcrypt.hash(TEST_HOUSEHOLD_PASSCODE, 10);

  await db
    .insert(households)
    .values({
      id: TEST_HOUSEHOLD_ID,
      passcodeHash,
      isTest: true,
      consentedAt: new Date(),
    })
    .onConflictDoUpdate({
      target: households.id,
      set: { passcodeHash, isTest: true, consentedAt: new Date() },
    });

  await db
    .insert(householdProfiles)
    .values({
      householdId: TEST_HOUSEHOLD_ID,
      householdSize: 1,
      dwellingType: "apartment",
      ownsDishwasher: true,
      ownsWashingMachine: true,
      ownsPhoneChargingHabit: true,
    })
    .onConflictDoUpdate({
      target: householdProfiles.householdId,
      set: {
        ownsDishwasher: true,
        ownsWashingMachine: true,
        ownsPhoneChargingHabit: true,
      },
    });
}

export type SeededCredential = { id: string; passcode: string; note?: string };

export async function seedHouseholds(count: number): Promise<SeededCredential[]> {
  await seedTestHousehold();

  const credentials: SeededCredential[] = [
    { id: TEST_HOUSEHOLD_ID, passcode: TEST_HOUSEHOLD_PASSCODE, note: "test/debug account, not a participant" },
  ];

  for (let i = 1; i <= count; i++) {
    const id = String(i).padStart(3, "0");
    const passcode = randomPasscode();
    const passcodeHash = await bcrypt.hash(passcode, 10);

    await db
      .insert(households)
      .values({ id, passcodeHash })
      .onConflictDoNothing();

    credentials.push({ id, passcode });
  }

  return credentials;
}

export function credentialsToCsv(credentials: SeededCredential[]): string {
  const lines = ["household_id,passcode"];
  for (const c of credentials) {
    lines.push(c.note ? `${c.id},${c.passcode} (${c.note})` : `${c.id},${c.passcode}`);
  }
  return lines.join("\n") + "\n";
}
