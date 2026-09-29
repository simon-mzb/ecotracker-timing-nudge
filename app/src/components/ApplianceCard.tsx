"use client";

import { useState } from "react";
import { useTranslations } from "next-intl";
import { interpolate } from "@/lib/format";
import ConfirmTapButton from "./ConfirmTapButton";
import BackdatedEntryButton from "./BackdatedEntryButton";
import type { Appliance } from "@/lib/appliances";
import { needsConfirmation } from "@/lib/schedule";
import type { Window } from "@/lib/schedule";

type LogModeProps = {
  mode: "log";
  appliance: Appliance;
  logged: boolean;
  onStartNow: () => void;
};

type NudgeModeProps = {
  mode: "nudge";
  appliance: Appliance;
  window: Window;
  suggestedWaitHours: number | null;
  responded: "accept" | "decline" | null;
  onRespond: (response: "accept" | "decline") => void;
};

export default function ApplianceCard(props: LogModeProps | NudgeModeProps) {
  const tAppliances = useTranslations("appliances");
  const tHome = useTranslations("home");
  const [confirming, setConfirming] = useState(false);

  const applianceName = tAppliances(props.appliance);

  return (
    <div className="rounded-2xl bg-white p-4 shadow-sm ring-1 ring-neutral-200">
      <div className="mb-3 flex items-center gap-2">
        <span className="text-xl">{APPLIANCE_ICONS[props.appliance]}</span>
        <h3 className="font-semibold text-neutral-800">{applianceName}</h3>
      </div>

      {props.mode === "log" ? (
        <div className="flex items-center gap-2">
          <ConfirmTapButton
            onConfirm={props.onStartNow}
            idleLabel={props.logged ? tHome("logged") : tHome("startNow")}
            confirmLabel={tHome("tapToConfirm")}
            className="flex-1 rounded-xl bg-emerald-100 px-4 py-2.5 text-sm font-semibold text-emerald-800 transition-colors hover:bg-emerald-200"
          />
          <BackdatedEntryButton appliance={props.appliance} phase={1} />
        </div>
      ) : (
        <NudgeCardBody
          {...props}
          applianceName={applianceName}
          confirming={confirming}
          setConfirming={setConfirming}
        />
      )}
    </div>
  );
}

const APPLIANCE_ICONS: Record<Appliance, string> = {
  dishwasher: "🍽️",
  washing_machine: "🧺",
  phone_charging: "🔌",
};

function NudgeCardBody({
  window,
  suggestedWaitHours,
  responded,
  onRespond,
  appliance,
  applianceName,
  confirming,
  setConfirming,
}: NudgeModeProps & {
  applianceName: string;
  confirming: boolean;
  setConfirming: (value: boolean) => void;
}) {
  const tHome = useTranslations("home");

  if (responded === "accept") {
    const text =
      window === "great"
        ? tHome("praiseAfterAccept")
        : window === "ok"
          ? tHome("ackAfterAcceptOk")
          : tHome("ackAfterAcceptBad");
    return (
      <p className="text-sm font-medium text-emerald-700">
        {interpolate(text, { appliance: applianceName })}
      </p>
    );
  }

  if (responded === "decline") {
    const text =
      suggestedWaitHours != null
        ? interpolate(tHome("ackAfterDeclineWithHours"), {
            appliance: applianceName,
            hours: suggestedWaitHours,
          })
        : interpolate(tHome("ackAfterDeclineGeneric"), { appliance: applianceName });
    return <p className="text-sm font-medium text-emerald-700">{text}</p>;
  }

  if (confirming) {
    const body =
      suggestedWaitHours != null
        ? interpolate(tHome("confirmBodyWithHours"), {
            appliance: applianceName,
            hours: suggestedWaitHours,
          })
        : interpolate(tHome("confirmBodyGeneric"), { appliance: applianceName });
    return (
      <div className="flex flex-col gap-2 rounded-xl bg-amber-50 p-3 ring-1 ring-amber-200">
        <p className="text-sm font-semibold text-amber-900">{tHome("confirmTitle")}</p>
        <p className="text-sm text-amber-800">{body}</p>
        <div className="mt-1 flex gap-2">
          <button
            type="button"
            onClick={() => onRespond("accept")}
            className="flex-1 rounded-xl bg-amber-600 px-3 py-2 text-sm font-semibold text-white transition-colors hover:bg-amber-700"
          >
            {tHome("useAnyway")}
          </button>
          <button
            type="button"
            onClick={() => onRespond("decline")}
            className="flex-1 rounded-xl bg-white px-3 py-2 text-sm font-semibold text-amber-800 ring-1 ring-amber-300 transition-colors hover:bg-amber-100"
          >
            {tHome("wait")}
          </button>
        </div>
      </div>
    );
  }

  const useNowLabel = interpolate(tHome("useNow"), { appliance: applianceName });

  return (
    <div className="flex items-center gap-2">
      {needsConfirmation(window) ? (
        <button
          type="button"
          onClick={() => setConfirming(true)}
          className="flex-1 rounded-xl bg-emerald-600 px-4 py-2.5 text-sm font-semibold text-white transition-colors hover:bg-emerald-700"
        >
          {useNowLabel}
        </button>
      ) : (
        <ConfirmTapButton
          onConfirm={() => onRespond("accept")}
          idleLabel={useNowLabel}
          confirmLabel={tHome("tapToConfirm")}
          className="flex-1 rounded-xl bg-emerald-600 px-4 py-2.5 text-sm font-semibold text-white transition-colors hover:bg-emerald-700"
        />
      )}
      <BackdatedEntryButton appliance={appliance} phase={2} />
    </div>
  );
}
