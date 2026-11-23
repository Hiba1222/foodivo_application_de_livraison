import { formatPrice } from "@/lib/currency";
import { createClient } from "@/lib/supabase/server";
import RealtimeRefresher from "@/components/RealtimeRefresher";
import { getT } from "@/lib/i18n/server";

const PLATFORM_FEE_RATE = 0.1;

export default async function AdminFeesPage({
  searchParams,
}: {
  searchParams: { period?: string };
}) {
  const t = getT();
  const supabase = createClient();

  const period = searchParams.period ?? "30";
  const days = Number(period) || 30;
  const since = new Date();
  since.setDate(since.getDate() - days);

  const { data: orders } = await supabase
    .from("orders")
    .select("id, total_cents, subtotal_cents, delivery_fee_cents, created_at, restaurants(name)")
    .eq("payment_status", "paid")
    .gte("created_at", since.toISOString())
    .order("created_at", { ascending: false });

  const rows = orders ?? [];

  // Per-order fee breakdown
  const enriched = rows.map((o) => {
    const feeRestaurant = Math.round(o.subtotal_cents * PLATFORM_FEE_RATE);
    const feeDriver = Math.round(o.delivery_fee_cents * PLATFORM_FEE_RATE);
    return { ...o, feeRestaurant, feeDriver, feeTotal: feeRestaurant + feeDriver };
  });

  const totals = enriched.reduce(
    (acc, o) => ({
      revenue: acc.revenue + o.total_cents,
      feeRestaurant: acc.feeRestaurant + o.feeRestaurant,
      feeDriver: acc.feeDriver + o.feeDriver,
      feeTotal: acc.feeTotal + o.feeRestaurant + o.feeDriver,
    }),
    { revenue: 0, feeRestaurant: 0, feeDriver: 0, feeTotal: 0 }
  );

  // Revenue by day
  const revenueByDay: Record<string, { orders: number; fees: number }> = {};
  for (let i = days - 1; i >= 0; i--) {
    const d = new Date();
    d.setDate(d.getDate() - i);
    revenueByDay[d.toISOString().slice(0, 10)] = { orders: 0, fees: 0 };
  }
  for (const o of enriched) {
    const day = o.created_at.slice(0, 10);
    if (day in revenueByDay) {
      revenueByDay[day].orders += 1;
      revenueByDay[day].fees += o.feeTotal;
    }
  }
  const dayEntries = Object.entries(revenueByDay);
  const maxFees = Math.max(...dayEntries.map(([, v]) => v.fees), 1);

  return (
    <div>
      <RealtimeRefresher table="orders" />

      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-xl font-bold text-slate-900">{t("Platform fees")}</h1>
          <p className="mt-1 text-sm text-slate-500">{t("10% on food subtotal + 10% on delivery fee")}</p>
        </div>
        <div className="flex gap-2">
          {["7", "30", "90"].map((p) => (
            <a
              key={p}
              href={`/admin/fees?period=${p}`}
              className={`rounded-lg px-3 py-1.5 text-sm font-medium ${
                period === p
                  ? "bg-brand-600 text-white"
                  : "bg-white text-slate-600 ring-1 ring-slate-200 hover:bg-slate-50"
              }`}
            >
              {p}{t("d")}
            </a>
          ))}
        </div>
      </div>

      {/* Summary */}
      <div className="mt-6 grid grid-cols-1 gap-4 sm:grid-cols-2 lg:grid-cols-4">
        <div className="rounded-2xl bg-brand-50 p-5 ring-1 ring-brand-200">
          <p className="text-sm text-brand-600">{t("Total platform fees")}</p>
          <p className="mt-2 text-2xl font-bold text-brand-800">{formatPrice(totals.feeTotal)}</p>
        </div>
        <div className="rounded-2xl bg-white p-5 shadow-sm ring-1 ring-slate-200">
          <p className="text-sm text-slate-500">{t("From restaurants")}</p>
          <p className="mt-2 text-2xl font-bold text-slate-900">{formatPrice(totals.feeRestaurant)}</p>
        </div>
        <div className="rounded-2xl bg-white p-5 shadow-sm ring-1 ring-slate-200">
          <p className="text-sm text-slate-500">{t("From drivers")}</p>
          <p className="mt-2 text-2xl font-bold text-slate-900">{formatPrice(totals.feeDriver)}</p>
        </div>
        <div className="rounded-2xl bg-white p-5 shadow-sm ring-1 ring-slate-200">
          <p className="text-sm text-slate-500">{t("Total revenue (paid)")}</p>
          <p className="mt-2 text-2xl font-bold text-slate-900">{formatPrice(totals.revenue)}</p>
        </div>
      </div>

      {/* Fee chart */}
      <div className="mt-6 rounded-2xl bg-white p-5 shadow-sm ring-1 ring-slate-200">
        <h2 className="mb-4 text-sm font-semibold text-slate-900">{t("Daily fees")}</h2>
        <div className="flex h-32 items-end gap-px overflow-hidden">
          {dayEntries.map(([day, { fees }]) => {
            const height = maxFees === 0 ? 0 : Math.round((fees / maxFees) * 100);
            return (
              <div
                key={day}
                className="group relative flex flex-1 flex-col items-center justify-end"
                title={`${day.slice(5)}: ${formatPrice(fees)}`}
              >
                <div
                  className="w-full rounded-t bg-brand-500 transition-all group-hover:bg-brand-700"
                  style={{ height: `${height}%`, minHeight: fees > 0 ? "2px" : "0" }}
                />
              </div>
            );
          })}
        </div>
        <div className="mt-2 flex justify-between text-xs text-slate-400">
          <span>{dayEntries[0]?.[0]?.slice(5)}</span>
          <span>{dayEntries[Math.floor(dayEntries.length / 2)]?.[0]?.slice(5)}</span>
          <span>{dayEntries[dayEntries.length - 1]?.[0]?.slice(5)}</span>
        </div>
      </div>

      {/* Order table */}
      <div className="mt-6 overflow-hidden rounded-2xl bg-white shadow-sm ring-1 ring-slate-200">
        <div className="border-b border-slate-100 px-5 py-3">
          <h2 className="text-sm font-semibold text-slate-900">
            {t("{n} paid orders", { n: String(enriched.length) })}
          </h2>
        </div>
        <div className="overflow-x-auto">
          <table className="min-w-full text-sm">
            <thead className="bg-slate-50 text-xs text-slate-500">
              <tr>
                <th className="px-5 py-2 text-left">{t("Date")}</th>
                <th className="px-5 py-2 text-left">{t("Restaurant")}</th>
                <th className="px-5 py-2 text-right">{t("Order total")}</th>
                <th className="px-5 py-2 text-right">{t("Restaurant fee")}</th>
                <th className="px-5 py-2 text-right">{t("Driver fee")}</th>
                <th className="px-5 py-2 text-right">{t("Platform fee")}</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-slate-100">
              {enriched.slice(0, 100).map((o) => (
                <tr key={o.id} className="hover:bg-slate-50">
                  <td className="px-5 py-2 text-slate-500">{o.created_at.slice(0, 10)}</td>
                  <td className="px-5 py-2 font-medium text-slate-900">
                    {(o.restaurants as any)?.name ?? "—"}
                  </td>
                  <td className="px-5 py-2 text-right">{formatPrice(o.total_cents)}</td>
                  <td className="px-5 py-2 text-right text-slate-500">{formatPrice(o.feeRestaurant)}</td>
                  <td className="px-5 py-2 text-right text-slate-500">{formatPrice(o.feeDriver)}</td>
                  <td className="px-5 py-2 text-right font-semibold text-brand-700">{formatPrice(o.feeTotal)}</td>
                </tr>
              ))}
              {enriched.length === 0 && (
                <tr>
                  <td colSpan={6} className="px-5 py-8 text-center text-slate-400">
                    {t("No paid orders in this period.")}
                  </td>
                </tr>
              )}
            </tbody>
          </table>
        </div>
      </div>
    </div>
  );
}
