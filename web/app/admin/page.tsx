import { formatPrice } from "@/lib/currency";
import { createClient } from "@/lib/supabase/server";
import RealtimeRefresher from "@/components/RealtimeRefresher";
import { getT } from "@/lib/i18n/server";

const PLATFORM_FEE_RATE = 0.1;

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
    supabase.from("restaurants").select("*", { count: "exact", head: true }).eq("is_approved", false),
    supabase.from("driver_profiles").select("*", { count: "exact", head: true }).eq("is_approved", false),
    supabase
      .from("orders")
      .select("*", { count: "exact", head: true })
      .in("status", ["pending", "accepted", "ready_for_pickup", "driver_assigned", "picked_up"]),
    supabase.from("orders").select("total_cents, subtotal_cents, delivery_fee_cents").eq("payment_status", "paid"),
  ]);

  const totalRevenueCents = (revenueRows ?? []).reduce((sum, r) => sum + r.total_cents, 0);
  const platformFeeRestaurant = (revenueRows ?? []).reduce(
    (sum, r) => sum + Math.round(r.subtotal_cents * PLATFORM_FEE_RATE),
    0
  );
  const platformFeeDriver = (revenueRows ?? []).reduce(
    (sum, r) => sum + Math.round(r.delivery_fee_cents * PLATFORM_FEE_RATE),
    0
  );
  const platformFeeTotal = platformFeeRestaurant + platformFeeDriver;

  return {
    totalOrders: totalOrders ?? 0,
    pendingApprovalRestaurants: pendingApprovalRestaurants ?? 0,
    pendingApprovalDrivers: pendingApprovalDrivers ?? 0,
    activeOrders: activeOrders ?? 0,
    totalRevenueCents,
    platformFeeTotal,
    platformFeeRestaurant,
    platformFeeDriver,
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

      {/* Platform earnings */}
      <div className="mt-6">
        <h2 className="text-base font-semibold text-slate-700">{t("Platform earnings (10% fee)")}</h2>
        <div className="mt-3 grid grid-cols-1 gap-4 sm:grid-cols-3">
          <div className="rounded-2xl bg-brand-50 p-5 ring-1 ring-brand-200">
            <p className="text-sm text-brand-600">{t("Total platform fee")}</p>
            <p className="mt-2 text-2xl font-bold text-brand-800">{formatPrice(stats.platformFeeTotal)}</p>
          </div>
          <div className="rounded-2xl bg-white p-5 shadow-sm ring-1 ring-slate-200">
            <p className="text-sm text-slate-500">{t("From restaurants (10% of food)")}</p>
            <p className="mt-2 text-2xl font-bold text-slate-900">{formatPrice(stats.platformFeeRestaurant)}</p>
          </div>
          <div className="rounded-2xl bg-white p-5 shadow-sm ring-1 ring-slate-200">
            <p className="text-sm text-slate-500">{t("From drivers (10% of delivery fee)")}</p>
            <p className="mt-2 text-2xl font-bold text-slate-900">{formatPrice(stats.platformFeeDriver)}</p>
          </div>
        </div>
      </div>
    </div>
  );
}
