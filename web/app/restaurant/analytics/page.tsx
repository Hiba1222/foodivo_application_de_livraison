import { formatPrice } from "@/lib/currency";
import { createClient } from "@/lib/supabase/server";
import { getMyRestaurant } from "@/lib/restaurant";
import RealtimeRefresher from "@/components/RealtimeRefresher";
import { getT } from "@/lib/i18n/server";

export default async function RestaurantAnalyticsPage() {
  const t = getT();
  const restaurant = await getMyRestaurant();
  if (!restaurant) return null;

  const supabase = createClient();
  const now = new Date();
  const thirtyDaysAgo = new Date(now);
  thirtyDaysAgo.setDate(thirtyDaysAgo.getDate() - 30);

  const [{ data: deliveredOrders }, { data: orderItems }, { data: reviewRows }] =
    await Promise.all([
      supabase
        .from("orders")
        .select("id, subtotal_cents, created_at")
        .eq("restaurant_id", restaurant.id)
        .eq("status", "delivered")
        .gte("created_at", thirtyDaysAgo.toISOString())
        .order("created_at"),
      supabase
        .from("order_items")
        .select("quantity, menu_items(name)")
        .in(
          "order_id",
          // We'll get all delivered order ids from the last 30 days
          (
            await supabase
              .from("orders")
              .select("id")
              .eq("restaurant_id", restaurant.id)
              .eq("status", "delivered")
              .gte("created_at", thirtyDaysAgo.toISOString())
          ).data?.map((o) => o.id) ?? []
        ),
      supabase
        .from("reviews")
        .select("restaurant_rating")
        .in(
          "order_id",
          (
            await supabase
              .from("orders")
              .select("id")
              .eq("restaurant_id", restaurant.id)
          ).data?.map((o) => o.id) ?? []
        ),
    ]);

  // Revenue by day (last 30 days)
  const revenueByDay: Record<string, number> = {};
  for (let i = 29; i >= 0; i--) {
    const d = new Date(now);
    d.setDate(d.getDate() - i);
    revenueByDay[d.toISOString().slice(0, 10)] = 0;
  }
  for (const o of deliveredOrders ?? []) {
    const day = o.created_at.slice(0, 10);
    if (day in revenueByDay) revenueByDay[day] = (revenueByDay[day] ?? 0) + o.subtotal_cents;
  }

  const days = Object.entries(revenueByDay);
  const maxRevenue = Math.max(...days.map(([, v]) => v), 1);
  const totalRevenue = (deliveredOrders ?? []).reduce((s, o) => s + o.subtotal_cents, 0);
  const totalOrders = deliveredOrders?.length ?? 0;

  // Top items
  const itemTotals: Record<string, number> = {};
  for (const oi of orderItems ?? []) {
    const name = (oi.menu_items as any)?.name ?? "Unknown";
    itemTotals[name] = (itemTotals[name] ?? 0) + oi.quantity;
  }
  const topItems = Object.entries(itemTotals)
    .sort((a, b) => b[1] - a[1])
    .slice(0, 8);
  const maxQty = Math.max(...topItems.map(([, v]) => v), 1);

  // Average rating
  const ratings = (reviewRows ?? []).map((r) => r.restaurant_rating).filter(Boolean) as number[];
  const avgRating = ratings.length > 0 ? ratings.reduce((s, r) => s + r, 0) / ratings.length : null;

  return (
    <div>
      <RealtimeRefresher table="orders" filter={`restaurant_id=eq.${restaurant.id}`} />
      <h1 className="text-xl font-bold text-slate-900">{t("Analytics")}</h1>
      <p className="mt-1 text-sm text-slate-500">{t("Last 30 days")}</p>

      {/* Summary cards */}
      <div className="mt-6 grid grid-cols-1 gap-4 sm:grid-cols-3">
        <div className="rounded-2xl bg-white p-5 shadow-sm ring-1 ring-slate-200">
          <p className="text-sm text-slate-500">{t("Revenue (30 days)")}</p>
          <p className="mt-2 text-2xl font-bold text-slate-900">{formatPrice(totalRevenue)}</p>
        </div>
        <div className="rounded-2xl bg-white p-5 shadow-sm ring-1 ring-slate-200">
          <p className="text-sm text-slate-500">{t("Orders delivered (30 days)")}</p>
          <p className="mt-2 text-2xl font-bold text-slate-900">{totalOrders}</p>
        </div>
        <div className="rounded-2xl bg-white p-5 shadow-sm ring-1 ring-slate-200">
          <p className="text-sm text-slate-500">{t("Average rating")}</p>
          <p className="mt-2 text-2xl font-bold text-slate-900">
            {avgRating ? `${"⭐".repeat(Math.round(avgRating))} ${avgRating.toFixed(1)}` : t("No reviews yet")}
          </p>
        </div>
      </div>

      {/* Revenue chart */}
      <div className="mt-6 rounded-2xl bg-white p-5 shadow-sm ring-1 ring-slate-200">
        <h2 className="mb-4 text-sm font-semibold text-slate-900">{t("Daily revenue")}</h2>
        <div className="flex h-40 items-end gap-px overflow-hidden">
          {days.map(([day, revenue]) => {
            const height = maxRevenue === 0 ? 0 : Math.round((revenue / maxRevenue) * 100);
            const shortDay = new Date(day + "T12:00:00Z").toLocaleDateString("en", { day: "numeric", month: "short" });
            return (
              <div
                key={day}
                className="group relative flex flex-1 flex-col items-center justify-end"
                title={`${shortDay}: ${formatPrice(revenue)}`}
              >
                <div
                  className="w-full rounded-t bg-brand-500 transition-all group-hover:bg-brand-600"
                  style={{ height: `${height}%`, minHeight: revenue > 0 ? "2px" : "0" }}
                />
              </div>
            );
          })}
        </div>
        <div className="mt-2 flex justify-between text-xs text-slate-400">
          <span>{days[0]?.[0]?.slice(5)}</span>
          <span>{days[Math.floor(days.length / 2)]?.[0]?.slice(5)}</span>
          <span>{days[days.length - 1]?.[0]?.slice(5)}</span>
        </div>
      </div>

      {/* Top items */}
      {topItems.length > 0 && (
        <div className="mt-6 rounded-2xl bg-white p-5 shadow-sm ring-1 ring-slate-200">
          <h2 className="mb-4 text-sm font-semibold text-slate-900">{t("Top-selling items")}</h2>
          <ul className="space-y-3">
            {topItems.map(([name, qty]) => (
              <li key={name} className="flex items-center gap-3">
                <span className="w-36 truncate text-sm text-slate-700">{name}</span>
                <div className="flex-1 overflow-hidden rounded-full bg-slate-100">
                  <div
                    className="h-2 rounded-full bg-brand-500"
                    style={{ width: `${Math.round((qty / maxQty) * 100)}%` }}
                  />
                </div>
                <span className="w-8 text-right text-xs font-semibold text-slate-500">{qty}</span>
              </li>
            ))}
          </ul>
        </div>
      )}
    </div>
  );
}
