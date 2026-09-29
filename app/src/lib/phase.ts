const STAGE_SWITCH_DAYS = 7;

export type Phase = 1 | 2;

type PhaseInput = {
  firstLoginAt: Date | null;
  phaseOverride: "1" | "2" | null;
  dayOverride: number | null;
};

export function getPhase(household: PhaseInput): Phase {
  if (household.dayOverride != null) {
    return household.dayOverride >= STAGE_SWITCH_DAYS + 1 ? 2 : 1;
  }
  if (household.phaseOverride) {
    return Number(household.phaseOverride) as Phase;
  }
  if (!household.firstLoginAt) return 1;
  const daysSinceFirstLogin =
    (Date.now() - household.firstLoginAt.getTime()) / (1000 * 60 * 60 * 24);
  return daysSinceFirstLogin >= STAGE_SWITCH_DAYS ? 2 : 1;
}

export function getStudyDay(household: Pick<PhaseInput, "firstLoginAt" | "dayOverride">): number {
  if (household.dayOverride != null) return household.dayOverride;
  if (!household.firstLoginAt) return 1;
  const days = Math.floor(
    (Date.now() - household.firstLoginAt.getTime()) / (1000 * 60 * 60 * 24),
  );
  return days + 1;
}
