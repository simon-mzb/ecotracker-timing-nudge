"use client";

import { useState } from "react";
import { useRouter } from "next/navigation";
import { useTranslations } from "next-intl";
import { APPLIANCES, type Appliance } from "@/lib/appliances";
import IneligibleScreen from "./IneligibleScreen";

const AGE_BRACKETS = ["18-24", "25-34", "35-44", "45-54", "55-64", "65+"];

type Step = "screening" | "ineligible" | "consent" | "intake";

export default function OnboardingFlow() {
  const tScreening = useTranslations("onboarding.screening");
  const tConsent = useTranslations("onboarding.consent");
  const tIntake = useTranslations("onboarding.intake");
  const tAppliances = useTranslations("appliances");
  const router = useRouter();

  const [step, setStep] = useState<Step>("screening");
  const [submitting, setSubmitting] = useState(false);
  const [error, setError] = useState(false);

  const [owned, setOwned] = useState<Record<Appliance, boolean>>({
    dishwasher: false,
    washing_machine: false,
    phone_charging: false,
  });
  const [householdSize, setHouseholdSize] = useState(1);
  const [dwellingType, setDwellingType] = useState<"house" | "apartment" | "other">("apartment");
  const [ageBracket, setAgeBracket] = useState("");

  function toggleAppliance(appliance: Appliance) {
    setOwned((prev) => ({ ...prev, [appliance]: !prev[appliance] }));
  }

  async function handleScreeningSubmit(e: React.FormEvent) {
    e.preventDefault();
    setSubmitting(true);
    setError(false);

    const res = await fetch("/api/onboarding/screening", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        ownsDishwasher: owned.dishwasher,
        ownsWashingMachine: owned.washing_machine,
        ownsPhoneChargingHabit: owned.phone_charging,
      }),
    });

    setSubmitting(false);
    if (!res.ok) {
      setError(true);
      return;
    }
    const data = await res.json();
    setStep(data.eligible ? "consent" : "ineligible");
  }

  async function handleConsentAgree() {
    setSubmitting(true);
    setError(false);
    const res = await fetch("/api/onboarding/consent", { method: "POST" });
    setSubmitting(false);
    if (!res.ok) {
      setError(true);
      return;
    }
    setStep("intake");
  }

  async function handleIntakeSubmit(e: React.FormEvent) {
    e.preventDefault();
    setSubmitting(true);
    setError(false);

    const res = await fetch("/api/onboarding/intake", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        householdSize,
        dwellingType,
        ageBracket: ageBracket || undefined,
      }),
    });

    if (!res.ok) {
      setError(true);
      setSubmitting(false);
      return;
    }

    router.push("/");
    router.refresh();
  }

  if (step === "screening") {
    return (
      <form onSubmit={handleScreeningSubmit} className="flex flex-col gap-5">
        <div>
          <h1 className="text-xl font-bold text-neutral-900">{tScreening("title")}</h1>
          <p className="mt-1 text-sm text-neutral-500">{tScreening("subtitle")}</p>
        </div>
        <div className="flex flex-col gap-2">
          {APPLIANCES.map((appliance) => (
            <label
              key={appliance}
              className="flex items-center gap-3 rounded-xl border border-neutral-300 px-4 py-3"
            >
              <input
                type="checkbox"
                checked={owned[appliance]}
                onChange={() => toggleAppliance(appliance)}
                className="h-4 w-4 accent-emerald-600"
              />
              <span className="text-sm text-neutral-800">{tAppliances(appliance)}</span>
            </label>
          ))}
        </div>
        {error && <p className="text-sm text-red-600">{tScreening("error")}</p>}
        <button
          type="submit"
          disabled={submitting}
          className="rounded-xl bg-emerald-600 px-4 py-3 text-base font-semibold text-white shadow-sm transition-colors hover:bg-emerald-700 disabled:opacity-60"
        >
          {tScreening("continue")}
        </button>
      </form>
    );
  }

  if (step === "ineligible") {
    return <IneligibleScreen />;
  }

  if (step === "consent") {
    return (
      <div className="flex flex-col gap-4">
        <h1 className="text-xl font-bold text-neutral-900">{tConsent("title")}</h1>
        <p className="text-sm text-neutral-600">{tConsent("intro")}</p>
        <ul className="flex flex-col gap-3 text-sm text-neutral-700">
          <li className="rounded-xl bg-emerald-50 p-3 ring-1 ring-emerald-100">
            {tConsent("point1")}
          </li>
          <li className="rounded-xl bg-emerald-50 p-3 ring-1 ring-emerald-100">
            {tConsent("point2")}
          </li>
          <li className="rounded-xl bg-emerald-50 p-3 ring-1 ring-emerald-100">
            {tConsent("point4")}
          </li>
        </ul>
        {error && <p className="text-sm text-red-600">{tScreening("error")}</p>}
        <button
          type="button"
          onClick={handleConsentAgree}
          disabled={submitting}
          className="mt-2 rounded-xl bg-emerald-600 px-4 py-3 text-base font-semibold text-white shadow-sm transition-colors hover:bg-emerald-700 disabled:opacity-60"
        >
          {tConsent("agree")}
        </button>
      </div>
    );
  }

  return (
    <form onSubmit={handleIntakeSubmit} className="flex flex-col gap-5">
      <div>
        <h1 className="text-xl font-bold text-neutral-900">{tIntake("title")}</h1>
        <p className="mt-1 text-sm text-neutral-500">{tIntake("subtitle")}</p>
      </div>

      <div className="flex flex-col gap-1">
        <label htmlFor="householdSize" className="text-sm font-medium text-neutral-700">
          {tIntake("householdSize")}
        </label>
        <input
          id="householdSize"
          type="number"
          min={1}
          max={20}
          value={householdSize}
          onChange={(e) => setHouseholdSize(Number(e.target.value))}
          required
          className="rounded-xl border border-neutral-300 px-4 py-3 text-base focus:border-emerald-500 focus:outline-none focus:ring-2 focus:ring-emerald-200"
        />
      </div>

      <div className="flex flex-col gap-1">
        <span className="text-sm font-medium text-neutral-700">{tIntake("dwellingType")}</span>
        <div className="flex gap-2">
          {(["house", "apartment", "other"] as const).map((type) => (
            <button
              key={type}
              type="button"
              onClick={() => setDwellingType(type)}
              className={`flex-1 rounded-xl px-3 py-2 text-sm font-medium ring-1 transition-colors ${
                dwellingType === type
                  ? "bg-emerald-600 text-white ring-emerald-600"
                  : "bg-white text-neutral-600 ring-neutral-300"
              }`}
            >
              {tIntake(
                type === "house"
                  ? "dwellingHouse"
                  : type === "apartment"
                    ? "dwellingApartment"
                    : "dwellingOther",
              )}
            </button>
          ))}
        </div>
      </div>

      <div className="flex flex-col gap-1">
        <label htmlFor="ageBracket" className="text-sm font-medium text-neutral-700">
          {tIntake("ageBracket")}
        </label>
        <select
          id="ageBracket"
          value={ageBracket}
          onChange={(e) => setAgeBracket(e.target.value)}
          className="rounded-xl border border-neutral-300 px-4 py-3 text-base focus:border-emerald-500 focus:outline-none focus:ring-2 focus:ring-emerald-200"
        >
          <option value="">{tIntake("ageBracketSkip")}</option>
          {AGE_BRACKETS.map((bracket) => (
            <option key={bracket} value={bracket}>
              {bracket}
            </option>
          ))}
        </select>
      </div>

      {error && <p className="text-sm text-red-600">{tScreening("error")}</p>}

      <button
        type="submit"
        disabled={submitting}
        className="rounded-xl bg-emerald-600 px-4 py-3 text-base font-semibold text-white shadow-sm transition-colors hover:bg-emerald-700 disabled:opacity-60"
      >
        {tIntake("submit")}
      </button>
    </form>
  );
}
