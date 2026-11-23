import { formatPrice } from "@/lib/currency";
import { createClient } from "@/lib/supabase/server";
import RealtimeRefresher from "@/components/RealtimeRefresher";
import { getT } from "@/lib/i18n/server";

const PLATFORM_FEE_RATE = 0.1;

export default async function DriverEarningsPage({
  searchParams,
}: {
  searchParams: { period?: string };
}) {
  const t = getT();
  const supabase = createClient();

  const {
    data: { user },
  } = await supabase.auth.getUser();

  const period = searchParams.period ?? "30";
  const days = period === "all" ? null : Number(period) || 30;
  const since = days
    ? (() => { const d = new Date(); d.setDate(d.getDate() - days); return d.toISOString(); })()
    : null;

  let query = supabase
    .from("orders")
    .select("id, delivery_fee_cents, created_at, delivered_at, restaurants(name)")
    .eq("driver_id", user!.id)
    .eq("status", "delivered")
    .order("delivered_at", { ascending: false });

  if (since) query = query.gte("created_at", since);

  const { data: orders } = await query;
  const rows = orders ?? [];

  const enriched = rows.map((o) => ({
    ...o,
    platformCut: Math.round(o.delivery_fee_cents * PLATFORM_FEE_RATE),
    netEarned: Math.round(o.delivery_fee_cents * (1 - PLATFORM_FEE_RATE)),
  }));

  const totals = enriched.reduce(
    (acc, o) => ({
      gross: acc.gross + o.delivery_fee_cents,
      cut: acc.cut + o.platformCut,
      net: acc.net + o.netEarned,
    }),
    { gross: 0, cut: 0, net: 0 }
  );

  const avgEarned = enriched.length > 0 ? Math.round(totals.net / enriched.length) : 0;

  const PERIODS = [
    { label: "7d", value: "7" },
    { label: "30d", value: "30" },
    { label: "90d", value: "90" },
    { label: t("All time"), value: "all" },
  ];

  return (
    <div>
      <RealtimeRefresher table="orders" filter={`driver_id=eq.${user!.id}`} />

      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-xl font-bold text-slate-900">{t("My earnings")}</h1>
          <p className="mt-1 text-sm text-slate-500">{t("You keep 90% of the delivery fee.")}</p>
        </div>
        <div className="flex gap-2">
          {PERIODS.map((p) => (
            <a
              key={p.value}
              href={`/driver/earnings?period=${p.value}`}
              className={`rounded-lg px-3 py-1.5 text-sm font-medium ${
                period === p.value
                  ? "bg-brand-600 text-white"
                  : "bg-white text-slate-600 ring-1 ring-slate-200 hover:bg-slate-50"
              }`}
            >
              {p.label}
            </a>
          ))}
        </div>
      </div>

      {/* Summary cards */}
      <div className="mt-6 grid grid-cols-1 gap-4 sm:grid-cols-2 lg:grid-cols-4">
        <div className="rounded-2xl bg-brand-50 p-5 ring-1 ring-brand-200">
          <p className="text-sm text-brand-600">{t("Net earnings")}</p>
          <p className="mt-2 text-2xl font-bold text-brand-800">{formatPrice(totals.net)}</p>
        </div>
        <div className="rounded-2xl bg-white p-5 shadow-sm ring-1 ring-slate-200">
          <p className="text-sm text-slate-500">{t("Deliveries completed")}</p>
          <p className="mt-2 text-2xl font-bold text-slate-900">{enriched.length}</p>
        </div>
        <div className="rounded-2xl bg-white p-5 shadow-sm ring-1 ring-slate-200">
          <p className="text-sm text-slate-500">{t("Avg per delivery")}</p>
          <p className="mt-2 text-2xl font-bold text-slate-900">{formatPrice(avgEarned)}</p>
        </div>
        <div className="rounded-2xl bg-white p-5 shadow-sm ring-1 ring-slate-200">
          <p className="text-sm text-slate-500">{t("Platform fees paid")}</p>
          <p className="mt-2 text-2xl font-bold text-slate-500">{formatPrice(totals.cut)}</p>
        </div>
      </div>

      {/* Order table */}
      <div className="mt-6 overflow-hidden rounded-2xl bg-white shadow-sm ring-1 ring-slate-200">
        <div className="border-b border-slate-100 px-5 py-3">
          <h2 className="text-sm font-semibold text-slate-900">
            {t("{n} deliveries", { n: String(enriched.length) })}
          </h2>
        </div>
        <div className="overflow-x-auto">
          <table className="min-w-full text-sm">
            <thead className="bg-slate-50 text-xs text-slate-500">
              <tr>
                <th className="px-5 py-2 text-left">{t("Date")}</th>
                <th className="px-5 py-2 text-left">{t("Restaurant")}</th>
                <th className="px-5 py-2 text-right">{t("Delivery fee")}</th>
                <th className="px-5 py-2 text-right">{t("Platform cut (10%)")}</th>
                <th className="px-5 py-2 text-right">{t("You earned")}</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-slate-100">
              {enriched.map((o) => (
                <tr key={o.id} className="hover:bg-slate-50">
                  <td className="px-5 py-2 text-slate-500">
                    {(o.delivered_at ?? o.created_at).slice(0, 10)}
                  </td>
                  <td className="px-5 py-2 font-medium text-slate-900">
                    {(o.restaurants as any)?.name ?? "—"}
                  </td>
                  <td className="px-5 py-2 text-right text-slate-500">{formatPrice(o.delivery_fee_cents)}</td>
                  <td className="px-5 py-2 text-right text-red-500">−{formatPrice(o.platformCut)}</td>
                  <td className="px-5 py-2 text-right font-semibold text-brand-700">{formatPrice(o.netEarned)}</td>
                </tr>
              ))}
              {enriched.length === 0 && (
                <tr>
                  <td colSpan={5} className="px-5 py-8 text-center text-slate-400">
                    {t("No deliveries in this period.")}
                  </td>
                </tr>
              )}
            </tbody>
          </table>
        </div>
        {enriched.length > 0 && (
          <div className="border-t border-slate-100 bg-slate-50 px-5 py-3 text-sm font-semibold flex justify-end gap-8">
            <span className="text-slate-500">{t("Total")}</span>
            <span className="text-red-500">−{formatPrice(totals.cut)}</span>
            <span className="text-brand-700">{formatPrice(totals.net)}</span>
          </div>
        )}
      </div>

      {/* Report download link */}
      <div className="mt-4 flex justify-end">
        <a
          href={`/report/driver?period=${period}`}
          target="_blank"
          rel="noopener noreferrer"
          className="flex items-center gap-2 rounded-xl bg-white px-4 py-2.5 text-sm font-medium text-slate-700 shadow-sm ring-1 ring-slate-200 hover:bg-slate-50"
        >
          📄 {t("Download / Email Report")}
        </a>
      </div>
    </div>
  );
}
