"use client";

import { useEffect, useState } from "react";
import Link from "next/link";
import { useRouter } from "next/navigation";
import { useTranslations } from "next-intl";
import WindowBanner from "./WindowBanner";
import GreenScoreTracker from "./GreenScoreTracker";
import ApplianceCard from "./ApplianceCard";
import LanguageSwitcher from "./LanguageSwitcher";
import HelpModal from "./HelpModal";
import DebugConditionPanel from "./DebugConditionPanel";
import { interpolate } from "@/lib/format";
import { getWindow, getNextGreatWindow, type Window } from "@/lib/schedule";
import type { Appliance } from "@/lib/appliances";

type Props = {
  phase: 1 | 2;
  studyDay: number;
  appliances: Appliance[];
  isTest: boolean;
  greenScore: number;
};

export default function HomeClient({
  phase,
  studyDay,
  appliances,
  isTest,
  greenScore,
}: Props) {
  const t = useTranslations("home");
  const tCommon = useTranslations("common");
  const tNudge = useTranslations("nudge");
  const tAppliances = useTranslations("appliances");
  const tInfo = useTranslations("info");
  const router = useRouter();

  // Starts null (not a lazy initializer) so server and client render the same
  // markup on mount; the real local hour only exists in the browser.
  const [currentHour, setCurrentHour] = useState<number | null>(null);
  const [windowOverride, setWindowOverride] = useState<Window | null>(null);
  const [loggedAppliances, setLoggedAppliances] = useState<Set<Appliance>>(new Set());
  const [responses, setResponses] = useState<Record<string, "accept" | "decline" | null>>({});
  const [score, setScore] = useState(greenScore);
  const [lastDelta, setLastDelta] = useState<number | null>(null);

  useEffect(() => {
    // Intentional: syncs client-only local time on mount (server has no
    // knowledge of the participant's timezone), not derived render state.
    // eslint-disable-next-line react-hooks/set-state-in-effect
    setCurrentHour(new Date().getHours());
    const interval = setInterval(() => setCurrentHour(new Date().getHours()), 60_000);
    return () => clearInterval(interval);
  }, []);

  const currentWindow: Window | null =
    windowOverride ?? (currentHour != null ? getWindow(currentHour) : null);

  async function handleStartNow(appliance: Appliance) {
    if (currentHour == null) return;
    const res = await fetch("/api/usage", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ appliance, localHour: currentHour }),
    });
    if (!res.ok) return;
    setLoggedAppliances((prev) => new Set(prev).add(appliance));
    setTimeout(() => {
      setLoggedAppliances((prev) => {
        const next = new Set(prev);
        next.delete(appliance);
        return next;
      });
    }, 2000);
  }

  async function handleRespond(appliance: Appliance, response: "accept" | "decline") {
    if (currentHour == null) return;
    const res = await fetch("/api/nudge-response", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ appliance, localHour: currentHour, response }),
    });
    if (!res.ok) return;
    const result = await res.json();
    setResponses((prev) => ({ ...prev, [appliance]: response }));
    if (result.delta) {
      setScore(result.newScore);
      setLastDelta(result.delta);
      setTimeout(() => setLastDelta(null), 2500);
    }
  }

  async function handleLogout() {
    await fetch("/api/auth/logout", { method: "POST" });
    router.push("/login");
    router.refresh();
  }

  const suggestedWaitHours =
    currentWindow === "bad" && currentHour != null
      ? getNextGreatWindow(currentHour).hoursUntil
      : null;

  const topBannerMessage = currentWindow
    ? interpolate(tNudge(currentWindow), {
        appliance: tAppliances("generic"),
        hours: suggestedWaitHours ?? "",
      })
    : "";

  return (
    <main className="mx-auto flex min-h-full w-full max-w-sm flex-1 flex-col gap-5 px-5 py-6">
      <header className="flex items-center justify-between">
        <div>
          <h1 className="text-xl font-bold text-emerald-700">
            🌱 {tCommon("appName")}
          </h1>
          <p className="text-xs text-neutral-500">{t("day", { day: studyDay })}</p>
        </div>
        <div className="flex items-center gap-2">
          <HelpModal phase={phase} />
          <LanguageSwitcher />
        </div>
      </header>

      {isTest && (
        <DebugConditionPanel
          currentDay={studyDay}
          onSelect={setWindowOverride}
          onReset={() => setWindowOverride(null)}
        />
      )}

      {phase === 2 && currentWindow && (
        <>
          <GreenScoreTracker score={score} lastDelta={lastDelta} />
          <WindowBanner window={currentWindow} message={topBannerMessage} />
          <Link
            href="/info"
            className="self-start text-xs font-medium text-emerald-700 underline-offset-2 hover:underline"
          >
            {tInfo("learnMoreLink")}
          </Link>
        </>
      )}

      <section className="flex flex-col gap-3">
        <h2 className="text-sm font-semibold uppercase tracking-wide text-neutral-500">
          {phase === 1 ? t("phase1Title") : t("phase2Title")}
        </h2>
        <div className="flex flex-col gap-3">
          {appliances.map((appliance) =>
            phase === 1 ? (
              <ApplianceCard
                key={appliance}
                mode="log"
                appliance={appliance}
                logged={loggedAppliances.has(appliance)}
                onStartNow={() => handleStartNow(appliance)}
              />
            ) : currentWindow ? (
              <ApplianceCard
                key={appliance}
                mode="nudge"
                appliance={appliance}
                window={currentWindow}
                suggestedWaitHours={suggestedWaitHours}
                responded={responses[appliance] ?? null}
                onRespond={(response) => handleRespond(appliance, response)}
              />
            ) : null,
          )}
        </div>
      </section>

      <button
        type="button"
        onClick={handleLogout}
        className="mt-auto self-center text-sm text-neutral-400 underline-offset-2 hover:text-neutral-600 hover:underline"
      >
        {tCommon("logout")}
      </button>
    </main>
  );
}
