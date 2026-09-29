import "dotenv/config";
import { writeFileSync } from "fs";
import { seedHouseholds, credentialsToCsv, TEST_HOUSEHOLD_ID } from "../src/lib/seed";

async function main() {
  const countArg = process.argv.find((a) => a.startsWith("--count="));
  const count = countArg ? Number(countArg.split("=")[1]) : 500;

  if (!Number.isInteger(count) || count < 1) {
    throw new Error("Invalid --count value");
  }

  const credentials = await seedHouseholds(count);
  const csv = credentialsToCsv(credentials);

  const outPath = "households-credentials.csv";
  writeFileSync(outPath, csv, "utf-8");

  console.log(csv);
  console.log(`Seeded ${count} households (+ 1 test household ${TEST_HOUSEHOLD_ID}). Credentials written to ${outPath}`);
  console.log("This file is gitignored — hand it to participants and delete it once distributed.");
}

main()
  .then(() => process.exit(0))
  .catch((err) => {
    console.error(err);
    process.exit(1);
  });
