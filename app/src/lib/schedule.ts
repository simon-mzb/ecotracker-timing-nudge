export type Window = "great" | "ok" | "bad";

const OK_MORNING_START = 8;
const GREAT_START = 10;
const GREAT_END = 17;
const OK_EVENING_END = 19;

/**
 * Fixed daily schedule (participant's local hour, no live data):
 * 08:00-10:00 ok, 10:00-17:00 great, 17:00-19:00 ok, else bad.
 */
export function getWindow(hour: number): Window {
  if (hour >= GREAT_START && hour < GREAT_END) return "great";
  if (hour >= OK_MORNING_START && hour < GREAT_START) return "ok";
  if (hour >= GREAT_END && hour < OK_EVENING_END) return "ok";
  return "bad";
}

/** Only a "bad" window needs the are-you-sure friction. */
export function needsConfirmation(window: Window): boolean {
  return window === "bad";
}

/** Only "great" is worth actively rewarding; "ok" is neutral. */
export function isGreat(window: Window): boolean {
  return window === "great";
}

const WINDOW_LABEL = "10:00-17:00";

/**
 * Hours until the next "great" window starts, and a human label for it.
 * Always computable since the schedule is fixed.
 */
export function getNextGreatWindow(hour: number): { hoursUntil: number; label: string } {
  const hoursUntil = hour < GREAT_START ? GREAT_START - hour : 24 - hour + GREAT_START;
  return { hoursUntil, label: WINDOW_LABEL };
}

export function hourFromDate(date: Date): number {
  return date.getHours();
}
