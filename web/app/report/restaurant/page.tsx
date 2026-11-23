import { createClient } from "@/lib/supabase/server";
import { getMyRestaurant } from "@/lib/restaurant";
import { formatPrice } from "@/lib/currency";
import { redirect } from "next/navigation";
import ReportActions from "./ReportActions";

const PLATFORM_FEE_RATE = 0.1;

function periodLabel(p: string) {
  if (p === "all") return "All time";
  return `Last ${p} days`;
}

export default async function RestaurantReportPage({
  searchParams,
}: {
  searchParams: { period?: string };
}) {
  const supabase = createClient();
  const restaurant = await getMyRestaurant();
  if (!restaurant) redirect("/restaurant");

  const period = searchParams.period ?? "30";
  const days = period === "all" ? null : Number(period) || 30;
  const since = days
    ? (() => { const d = new Date(); d.setDate(d.getDate() - days); return d.toISOString(); })()
    : null;

  let query = supabase
    .from("orders")
    .select("id, subtotal_cents, delivered_at, profiles!orders_client_id_fkey(full_name)")
    .eq("restaurant_id", restaurant.id)
    .eq("status", "delivered")
    .order("delivered_at", { ascending: false });

  if (since) query = query.gte("created_at", since);
  const { data: orders } = await query;

  const rows = (orders ?? []).map((o) => ({
    ...o,
    fee: Math.round(o.subtotal_cents * PLATFORM_FEE_RATE),
    net: Math.round(o.subtotal_cents * (1 - PLATFORM_FEE_RATE)),
  }));

  const totals = rows.reduce(
    (acc, o) => ({ gross: acc.gross + o.subtotal_cents, fee: acc.fee + o.fee, net: acc.net + o.net }),
    { gross: 0, fee: 0, net: 0 }
  );

  const generatedDate = new Date().toLocaleDateString("en-GB", {
    year: "numeric", month: "long", day: "numeric",
  });

  return (
    <div className="min-h-screen bg-white">
      <div className="print:hidden sticky top-0 z-10 flex items-center justify-between border-b border-slate-100 bg-white px-6 py-3 shadow-sm">
        <a href="/restaurant/payouts" className="text-sm text-slate-500 hover:text-slate-700">
          ← Back to Payouts
        </a>
        <ReportActions restaurantId={restaurant.id} period={period} />
      </div>

      <div className="mx-auto max-w-3xl px-8 py-10 print:py-6">
        {/* Header */}
        <div className="flex items-start justify-between border-b-2 border-slate-200 pb-6">
          <div>
            <p className="text-2xl font-black text-brand-600">Foodivo</p>
            <p className="mt-1 text-lg font-semibold text-slate-900">{restaurant.name}</p>
            <p className="text-xs text-slate-400">Payout report · {periodLabel(period)}</p>
          </div>
          <div className="text-right text-sm text-slate-500">
            <p>Generated: {generatedDate}</p>
            <p className="mt-0.5 text-xs text-slate-400">Platform fee: 10% of food subtotal</p>
          </div>
        </div>

        {/* Summary */}
        <div className="mt-6 grid grid-cols-3 gap-4">
          {[
            { label: "Net payout", value: formatPrice(totals.net), primary: true },
            { label: "Gross revenue", value: formatPrice(totals.gross), primary: false },
            { label: "Platform fees", value: formatPrice(totals.fee), primary: false },
          ].map((c) => (
            <div
              key={c.label}
              className={`rounded-xl p-4 ${c.primary ? "bg-brand-50 ring-1 ring-brand-200" : "bg-slate-50 ring-1 ring-slate-100"}`}
            >
              <p className={`text-xs font-medium ${c.primary ? "text-brand-600" : "text-slate-500"}`}>{c.label}</p>
              <p className={`mt-1 text-xl font-bold ${c.primary ? "text-brand-800" : "text-slate-900"}`}>{c.value}</p>
            </div>
          ))}
        </div>

        {/* Table */}
        <div className="mt-8">
          <table className="w-full text-sm">
            <thead>
              <tr className="border-b-2 border-slate-200 text-xs uppercase tracking-wide text-slate-400">
                <th className="pb-2 text-left">Date</th>
                <th className="pb-2 text-left">Client</th>
                <th className="pb-2 text-right">Subtotal</th>
                <th className="pb-2 text-right">Platform fee</th>
                <th className="pb-2 text-right">Your payout</th>
              </tr>
            </thead>
            <tbody>
              {rows.map((o, i) => (
                <tr key={o.id} className={i % 2 === 0 ? "bg-white" : "bg-slate-50"}>
                  <td className="py-2 text-slate-500">
                    {o.delivered_at ? new Date(o.delivered_at).toLocaleDateString("en-GB") : "—"}
                  </td>
                  <td className="py-2 font-medium text-slate-900">
                    {(o.profiles as any)?.full_name ?? "—"}
                  </td>
                  <td className="py-2 text-right text-slate-500">{formatPrice(o.subtotal_cents)}</td>
                  <td className="py-2 text-right text-red-500">−{formatPrice(o.fee)}</td>
                  <td className="py-2 text-right font-semibold text-brand-700">{formatPrice(o.net)}</td>
                </tr>
              ))}
              {rows.length === 0 && (
                <tr>
                  <td colSpan={5} className="py-8 text-center text-slate-400">
                    No delivered orders in this period.
                  </td>
                </tr>
              )}
            </tbody>
            {rows.length > 0 && (
              <tfoot>
                <tr className="border-t-2 border-slate-200 font-bold text-slate-900">
                  <td colSpan={2} className="pt-3">Total</td>
                  <td className="pt-3 text-right text-slate-500">{formatPrice(totals.gross)}</td>
                  <td className="pt-3 text-right text-red-500">−{formatPrice(totals.fee)}</td>
                  <td className="pt-3 text-right text-brand-700">{formatPrice(totals.net)}</td>
                </tr>
              </tfoot>
            )}
          </table>
        </div>

        <div className="mt-10 border-t border-slate-100 pt-4 text-center text-xs text-slate-400">
          Foodivo · Payout report generated {generatedDate}
        </div>
      </div>
    </div>
  );
}
