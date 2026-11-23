import { createClient } from "@/lib/supabase/server";
import { getMyDriverProfile } from "@/lib/driver";
import { markPickedUp, markDelivered } from "../actions";
import RealtimeRefresher from "@/components/RealtimeRefresher";
import { getT } from "@/lib/i18n/server";
import { statusLabel } from "@/lib/i18n/core";
import { pickupCode, deliveryCode } from "@/lib/order-codes";

export default async function MyDeliveriesPage() {
  const driver = await getMyDriverProfile();
  if (!driver) return null;

  const t = getT();
  const supabase = createClient();
  const { data: orders } = await supabase
    .from("orders")
    .select(
      "id, status, total_cents, restaurants(name, address), client_addresses(address_line), profiles!orders_client_id_fkey(full_name, phone), order_items(quantity, menu_items(name, image_url))"
    )
    .eq("driver_id", driver.id)
    .in("status", ["driver_assigned", "picked_up"])
    .order("created_at", { ascending: true });

  return (
    <div>
      <RealtimeRefresher table="orders" filter={`driver_id=eq.${driver.id}`} />
      <h1 className="text-xl font-bold text-slate-900">{t("My deliveries")}</h1>

      <div className="mt-6 space-y-4">
        {(orders ?? []).map((order: any) => {
          const pCode = pickupCode(order.id);
          const dCode = deliveryCode(order.id);
          const pickedUp = order.status === "picked_up";

          return (
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

              {/* Order items */}
              {(order.order_items ?? []).length > 0 && (
                <div className="mt-3 flex flex-wrap gap-2 border-t border-slate-100 pt-3">
                  {(order.order_items as { quantity: number; menu_items: { name: string; image_url: string | null } }[]).map(
                    (oi, idx) => (
                      <div key={idx} className="flex items-center gap-2 rounded-xl bg-slate-50 py-1.5 pl-1.5 pr-3">
                        {oi.menu_items?.image_url ? (
                          <img
                            src={oi.menu_items.image_url}
                            alt={oi.menu_items.name}
                            className="h-8 w-8 rounded-lg object-cover"
                          />
                        ) : (
                          <div className="flex h-8 w-8 items-center justify-center rounded-lg bg-slate-200 text-sm">
                            🍽️
                          </div>
                        )}
                        <span className="text-sm font-medium text-slate-700">
                          {oi.quantity}× {oi.menu_items?.name}
                        </span>
                      </div>
                    )
                  )}
                </div>
              )}

              {/* Verification codes */}
              <div className="mt-4 grid grid-cols-2 gap-3">
                {!pickedUp && (
                  <div className="rounded-xl bg-indigo-50 px-4 py-3">
                    <p className="text-xs font-semibold text-indigo-500">{t("Pickup code")}</p>
                    <p className="text-xl font-black tracking-widest text-indigo-800">{pCode}</p>
                    <p className="text-xs text-indigo-400">{t("Show to restaurant")}</p>
                  </div>
                )}
                <div className={`rounded-xl bg-green-50 px-4 py-3 ${!pickedUp ? "" : "col-span-2"}`}>
                  <p className="text-xs font-semibold text-green-600">{t("Delivery code")}</p>
                  <p className="text-xl font-black tracking-widest text-green-800">{dCode}</p>
                  <p className="text-xs text-green-500">{t("Ask client for this code")}</p>
                </div>
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
          );
        })}

        {(orders ?? []).length === 0 && (
          <p className="py-16 text-center text-slate-400">
            {t("No active deliveries. Check Available deliveries to accept one.")}
          </p>
        )}
      </div>
    </div>
  );
}
