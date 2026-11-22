import { createClient } from "@/lib/supabase/server";
import { setDriverApproval } from "@/app/admin/actions";
import type { DriverProfile } from "@/lib/types";
import { getT } from "@/lib/i18n/server";
import type { TFn } from "@/lib/i18n/core";

async function getDrivers(): Promise<DriverProfile[]> {
  const supabase = createClient();
  const { data } = await supabase
    .from("driver_profiles")
    .select("*, profiles(full_name, phone)")
    .order("id", { ascending: false });
  return (data as unknown as DriverProfile[]) ?? [];
}

const VEHICLE_TEXT: Record<string, string> = { bike: "Bike", scooter: "Scooter", car: "Car" };

function Badge({ approved, t }: { approved: boolean; t: TFn }) {
  return (
    <span
      className={`rounded-full px-2 py-0.5 text-xs font-semibold ${
        approved ? "bg-green-100 text-green-700" : "bg-amber-100 text-amber-700"
      }`}
    >
      {approved ? t("Approved") : t("Pending")}
    </span>
  );
}

export default async function AdminDriversPage() {
  const t = getT();
  const drivers = await getDrivers();

  return (
    <div>
      <h1 className="text-xl font-bold text-slate-900">{t("Drivers")}</h1>
      <p className="mt-1 text-sm text-slate-500">
        {t("Approve new driver signups before they can go online.")}
      </p>

      <div className="mt-6 overflow-hidden rounded-2xl bg-white shadow-sm ring-1 ring-slate-200">
        <table className="w-full text-left text-sm">
          <thead className="border-b border-slate-200 bg-slate-50 text-slate-500">
            <tr>
              <th className="px-4 py-3 font-medium">{t("Name")}</th>
              <th className="px-4 py-3 font-medium">{t("Phone")}</th>
              <th className="px-4 py-3 font-medium">{t("Vehicle")}</th>
              <th className="px-4 py-3 font-medium">{t("Online")}</th>
              <th className="px-4 py-3 font-medium">{t("Status")}</th>
              <th className="px-4 py-3 font-medium">{t("Action")}</th>
            </tr>
          </thead>
          <tbody>
            {drivers.map((d) => (
              <tr key={d.id} className="border-b border-slate-100 last:border-0">
                <td className="px-4 py-3 font-medium text-slate-900">
                  {d.profiles?.full_name ?? "—"}
                </td>
                <td className="px-4 py-3 text-slate-600">{d.profiles?.phone ?? "—"}</td>
                <td className="px-4 py-3 text-slate-600">{d.vehicle_type ? t(VEHICLE_TEXT[d.vehicle_type] ?? d.vehicle_type) : "—"}</td>
                <td className="px-4 py-3 text-slate-600">{d.is_online ? t("Online") : t("Offline")}</td>
                <td className="px-4 py-3">
                  <Badge approved={d.is_approved} t={t} />
                </td>
                <td className="px-4 py-3">
                  <form action={setDriverApproval.bind(null, d.id, !d.is_approved)}>
                    <button
                      type="submit"
                      className={`rounded-lg px-3 py-1.5 text-xs font-semibold ${
                        d.is_approved
                          ? "bg-red-50 text-red-700 hover:bg-red-100"
                          : "bg-brand-600 text-white hover:bg-brand-700"
                      }`}
                    >
                      {d.is_approved ? t("Suspend") : t("Approve")}
                    </button>
                  </form>
                </td>
              </tr>
            ))}
            {drivers.length === 0 && (
              <tr>
                <td colSpan={6} className="px-4 py-8 text-center text-slate-400">
                  {t("No drivers yet.")}
                </td>
              </tr>
            )}
          </tbody>
        </table>
      </div>
    </div>
  );
}
