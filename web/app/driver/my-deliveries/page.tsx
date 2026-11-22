import { createClient } from "@/lib/supabase/server";
import { getMyDriverProfile } from "@/lib/driver";
import { markPickedUp, markDelivered } from "../actions";
import RealtimeRefresher from "@/components/RealtimeRefresher";
import { getT } from "@/lib/i18n/server";
import { statusLabel } from "@/lib/i18n/core";

export default async function MyDeliveriesPage() {
  const driver = await getMyDriverProfile();
  if (!driver) return null;

  const t = getT();
  const supabase = createClient();
  const { data: orders } = await supabase
    .from("orders")
    .select(
      "id, status, total_cents, restaurants(name, address), client_addresses(address_line), profiles!orders_client_id_fkey(full_name, phone)"
    )
    .eq("driver_id", driver.id)
    .in("status", ["driver_assigned", "picked_up"])
    .order("created_at", { ascending: true });

  return (
    <div>
      <RealtimeRefresher table="orders" filter={`driver_id=eq.${driver.id}`} />
      <h1 className="text-xl font-bold text-slate-900">{t("My deliveries")}</h1>

      <div className="mt-6 space-y-4">
        {(orders ?? []).map((order: any) => (
          <div
            key={order.id}
            className="rounded-2xl bg-white p-5 shadow-sm ring-1 ring-slate-200"
          >
            <div className="flex items-start justify-between">
              <div>
                <p className="font-semibold text-slate-900">{order.restaurants?.name}</p>
                <p className="text-sm text-slate-500">{t("Pickup")}: {order.restaurants?.address}</p>
                <p className="text-sm text-slate-500">
                  {t("Dropoff")}: {order.client_addresses?.address_line}
                </p>
                <p className="mt-1 text-xs text-slate-400">
                  {t("Client")}: {order.profiles?.full_name} · {order.profiles?.phone ?? t("no phone on file")}
                </p>
              </div>
              <span className="rounded-full bg-indigo-100 px-2 py-0.5 text-xs font-semibold text-indigo-700">
                {statusLabel(t, order.status)}
              </span>
            </div>

            <div className="mt-4 flex justify-end">
              {order.status === "driver_assigned" && (
                <form action={markPickedUp.bind(null, order.id)}>
                  <button
                    type="submit"
                    className="rounded-lg bg-purple-600 px-4 py-2 text-xs font-semibold text-white hover:bg-purple-700"
                  >
                    {t("I've picked up the order")}
                  </button>
                </form>
              )}
              {order.status === "picked_up" && (
                <form action={markDelivered.bind(null, order.id)}>
                  <button
                    type="submit"
                    className="rounded-lg bg-green-600 px-4 py-2 text-xs font-semibold text-white hover:bg-green-700"
                  >
                    {t("Mark as delivered")}
                  </button>
                </form>
              )}
            </div>
          </div>
        ))}

        {(orders ?? []).length === 0 && (
          <p className="py-16 text-center text-slate-400">
            {t("No active deliveries. Check Available deliveries to accept one.")}
          </p>
        )}
      </div>
    </div>
  );
}
