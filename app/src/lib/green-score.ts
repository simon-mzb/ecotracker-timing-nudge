import type { Appliance } from "./appliances";
import type { Window } from "./schedule";

const POINTS_BY_APPLIANCE: Record<Appliance, number> = {
  phone_charging: 1,
  washing_machine: 3,
  dishwasher: 3,
};

/**
 * Only a "great"-window accept rewards; a "bad"-window accept-anyway
 * penalizes by the same magnitude. "ok" windows and any decline don't move
 * the score - nothing to reward yet if they waited, and "ok" isn't worth
 * punishing.
 */
export function scoreDeltaFor(params: {
  appliance: Appliance;
  response: "accept" | "decline";
  window: Window;
}): number {
  if (params.response === "decline") return 0;
  const points = POINTS_BY_APPLIANCE[params.appliance];
  if (params.window === "great") return points;
  if (params.window === "bad") return -points;
  return 0;
}
