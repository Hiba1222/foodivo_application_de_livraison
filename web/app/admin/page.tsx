import { formatPrice } from "@/lib/currency";
import { createClient } from "@/lib/supabase/server";
import RealtimeRefresher from "@/components/RealtimeRefresher";
import { getT } from "@/lib/i18n/server";

async function getStats() {
  const supabase = createClient();

  const [
    { count: totalOrders },
    { count: pendingApprovalRestaurants },
    { count: pendingApprovalDrivers },
    { count: activeOrders },
    { data: revenueRows },
  ] = await Promise.all([
    supabase.from("orders").select("*", { count: "exact", head: true }),
    supabase
      .from("restaurants")
      .select("*", { count: "exact", head: true })
      .eq("is_approved", false),
    supabase
      .from("driver_profiles")
      .select("*", { count: "exact", head: true })
      .eq("is_approved", false),
    supabase
      .from("orders")
      .select("*", { count: "exact", head: true })
      .in("status", ["pending", "accepted", "ready_for_pickup", "driver_assigned", "picked_up"]),
    supabase.from("orders").select("total_cents").eq("payment_status", "paid"),
  ]);

  const totalRevenueCents = (revenueRows ?? []).reduce(
    (sum, row) => sum + row.total_cents,
    0
  );

  return {
    totalOrders: totalOrders ?? 0,
    pendingApprovalRestaurants: pendingApprovalRestaurants ?? 0,
    pendingApprovalDrivers: pendingApprovalDrivers ?? 0,
    activeOrders: activeOrders ?? 0,
    totalRevenueCents,
  };
}

function StatCard({ label, value, href }: { label: string; value: string; href?: string }) {
  const card = (
    <div className="rounded-2xl bg-white p-5 shadow-sm ring-1 ring-slate-200">
      <p className="text-sm text-slate-500">{label}</p>
      <p className="mt-2 text-2xl font-bold text-slate-900">{value}</p>
    </div>
  );
  return href ? <a href={href}>{card}</a> : card;
}

export default async function AdminOverviewPage() {
  const t = getT();
  const stats = await getStats();

  return (
    <div>
      <RealtimeRefresher table="orders" />
      <h1 className="text-xl font-bold text-slate-900">{t("Platform overview")}</h1>
      <p className="mt-1 text-sm text-slate-500">
        {t("Live snapshot across all restaurants, drivers, and orders.")}
      </p>

      <div className="mt-6 grid grid-cols-1 gap-4 sm:grid-cols-2 lg:grid-cols-4">
        <StatCard label={t("Total orders")} value={String(stats.totalOrders)} href="/admin/orders" />
        <StatCard label={t("Active orders")} value={String(stats.activeOrders)} href="/admin/orders" />
        <StatCard
          label={t("Restaurants pending approval")}
          value={String(stats.pendingApprovalRestaurants)}
          href="/admin/restaurants"
        />
        <StatCard
          label={t("Drivers pending approval")}
          value={String(stats.pendingApprovalDrivers)}
          href="/admin/drivers"
        />
      </div>

      <div className="mt-4">
        <StatCard
          label={t("Total revenue (paid orders)")}
          value={formatPrice(stats.totalRevenueCents)}
        />
      </div>
    </div>
  );
}
