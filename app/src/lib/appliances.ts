export const APPLIANCES = [
  "dishwasher",
  "washing_machine",
  "phone_charging",
] as const;

export type Appliance = (typeof APPLIANCES)[number];
