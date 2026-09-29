"use client";

import { useState } from "react";
import { useRouter } from "next/navigation";

export default function AdminResetPanel() {
  const router = useRouter();
  const [count, setCount] = useState(500);
  const [confirmText, setConfirmText] = useState("");
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);

  async function handleReset() {
    setBusy(true);
    setError(null);

    const res = await fetch("/api/admin/reset-and-seed", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ count, confirmText }),
    });

    if (!res.ok) {
      setBusy(false);
      const body = await res.json().catch(() => ({}));
      setError(body.error === "invalid_request" ? 'Type "RESET" exactly to confirm.' : "Something went wrong.");
      return;
    }

    const blob = await res.blob();
    const url = URL.createObjectURL(blob);
    const a = document.createElement("a");
    a.href = url;
    a.download = "households-credentials.csv";
    a.click();
    URL.revokeObjectURL(url);

    setBusy(false);
    setConfirmText("");
    router.refresh();
  }

  return (
    <div className="rounded-xl border-2 border-dashed border-red-300 bg-red-50 p-4">
      <p className="text-sm font-semibold text-red-800">Danger zone: wipe &amp; reseed</p>
      <p className="mt-1 text-xs text-red-700">
        Permanently deletes all households, profiles, usage logs, and nudge responses, then
        creates a fresh set of households (plus the 000/TEST debug account) and downloads
        their credentials as a CSV. This cannot be undone.
      </p>
      <div className="mt-3 flex flex-wrap items-center gap-2">
        <label className="text-xs font-medium text-red-800">
          Count
          <input
            type="number"
            min={1}
            max={2000}
            value={count}
            onChange={(e) => setCount(Number(e.target.value))}
            className="ml-2 w-24 rounded-lg border border-red-300 px-2 py-1.5 text-sm"
          />
        </label>
        <label className="text-xs font-medium text-red-800">
          Type RESET to confirm
          <input
            type="text"
            value={confirmText}
            onChange={(e) => setConfirmText(e.target.value)}
            placeholder="RESET"
            className="ml-2 w-28 rounded-lg border border-red-300 px-2 py-1.5 text-sm"
          />
        </label>
        <button
          type="button"
          onClick={handleReset}
          disabled={busy || confirmText !== "RESET"}
          className="rounded-lg bg-red-600 px-3 py-2 text-xs font-semibold text-white hover:bg-red-700 disabled:cursor-not-allowed disabled:opacity-50"
        >
          {busy ? "Wiping & seeding…" : "Wipe & reseed"}
        </button>
      </div>
      {error && <p className="mt-2 text-xs text-red-700">{error}</p>}
    </div>
  );
}
