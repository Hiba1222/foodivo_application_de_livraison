import { formatPrice } from "@/lib/currency";
import { createClient } from "@/lib/supabase/server";
import OrderItemOptions from "@/components/OrderItemOptions";
import { ORDER_ITEMS_SELECT } from "@/lib/order-items";
import RealtimeRefresher from "@/components/RealtimeRefresher";
import DriverLocationMap from "./DriverLocationMap";
import CancelOrderButton from "@/components/CancelOrderButton";
import ReviewForm from "@/components/ReviewForm";
import { getLocale, getT } from "@/lib/i18n/server";
import { formatDateTime, formatTime } from "@/lib/i18n/core";
import { deliveryCode } from "@/lib/order-codes";

const STATUS_FLOW = [
  "pending",
  "accepted",
  "ready_for_pickup",
  "driver_assigned",
  "picked_up",
  "delivered",
];

// English keys — translated with t() at render time.
const STATUS_LABEL: Record<string, string> = {
  pending: "Order placed",
  accepted: "Restaurant accepted",
  rejected: "Restaurant rejected",
  ready_for_pickup: "Ready for pickup",
  driver_assigned: "Driver assigned",
  picked_up: "Picked up — on the way",
  delivered: "Delivered",
  cancelled: "Cancelled",
};

export default async function ClientOrderDetailPage({ params }: { params: { id: string } }) {
  const t = getT();
  const locale = getLocale();
  const supabase = createClient();

  const [{ data: order }, { data: history }, { data: review }] = await Promise.all([
    supabase
      .from("orders")
      .select(
        `id, status, driver_id, subtotal_cents, delivery_fee_cents, total_cents, created_at, restaurants(name, address), ${ORDER_ITEMS_SELECT}`
      )
      .eq("id", params.id)
      .single(),
    supabase
      .from("order_status_history")
      .select("status, changed_at")
      .eq("order_id", params.id)
      .order("changed_at", { ascending: true }),
    supabase
      .from("reviews")
      .select("id, restaurant_rating, driver_rating, comment")
      .eq("order_id", params.id)
      .maybeSingle(),
  ]);

  if (!order) return <p className="text-slate-500">{t("Order not found.")}</p>;

  const currentStepIndex = STATUS_FLOW.indexOf(order.status);
  const isTerminalFailure = order.status === "rejected" || order.status === "cancelled";
  let driverInfo: {
    fullName: string;
    phone: string | null;
    avatarUrl: string | null;
    vehicle: string | null;
    location: { latitude: number; longitude: number } | null;
  } | null = null;
  if (order.driver_id && (order.status === "driver_assigned" || order.status === "picked_up")) {
    // Profiles are private (RLS); this function returns the driver's contact
    // only to the client of this order while the delivery is in progress.
    const { data: rows } = await supabase.rpc("get_order_driver", { p_order_id: order.id });
    const d = (rows as any[] | null)?.[0];
    if (d) {
      driverInfo = {
        fullName: d.full_name ?? t("Your driver"),
        phone: d.phone ?? null,
        avatarUrl: d.avatar_url ?? null,
        vehicle: [d.vehicle_type, d.license_plate].filter(Boolean).join(" · ") || null,
        location:
          d.current_latitude && d.current_longitude
            ? { latitude: d.current_latitude, longitude: d.current_longitude }
            : null,
      };
    }
  }

  return (
    <div className="max-w-xl">
      {/* Live updates: re-renders this page whenever this order's row
          changes, or the assigned driver's location updates. */}
      <RealtimeRefresher table="orders" filter={`id=eq.${order.id}`} />
      {order.driver_id && (
        <RealtimeRefresher table="driver_profiles" filter={`id=eq.${order.driver_id}`} />
      )}

      <h1 className="text-xl font-bold text-slate-900">
        {t("Order from {name}", { name: (order as any).restaurants?.name ?? "" })}
      </h1>
      <p className="mt-1 text-sm text-slate-500">
        {t("Placed {date}", { date: formatDateTime(locale, order.created_at) })}
      </p>

      {/* Tracking timeline */}
      <div className="mt-6 rounded-2xl bg-white p-5 shadow-sm ring-1 ring-slate-200">
        {isTerminalFailure ? (
          <p className="text-sm font-semibold text-red-600">
            {t(STATUS_LABEL[order.status])}
          </p>
        ) : (
          <ol className="space-y-3">
            {STATUS_FLOW.map((step, idx) => {
              const reached = idx <= currentStepIndex;
              const historyEntry = history?.find((h) => h.status === step);
              return (
                <li key={step} className="flex items-center gap-3">
                  <span
                    className={`h-3 w-3 rounded-full ${
                      reached ? "bg-brand-600" : "bg-slate-200"
                    }`}
                  />
                  <span
                    className={`text-sm ${
                      reached ? "font-medium text-slate-900" : "text-slate-400"
                    }`}
                  >
                    {t(STATUS_LABEL[step])}
                  </span>
                  {historyEntry && (
                    <span className="ml-auto text-xs text-slate-400">
                      {formatTime(locale, historyEntry.changed_at)}
                    </span>
                  )}
                </li>
              );
            })}
          </ol>
        )}
      </div>

      {/* Delivery verification code — shown when driver is assigned */}
      {order.driver_id && (order.status === "driver_assigned" || order.status === "picked_up") && (
        <div className="mt-4 flex items-center gap-4 rounded-2xl bg-green-50 px-5 py-4 ring-1 ring-green-200">
          <div>
            <p className="text-xs font-semibold text-green-600">{t("Your delivery code")}</p>
            <p className="text-3xl font-black tracking-widest text-green-800">{deliveryCode(order.id)}</p>
          </div>
          <p className="text-xs text-green-600">{t("Share this code with your driver to confirm your identity.")}</p>
        </div>
      )}

      {/* Driver info + live location */}
      {driverInfo && (
        <div className="mt-4 animate-scale-in overflow-hidden rounded-2xl bg-white shadow-soft ring-1 ring-slate-200/70">
          <div className="flex items-center gap-2 bg-gradient-to-r from-brand-500 to-rose-500 px-5 py-2 text-xs font-bold text-white">
            <span className="live-dot h-2 w-2 rounded-full bg-white" />
            {order.status === "picked_up" ? `${t("Your order is on the way")} 🛵` : t("A driver is heading to the restaurant")}
          </div>
          <div className="flex items-center gap-4 p-5">
            {driverInfo.avatarUrl ? (
              // eslint-disable-next-line @next/next/no-img-element
              <img
                src={driverInfo.avatarUrl}
                alt={driverInfo.fullName}
                className="h-14 w-14 rounded-full object-cover ring-4 ring-brand-50"
              />
            ) : (
              <div className="flex h-14 w-14 items-center justify-center rounded-full bg-gradient-to-br from-brand-100 to-rose-100 text-xl font-extrabold text-brand-700 ring-4 ring-brand-50">
                {driverInfo.fullName.trim().charAt(0).toUpperCase() || "🛵"}
              </div>
            )}
            <div className="min-w-0 flex-1">
              <p className="text-xs font-medium uppercase tracking-wide text-slate-400">{t("Your driver")}</p>
              <p className="truncate text-base font-bold text-slate-900">{driverInfo.fullName}</p>
              {driverInfo.phone && (
                <p className="text-sm font-medium text-slate-600">📞 {driverInfo.phone}</p>
              )}
              {driverInfo.vehicle && <p className="text-xs text-slate-400">{driverInfo.vehicle}</p>}
            </div>
            {driverInfo.phone && (
              <a
                href={`tel:${driverInfo.phone.replace(/[^+\d]/g, "")}`}
                className="flex shrink-0 items-center gap-2 rounded-full bg-green-600 px-4 py-2.5 text-sm font-bold text-white shadow-md hover:-translate-y-0.5 hover:bg-green-700"
              >
                📞 {t("Call")}
              </a>
            )}
          </div>
          {driverInfo.location && (
            <div className="px-5 pb-5">
              <DriverLocationMap
                latitude={driverInfo.location.latitude}
                longitude={driverInfo.location.longitude}
              />
            </div>
          )}
        </div>
      )}

      {/* Cancel button — only while pending */}
      {order.status === "pending" && (
        <CancelOrderButton orderId={order.id} />
      )}

      {/* Review form — only after delivery and not yet reviewed */}
      {order.status === "delivered" && !review && (
        <ReviewForm orderId={order.id} hasDriver={!!order.driver_id} />
      )}

      {/* Show existing review */}
      {order.status === "delivered" && review && (
        <div className="mt-4 rounded-2xl bg-amber-50 p-5 ring-1 ring-amber-200">
          <p className="text-xs font-semibold uppercase tracking-wide text-amber-600">{t("Your review")}</p>
          <div className="mt-2 flex gap-4 text-sm">
            <span>🍽️ {"⭐".repeat(review.restaurant_rating ?? 0)}</span>
            {review.driver_rating && <span>🛵 {"⭐".repeat(review.driver_rating)}</span>}
          </div>
          {review.comment && <p className="mt-1 text-sm text-slate-600">{review.comment}</p>}
        </div>
      )}

      {/* Items */}
      <div className="mt-4 rounded-2xl bg-white p-5 shadow-sm ring-1 ring-slate-200">
        <h2 className="text-sm font-semibold text-slate-900">{t("Items")}</h2>
        <ul className="mt-2 space-y-1 text-sm text-slate-600">
          {(order as any).order_items.map((oi: any, idx: number) => (
            <li key={idx}>
              <div className="flex justify-between">
                <span>
                  {oi.quantity}× {oi.menu_items?.name}
                </span>
                <span>{formatPrice((oi.quantity * oi.unit_price_cents))}</span>
              </div>
              <OrderItemOptions options={oi.order_item_options} notes={oi.notes} />
            </li>
          ))}
        </ul>
        <div className="mt-3 space-y-1 border-t border-slate-100 pt-3 text-sm">
          <div className="flex justify-between text-slate-600">
            <span>{t("Subtotal")}</span>
            <span>{formatPrice(order.subtotal_cents)}</span>
          </div>
          <div className="flex justify-between text-slate-600">
            <span>{t("Delivery fee")}</span>
            <span>{formatPrice(order.delivery_fee_cents)}</span>
          </div>
          <div className="flex justify-between font-bold text-slate-900">
            <span>{t("Total")}</span>
            <span>{formatPrice(order.total_cents)}</span>
          </div>
        </div>
      </div>
    </div>
  );
}
