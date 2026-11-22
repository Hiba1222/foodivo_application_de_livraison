import { formatPrice } from "@/lib/currency";
import { createClient } from "@/lib/supabase/server";
import { getMyDriverProfile } from "@/lib/driver";
import { toggleOnline } from "./actions";
import { getT } from "@/lib/i18n/server";

export default async function DriverOverviewPage() {
  const driver = await getMyDriverProfile();
  if (!driver) return null;

  const t = getT();
  const supabase = createClient();
  const startOfToday = new Date();
  startOfToday.setHours(0, 0, 0, 0);

  const [{ count: activeCount }, { data: todayDeliveries }] = await Promise.all([
    supabase
      .from("orders")
      .select("*", { count: "exact", head: true })
      .eq("driver_id", driver.id)
      .in("status", ["driver_assigned", "picked_up"]),
    supabase
      .from("orders")
      .select("id, delivery_fee_cents")
      .eq("driver_id", driver.id)
      .eq("status", "delivered")
      .gte("delivered_at", startOfToday.toISOString()),
  ]);

  const deliveredToday = todayDeliveries?.length ?? 0;
  const earningsToday =
    (todayDeliveries ?? []).reduce((sum, o) => sum + o.delivery_fee_cents, 0);

  return (
    <div>
      <div className="flex items-center justify-between">
        <h1 className="text-xl font-bold text-slate-900">{t("Driver dashboard")}</h1>
        <form action={toggleOnline.bind(null, !driver.is_online)}>
          <button
            type="submit"
            disabled={!driver.is_approved}
            className={`rounded-lg px-4 py-2 text-sm font-semibold disabled:cursor-not-allowed disabled:opacity-50 ${
              driver.is_online
                ? "bg-green-100 text-green-700 hover:bg-green-200"
                : "bg-slate-200 text-slate-600 hover:bg-slate-300"
            }`}
          >
            {driver.is_online ? t("Online — tap to go offline") : t("Offline — tap to go online")}
          </button>
        </form>
      </div>

      <div className="mt-6 grid grid-cols-1 gap-4 sm:grid-cols-3">
        <div className="rounded-2xl bg-white p-5 shadow-sm ring-1 ring-slate-200">
          <p className="text-sm text-slate-500">{t("Active delivery")}</p>
          <p className="mt-2 text-2xl font-bold text-slate-900">{activeCount ?? 0}</p>
        </div>
        <div className="rounded-2xl bg-white p-5 shadow-sm ring-1 ring-slate-200">
          <p className="text-sm text-slate-500">{t("Delivered today")}</p>
          <p className="mt-2 text-2xl font-bold text-slate-900">{deliveredToday}</p>
        </div>
        <div className="rounded-2xl bg-white p-5 shadow-sm ring-1 ring-slate-200">
          <p className="text-sm text-slate-500">{t("Earnings today")}</p>
          <p className="mt-2 text-2xl font-bold text-slate-900">{formatPrice(earningsToday)}</p>
        </div>
      </div>
    </div>
  );
}
