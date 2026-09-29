import {
  pgTable,
  text,
  timestamp,
  boolean,
  integer,
  pgEnum,
  uuid,
} from "drizzle-orm/pg-core";

export const dwellingTypeEnum = pgEnum("dwelling_type", [
  "house",
  "apartment",
  "other",
]);
export const applianceEnum = pgEnum("appliance", [
  "dishwasher",
  "washing_machine",
  "phone_charging",
]);
export const windowEnum = pgEnum("window", ["great", "ok", "bad"]);
export const nudgeResponseEnum = pgEnum("nudge_response", [
  "accept",
  "decline",
]);
export const phaseOverrideEnum = pgEnum("phase_override", ["1", "2"]);

export const households = pgTable("households", {
  id: text("id").primaryKey(),
  passcodeHash: text("passcode_hash").notNull(),
  firstLoginAt: timestamp("first_login_at", { withTimezone: true }),
  phaseOverride: phaseOverrideEnum("phase_override"),
  ineligibleAt: timestamp("ineligible_at", { withTimezone: true }),
  consentedAt: timestamp("consented_at", { withTimezone: true }),
  phase2IntroSeenAt: timestamp("phase2_intro_seen_at", { withTimezone: true }),
  isTest: boolean("is_test").notNull().default(false),
  greenScore: integer("green_score").notNull().default(0),
  dayOverride: integer("day_override"),
  createdAt: timestamp("created_at", { withTimezone: true })
    .notNull()
    .defaultNow(),
});

export const householdProfiles = pgTable("household_profiles", {
  householdId: text("household_id")
    .primaryKey()
    .references(() => households.id),
  // Set at the screening step, before size/dwelling/age are known.
  ownsDishwasher: boolean("owns_dishwasher").notNull().default(false),
  ownsWashingMachine: boolean("owns_washing_machine")
    .notNull()
    .default(false),
  ownsPhoneChargingHabit: boolean("owns_phone_charging_habit")
    .notNull()
    .default(false),
  // Filled in later, at the remaining-intake step.
  householdSize: integer("household_size"),
  dwellingType: dwellingTypeEnum("dwelling_type"),
  ageBracket: text("age_bracket"),
  createdAt: timestamp("created_at", { withTimezone: true })
    .notNull()
    .defaultNow(),
});

export const usageLogs = pgTable("usage_logs", {
  id: uuid("id").defaultRandom().primaryKey(),
  householdId: text("household_id")
    .notNull()
    .references(() => households.id),
  appliance: applianceEnum("appliance").notNull(),
  startedAt: timestamp("started_at", { withTimezone: true })
    .notNull()
    .defaultNow(),
  windowAtUse: windowEnum("window_at_use"),
  isBackdated: boolean("is_backdated").notNull().default(false),
  createdAt: timestamp("created_at", { withTimezone: true })
    .notNull()
    .defaultNow(),
});

export const nudgeResponses = pgTable("nudge_responses", {
  id: uuid("id").defaultRandom().primaryKey(),
  householdId: text("household_id")
    .notNull()
    .references(() => households.id),
  appliance: applianceEnum("appliance").notNull(),
  window: windowEnum("window").notNull(),
  response: nudgeResponseEnum("response").notNull(),
  suggestedWaitHours: integer("suggested_wait_hours"),
  createdAt: timestamp("created_at", { withTimezone: true })
    .notNull()
    .defaultNow(),
});
