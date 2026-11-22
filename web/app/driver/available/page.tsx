import { formatPrice } from "@/lib/currency";
import { createClient } from "@/lib/supabase/server";
import { getMyDriverProfile } from "@/lib/driver";
import { acceptDelivery } from "../actions";
import RealtimeRefresher from "@/components/RealtimeRefresher";
import { getT } from "@/lib/i18n/server";

export default async function AvailableDeliveriesPage() {
  const driver = await getMyDriverProfile();
  if (!driver) return null;

  const t = getT();
  const supabase = createClient();
  const { data: orders } = await supabase
    .from("orders")
    .select(
      "id, delivery_fee_cents, created_at, restaurants(name, address), client_addresses(address_line)"
    )
    .eq("status", "ready_for_pickup")
    .is("driver_id", null)
    .order("ready_at", { ascending: true });

  if (!driver.is_approved) {
    return (
      <p className="text-slate-500">
        {t("You can browse available deliveries once an admin approves your driver account.")}
      </p>
    );
  }

  if (!driver.is_online) {
    return (
      <p className="text-slate-500">{t("Go online from the Overview page to see available deliveries.")}</p>
    );
  }

  return (
    <div>
      <RealtimeRefresher table="orders" filter="status=eq.ready_for_pickup" />
      <h1 className="text-xl font-bold text-slate-900">{t("Available deliveries")}</h1>
      <p className="mt-1 text-sm text-slate-500">
        {t("First to accept gets it — this list updates as other drivers pick up orders.")}
      </p>

      <div className="mt-6 space-y-3">
        {(orders ?? []).map((order: any) => (
          <div
            key={order.id}
            className="flex items-center justify-between rounded-2xl bg-white p-4 shadow-sm ring-1 ring-slate-200"
          >
            <div>
              <p className="font-medium text-slate-900">{order.restaurants?.name}</p>
              <p className="text-sm text-slate-500">{t("Pickup")}: {order.restaurants?.address}</p>
              <p className="text-sm text-slate-500">
                {t("Dropoff")}: {order.client_addresses?.address_line}
              </p>
            </div>
            <div className="text-right">
              <p className="mb-2 text-sm font-semibold text-slate-900">
                {t("{price} fee", { price: formatPrice(order.delivery_fee_cents) })}
              </p>
              <form action={acceptDelivery.bind(null, order.id)}>
                <button
                  type="submit"
                  className="rounded-lg bg-brand-600 px-3 py-1.5 text-xs font-semibold text-white hover:bg-brand-700"
                >
                  {t("Accept")}
                </button>
              </form>
            </div>
          </div>
        ))}

        {(orders ?? []).length === 0 && (
          <p className="py-16 text-center text-slate-400">{t("No deliveries waiting right now.")}</p>
        )}
      </div>
    </div>
  );
}
