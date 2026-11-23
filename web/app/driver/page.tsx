import { formatPrice } from "@/lib/currency";
import { createClient } from "@/lib/supabase/server";
import { getMyDriverProfile } from "@/lib/driver";
import { toggleOnline } from "./actions";
import { getT } from "@/lib/i18n/server";
import RealtimeRefresher from "@/components/RealtimeRefresher";

function startOfMonth(year: number, month: number): Date {
  return new Date(Date.UTC(year, month, 1));
}

export default async function DriverOverviewPage({
  searchParams,
}: {
  searchParams: { month?: string };
}) {
  const driver = await getMyDriverProfile();
  if (!driver) return null;

  const t = getT();
  const supabase = createClient();

  const now = new Date();
  const [year, month] = searchParams.month
    ? searchParams.month.split("-").map(Number)
    : [now.getFullYear(), now.getMonth()];

  const startOfToday = new Date();
  startOfToday.setHours(0, 0, 0, 0);

  const monthStart = startOfMonth(year, month);
  const monthEnd = startOfMonth(month === 11 ? year + 1 : year, month === 11 ? 0 : month + 1);

  const isCurrentMonth = year === now.getFullYear() && month === now.getMonth();

  const [{ count: activeCount }, { data: todayDeliveries }, { data: monthDeliveries }] =
    await Promise.all([
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
      supabase
        .from("orders")
        .select("id, delivery_fee_cents")
        .eq("driver_id", driver.id)
        .eq("status", "delivered")
        .gte("delivered_at", monthStart.toISOString())
        .lt("delivered_at", monthEnd.toISOString()),
    ]);

  const deliveredToday = todayDeliveries?.length ?? 0;
  const earningsToday = (todayDeliveries ?? []).reduce((sum, o) => sum + o.delivery_fee_cents, 0);
  const deliveredMonth = monthDeliveries?.length ?? 0;
  const earningsMonth = (monthDeliveries ?? []).reduce((sum, o) => sum + o.delivery_fee_cents, 0);

  const monthLabel = new Date(year, month).toLocaleString("en", { month: "long", year: "numeric" });

  // Build prev/next month links
  const prevMonth = month === 0 ? `${year - 1}-11` : `${year}-${String(month - 1).padStart(2, "0")}`;
  const nextMonth = month === 11 ? `${year + 1}-0` : `${year}-${String(month + 1).padStart(2, "0")}`;

  return (
    <div>
      <RealtimeRefresher table="orders" filter={`driver_id=eq.${driver.id}`} />
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

      {/* Today stats */}
      <p className="mt-6 text-xs font-semibold uppercase tracking-wide text-slate-400">{t("Today")}</p>
      <div className="mt-2 grid grid-cols-1 gap-4 sm:grid-cols-3">
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

      {/* Monthly stats */}
      <div className="mt-6 flex items-center gap-3">
        <a href={`?month=${prevMonth}`} className="rounded-lg bg-white px-2 py-1 text-sm font-semibold text-slate-600 shadow-sm ring-1 ring-slate-200 hover:bg-slate-50">‹</a>
        <p className="text-xs font-semibold uppercase tracking-wide text-slate-400">{monthLabel}</p>
        {!isCurrentMonth && (
          <a href={`?month=${nextMonth}`} className="rounded-lg bg-white px-2 py-1 text-sm font-semibold text-slate-600 shadow-sm ring-1 ring-slate-200 hover:bg-slate-50">›</a>
        )}
      </div>
      <div className="mt-2 grid grid-cols-1 gap-4 sm:grid-cols-2">
        <div className="rounded-2xl bg-white p-5 shadow-sm ring-1 ring-slate-200">
          <p className="text-sm text-slate-500">{t("Deliveries this month")}</p>
          <p className="mt-2 text-2xl font-bold text-slate-900">{deliveredMonth}</p>
        </div>
        <div className="rounded-2xl bg-white p-5 shadow-sm ring-1 ring-slate-200">
          <p className="text-sm text-slate-500">{t("Earnings this month")}</p>
          <p className="mt-2 text-2xl font-bold text-slate-900">{formatPrice(earningsMonth)}</p>
        </div>
      </div>
    </div>
  );
}
