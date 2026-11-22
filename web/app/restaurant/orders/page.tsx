import { formatPrice } from "@/lib/currency";
import { createClient } from "@/lib/supabase/server";
import { getMyRestaurant } from "@/lib/restaurant";
import { updateOrderStatus } from "../actions";
import type { OrderStatus } from "@/lib/types";
import RealtimeRefresher from "@/components/RealtimeRefresher";
import OrderItemOptions from "@/components/OrderItemOptions";
import { ORDER_ITEMS_SELECT, type OrderItemOptionRow } from "@/lib/order-items";
import { getLocale, getT } from "@/lib/i18n/server";
import { formatDateTime, statusLabel } from "@/lib/i18n/core";

interface OrderRow {
  id: string;
  status: OrderStatus;
  total_cents: number;
  created_at: string;
  profiles: { full_name: string } | null;
  order_items: {
    quantity: number;
    unit_price_cents: number;
    notes: string | null;
    menu_items: { name: string };
    order_item_options: OrderItemOptionRow[];
  }[];
}

const STATUS_STYLES: Record<string, string> = {
  pending: "bg-amber-100 text-amber-700",
  accepted: "bg-blue-100 text-blue-700",
  rejected: "bg-red-100 text-red-700",
  ready_for_pickup: "bg-indigo-100 text-indigo-700",
  driver_assigned: "bg-indigo-100 text-indigo-700",
  picked_up: "bg-purple-100 text-purple-700",
  delivered: "bg-green-100 text-green-700",
  cancelled: "bg-slate-200 text-slate-600",
};

export default async function RestaurantOrdersPage() {
  const restaurant = await getMyRestaurant();
  if (!restaurant) return null;
  const t = getT();
  const locale = getLocale();

  const supabase = createClient();
  const { data } = await supabase
    .from("orders")
    .select(
      `id, status, total_cents, created_at, profiles!orders_client_id_fkey(full_name), ${ORDER_ITEMS_SELECT}`
    )
    .eq("restaurant_id", restaurant.id)
    .order("created_at", { ascending: false })
    .limit(50);

  const orders = (data as unknown as OrderRow[]) ?? [];

  return (
    <div>
      <RealtimeRefresher table="orders" filter={`restaurant_id=eq.${restaurant.id}`} />
      <h1 className="text-xl font-bold text-slate-900">{t("Orders")}</h1>
      <p className="mt-1 text-sm text-slate-500">
        {t("New orders need a response. Accepted orders should be marked ready when the food is packed.")}
      </p>

      <div className="mt-6 space-y-4">
        {orders.map((order) => (
          <div
            key={order.id}
            className="rounded-2xl bg-white p-5 shadow-sm ring-1 ring-slate-200"
          >
            <div className="flex items-start justify-between">
              <div>
                <p className="font-semibold text-slate-900">
                  {order.profiles?.full_name ?? t("Client")}
                </p>
                <p className="text-xs text-slate-500">
                  {formatDateTime(locale, order.created_at)}
                </p>
              </div>
              <span
                className={`rounded-full px-2 py-0.5 text-xs font-semibold ${
                  STATUS_STYLES[order.status]
                }`}
              >
                {statusLabel(t, order.status)}
              </span>
            </div>

            <ul className="mt-3 space-y-2 text-sm text-slate-600">
              {order.order_items.map((oi, idx) => (
                <li key={idx}>
                  <span className="font-medium text-slate-800">
                    {oi.quantity}× {oi.menu_items?.name}
                  </span>{" "}
                  — {formatPrice((oi.quantity * oi.unit_price_cents))}
                  <OrderItemOptions options={oi.order_item_options} notes={oi.notes} />
                </li>
              ))}
            </ul>

            <div className="mt-3 flex items-center justify-between border-t border-slate-100 pt-3">
              <p className="text-sm font-semibold text-slate-900">
                {t("Total")}: {formatPrice(order.total_cents)}
              </p>

              <div className="flex gap-2">
                {order.status === "pending" && (
                  <>
                    <form action={updateOrderStatus.bind(null, order.id, "rejected")}>
                      <button
                        type="submit"
                        className="rounded-lg bg-red-50 px-3 py-1.5 text-xs font-semibold text-red-700 hover:bg-red-100"
                      >
                        {t("Reject")}
                      </button>
                    </form>
                    <form action={updateOrderStatus.bind(null, order.id, "accepted")}>
                      <button
                        type="submit"
                        className="rounded-lg bg-brand-600 px-3 py-1.5 text-xs font-semibold text-white hover:bg-brand-700"
                      >
                        {t("Accept")}
                      </button>
                    </form>
                  </>
                )}
                {order.status === "accepted" && (
                  <form action={updateOrderStatus.bind(null, order.id, "ready_for_pickup")}>
                    <button
                      type="submit"
                      className="rounded-lg bg-indigo-600 px-3 py-1.5 text-xs font-semibold text-white hover:bg-indigo-700"
                    >
                      {t("Mark ready for pickup")}
                    </button>
                  </form>
                )}
              </div>
            </div>
          </div>
        ))}

        {orders.length === 0 && (
          <div className="rounded-2xl bg-white p-8 text-center text-slate-400 shadow-sm ring-1 ring-slate-200">
            {t("No orders yet.")}
          </div>
        )}
      </div>
    </div>
  );
}
