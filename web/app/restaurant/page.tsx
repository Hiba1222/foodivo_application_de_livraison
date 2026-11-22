import { formatPrice } from "@/lib/currency";
import { createClient } from "@/lib/supabase/server";
import { getMyRestaurant } from "@/lib/restaurant";
import { toggleRestaurantOpen } from "./actions";
import RealtimeRefresher from "@/components/RealtimeRefresher";
import { getT } from "@/lib/i18n/server";

export default async function RestaurantOverviewPage() {
  const restaurant = await getMyRestaurant();
  if (!restaurant) return null; // layout already handles onboarding

  const t = getT();
  const supabase = createClient();
  const startOfToday = new Date();
  startOfToday.setHours(0, 0, 0, 0);

  const [{ count: pendingCount }, { count: activeCount }, { data: todayOrders }] =
    await Promise.all([
      supabase
        .from("orders")
        .select("*", { count: "exact", head: true })
        .eq("restaurant_id", restaurant.id)
        .eq("status", "pending"),
      supabase
        .from("orders")
        .select("*", { count: "exact", head: true })
        .eq("restaurant_id", restaurant.id)
        .in("status", ["accepted", "ready_for_pickup", "driver_assigned", "picked_up"]),
      supabase
        .from("orders")
        .select("total_cents")
        .eq("restaurant_id", restaurant.id)
        .gte("created_at", startOfToday.toISOString()),
    ]);

  const todayRevenueCents = (todayOrders ?? []).reduce((sum, o) => sum + o.total_cents, 0);

  return (
    <div>
      <RealtimeRefresher table="orders" filter={`restaurant_id=eq.${restaurant.id}`} />
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-xl font-bold text-slate-900">{restaurant.name}</h1>
          <p className="mt-1 text-sm text-slate-500">{restaurant.address}</p>
        </div>
        <form action={toggleRestaurantOpen.bind(null, restaurant.id, !restaurant.is_open)}>
          <button
            type="submit"
            className={`rounded-lg px-4 py-2 text-sm font-semibold ${
              restaurant.is_open
                ? "bg-green-100 text-green-700 hover:bg-green-200"
                : "bg-slate-200 text-slate-600 hover:bg-slate-300"
            }`}
          >
            {restaurant.is_open ? t("Open — accepting orders") : t("Closed — tap to open")}
          </button>
        </form>
      </div>

      <div className="mt-6 grid grid-cols-1 gap-4 sm:grid-cols-3">
        <div className="rounded-2xl bg-white p-5 shadow-sm ring-1 ring-slate-200">
          <p className="text-sm text-slate-500">{t("New orders waiting")}</p>
          <p className="mt-2 text-2xl font-bold text-slate-900">{pendingCount ?? 0}</p>
        </div>
        <div className="rounded-2xl bg-white p-5 shadow-sm ring-1 ring-slate-200">
          <p className="text-sm text-slate-500">{t("In progress")}</p>
          <p className="mt-2 text-2xl font-bold text-slate-900">{activeCount ?? 0}</p>
        </div>
        <div className="rounded-2xl bg-white p-5 shadow-sm ring-1 ring-slate-200">
          <p className="text-sm text-slate-500">{t("Revenue today")}</p>
          <p className="mt-2 text-2xl font-bold text-slate-900">
            {formatPrice(todayRevenueCents)}
          </p>
        </div>
      </div>
    </div>
  );
}
