export type ActivityEvent = {
  householdId: string;
  type: "usage" | "nudge";
  appliance: string;
  detail: string;
  createdAt: string;
};

export type OverviewStats = {
  totalHouseholds: number;
  consentedHouseholds: number;
  ineligibleHouseholds: number;
  totalUsageLogs: number;
  totalNudgeResponses: number;
  acceptCount: number;
  declineCount: number;
};

function StatCard({ label, value }: { label: string; value: number | string }) {
  return (
    <div className="rounded-xl bg-white p-4 ring-1 ring-neutral-200">
      <p className="text-2xl font-bold text-neutral-800">{value}</p>
      <p className="text-xs text-neutral-500">{label}</p>
    </div>
  );
}

export default function AdminOverview({
  stats,
  recentActivity,
}: {
  stats: OverviewStats;
  recentActivity: ActivityEvent[];
}) {
  return (
    <div className="flex flex-col gap-4">
      <div className="grid grid-cols-2 gap-3 sm:grid-cols-3">
        <StatCard label="Households (consented / total)" value={`${stats.consentedHouseholds} / ${stats.totalHouseholds}`} />
        <StatCard label="Ineligible (screened out)" value={stats.ineligibleHouseholds} />
        <StatCard label="Usage logs (Stage 1 + backdated)" value={stats.totalUsageLogs} />
        <StatCard label="Nudge responses (Stage 2)" value={stats.totalNudgeResponses} />
        <StatCard label="Accepted" value={stats.acceptCount} />
        <StatCard label="Declined" value={stats.declineCount} />
      </div>

      <div className="overflow-x-auto rounded-xl ring-1 ring-neutral-200">
        <table className="min-w-full divide-y divide-neutral-200 text-sm">
          <thead className="bg-neutral-50">
            <tr>
              <th className="px-3 py-2 text-left font-semibold text-neutral-600">Household</th>
              <th className="px-3 py-2 text-left font-semibold text-neutral-600">Type</th>
              <th className="px-3 py-2 text-left font-semibold text-neutral-600">Appliance</th>
              <th className="px-3 py-2 text-left font-semibold text-neutral-600">Detail</th>
              <th className="px-3 py-2 text-left font-semibold text-neutral-600">When</th>
            </tr>
          </thead>
          <tbody className="divide-y divide-neutral-100">
            {recentActivity.length === 0 && (
              <tr>
                <td colSpan={5} className="px-3 py-4 text-center text-neutral-400">
                  No activity yet.
                </td>
              </tr>
            )}
            {recentActivity.map((event, i) => (
              <tr key={i}>
                <td className="px-3 py-2 font-medium text-neutral-800">{event.householdId}</td>
                <td className="px-3 py-2 text-neutral-600">
                  {event.type === "usage" ? "Logged usage" : "Nudge response"}
                </td>
                <td className="px-3 py-2 text-neutral-600">{event.appliance}</td>
                <td className="px-3 py-2 text-neutral-600">{event.detail}</td>
                <td className="px-3 py-2 text-neutral-500">
                  {new Date(event.createdAt).toLocaleString()}
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
    </div>
  );
}
