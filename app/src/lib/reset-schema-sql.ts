/**
 * The full schema as individual statements, embedded directly (rather than
 * read from ./drizzle at runtime, which Next.js's serverless file tracing
 * won't reliably bundle). Generated once via `drizzle-kit generate` from
 * src/db/schema.ts — keep in sync if the schema changes again.
 */
export const RESET_SCHEMA_STATEMENTS: string[] = [
  `CREATE TYPE "public"."appliance" AS ENUM('dishwasher', 'washing_machine', 'phone_charging')`,
  `CREATE TYPE "public"."dwelling_type" AS ENUM('house', 'apartment', 'other')`,
  `CREATE TYPE "public"."nudge_response" AS ENUM('accept', 'decline')`,
  `CREATE TYPE "public"."phase_override" AS ENUM('1', '2')`,
  `CREATE TYPE "public"."window" AS ENUM('great', 'ok', 'bad')`,
  `CREATE TABLE "household_profiles" (
	"household_id" text PRIMARY KEY NOT NULL,
	"owns_dishwasher" boolean DEFAULT false NOT NULL,
	"owns_washing_machine" boolean DEFAULT false NOT NULL,
	"owns_phone_charging_habit" boolean DEFAULT false NOT NULL,
	"household_size" integer,
	"dwelling_type" "dwelling_type",
	"age_bracket" text,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL
)`,
  `CREATE TABLE "households" (
	"id" text PRIMARY KEY NOT NULL,
	"passcode_hash" text NOT NULL,
	"first_login_at" timestamp with time zone,
	"phase_override" "phase_override",
	"ineligible_at" timestamp with time zone,
	"consented_at" timestamp with time zone,
	"phase2_intro_seen_at" timestamp with time zone,
	"is_test" boolean DEFAULT false NOT NULL,
	"green_score" integer DEFAULT 0 NOT NULL,
	"day_override" integer,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL
)`,
  `CREATE TABLE "nudge_responses" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"household_id" text NOT NULL,
	"appliance" "appliance" NOT NULL,
	"window" "window" NOT NULL,
	"response" "nudge_response" NOT NULL,
	"suggested_wait_hours" integer,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL
)`,
  `CREATE TABLE "usage_logs" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"household_id" text NOT NULL,
	"appliance" "appliance" NOT NULL,
	"started_at" timestamp with time zone DEFAULT now() NOT NULL,
	"window_at_use" "window",
	"is_backdated" boolean DEFAULT false NOT NULL,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL
)`,
  `ALTER TABLE "household_profiles" ADD CONSTRAINT "household_profiles_household_id_households_id_fk" FOREIGN KEY ("household_id") REFERENCES "public"."households"("id") ON DELETE no action ON UPDATE no action`,
  `ALTER TABLE "nudge_responses" ADD CONSTRAINT "nudge_responses_household_id_households_id_fk" FOREIGN KEY ("household_id") REFERENCES "public"."households"("id") ON DELETE no action ON UPDATE no action`,
  `ALTER TABLE "usage_logs" ADD CONSTRAINT "usage_logs_household_id_households_id_fk" FOREIGN KEY ("household_id") REFERENCES "public"."households"("id") ON DELETE no action ON UPDATE no action`,
];
