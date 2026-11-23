import Link from "next/link";
import { formatPrice } from "@/lib/currency";
import { createClient } from "@/lib/supabase/server";
import { getMyRestaurant } from "@/lib/restaurant";
import { updateOrderStatus } from "../actions";
import type { OrderStatus } from "@/lib/types";
import RealtimeRefresher from "@/components/RealtimeRefresher";
import OrderItemOptions from "@/components/OrderItemOptions";
import { ORDER_ITEMS_SELECT, type OrderItemOptionRow } from "@/lib/order-items";
import { getLocale, getT } from "@/lib/i18n/server";
import { formatDate, formatDateTime, formatTime, statusLabel, type Locale, type TFn } from "@/lib/i18n/core";
import { pickupCode } from "@/lib/order-codes";

// ── Types ──────────────────────────────────────────────────────────────────

interface OrderRow {
  id: string;
  status: OrderStatus;
  driver_id: string | null;
  total_cents: number;
  created_at: string;
  profiles: { full_name: string; phone: string | null } | null;
  order_items: {
    quantity: number;
    unit_price_cents: number;
    notes: string | null;
    menu_items: { name: string; image_url: string | null };
    order_item_options: OrderItemOptionRow[];
  }[];
}

interface HistoryRow {
  id: string;
  status: OrderStatus;
  total_cents: number;
  created_at: string;
  profiles: { full_name: string; phone: string | null } | null;
}

// ── Constants ───────────────────────────────────────────────────────────────

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

const STATUS_PRIORITY: Record<string, number> = {
  pending: 0,
  accepted: 1,
  ready_for_pickup: 2,
  driver_assigned: 3,
  picked_up: 4,
};

const ACTIVE_STATUSES = ["pending", "accepted", "ready_for_pickup", "driver_assigned", "picked_up"];
const PAST_STATUSES = ["delivered", "rejected", "cancelled"];

// ── Helpers ─────────────────────────────────────────────────────────────────

function offsetDay(day: string, n: number): string {
  const d = new Date(`${day}T12:00:00`);
  d.setDate(d.getDate() + n);
  return d.toLocaleDateString("en-CA");
}

function localToday(): string {
  // Tunisia is UTC+1 year-round
  return new Date(new Date().toLocaleString("en-US", { timeZone: "Africa/Tunis" })).toLocaleDateString("en-CA");
}

// ── Page ────────────────────────────────────────────────────────────────────

type Props = { searchParams: { view?: string; day?: string; month?: string } };

export default async function RestaurantOrdersPage({ searchParams }: Props) {
  const restaurant = await getMyRestaurant();
  if (!restaurant) return null;
  const t = getT();
  const locale = getLocale();
  const supabase = createClient();

  // ── Date state ──
  const view = searchParams.view === "month" ? "month" : "day";
  const todayStr = localToday();

  const selectedDay = searchParams.day ?? todayStr;
  const prevDayStr = offsetDay(selectedDay, -1);
  const nextDayStr = offsetDay(selectedDay, 1);
  const isToday = selectedDay === todayStr;

  const now = new Date();
  const rawMonth = searchParams.month ?? `${now.getFullYear()}-${now.getMonth() + 1}`;
  const [mYear, mMonth] = rawMonth.split("-").map(Number);
  const isCurrentMonth = mYear === now.getFullYear() && mMonth === now.getMonth() + 1;
  const prevMonthStr = mMonth === 1 ? `${mYear - 1}-12` : `${mYear}-${mMonth - 1}`;
  const nextMonthStr = mMonth === 12 ? `${mYear + 1}-1` : `${mYear}-${mMonth + 1}`;

  // ── Date range for history query ──
  let gte: string, lte: string;
  if (view === "day") {
    gte = `${selectedDay}T00:00:00+01:00`;
    lte = `${selectedDay}T23:59:59+01:00`;
  } else {
    const mm = String(mMonth).padStart(2, "0");
    const lastDay = new Date(mYear, mMonth, 0).getDate();
    const ld = String(lastDay).padStart(2, "0");
    gte = `${mYear}-${mm}-01T00:00:00+01:00`;
    lte = `${mYear}-${mm}-${ld}T23:59:59+01:00`;
  }

  // ── Queries ──
  const FULL_SELECT = `id, status, driver_id, total_cents, created_at, profiles!orders_client_id_fkey(full_name, phone), ${ORDER_ITEMS_SELECT}`;
  const HIST_SELECT = `id, status, total_cents, created_at, profiles!orders_client_id_fkey(full_name, phone)`;

  const [{ data: rawActive }, { data: rawHistory }] = await Promise.all([
    supabase
      .from("orders")
      .select(FULL_SELECT)
      .eq("restaurant_id", restaurant.id)
      .in("status", ACTIVE_STATUSES)
      .order("created_at", { ascending: false }),
    supabase
      .from("orders")
      .select(HIST_SELECT)
      .eq("restaurant_id", restaurant.id)
      .in("status", PAST_STATUSES)
      .gte("created_at", gte)
      .lte("created_at", lte)
      .order("created_at", { ascending: false })
      .limit(100),
  ]);

  const active = [...((rawActive as unknown as OrderRow[]) ?? [])].sort(
    (a, b) => (STATUS_PRIORITY[a.status] ?? 9) - (STATUS_PRIORITY[b.status] ?? 9)
  );
  const history = (rawHistory as unknown as HistoryRow[]) ?? [];
  const histRevenue = history
    .filter((o) => o.status === "delivered")
    .reduce((s, o) => s + o.total_cents, 0);
  const deliveredCount = history.filter((o) => o.status === "delivered").length;

  // ── Navigation labels ──
  const dtLocale = locale === "fr" ? "fr-FR" : "en-GB";
  const monthLabel = new Date(mYear, mMonth - 1, 1).toLocaleDateString(dtLocale, {
    month: "long",
    year: "numeric",
  });
  const dayDisplayLabel = isToday
    ? t("Today")
    : new Date(`${selectedDay}T12:00:00`).toLocaleDateString(dtLocale, {
        weekday: "short",
        day: "numeric",
        month: "short",
      });

  // ── URL builders ──
  const dayUrl = (d: string) => `/restaurant/orders?view=day&day=${d}`;
  const monthUrl = (m: string) => `/restaurant/orders?view=month&month=${m}`;

  return (
    <div className="space-y-10">
      <RealtimeRefresher table="orders" filter={`restaurant_id=eq.${restaurant.id}`} />

      {/* ══ ACTIVE ORDERS ══════════════════════════════════════════════════ */}
      <section>
        <div className="mb-5 flex items-center gap-3">
          <h1 className="text-xl font-black text-slate-900">{t("Active orders")}</h1>
          {active.length > 0 && (
            <span className="rounded-full bg-amber-100 px-2.5 py-0.5 text-xs font-bold text-amber-700">
              {active.length}
            </span>
          )}
        </div>

        {active.length === 0 ? (
          <div className="rounded-2xl bg-white p-10 text-center text-slate-400 shadow-sm ring-1 ring-slate-100">
            😌 {t("No active orders right now.")}
          </div>
        ) : (
          <div className="space-y-4">
            {active.map((order) => {
              const driverAssigned =
                order.status === "driver_assigned" || order.status === "picked_up";
              const code = driverAssigned ? pickupCode(order.id) : null;
              const isNew = order.status === "pending";
              const totalItems = order.order_items.reduce((s, i) => s + i.quantity, 0);

              return (
                <div
                  key={order.id}
                  className={`rounded-2xl bg-white p-5 shadow-sm ring-1 transition-shadow ${
                    isNew ? "ring-amber-300 shadow-amber-100" : "ring-slate-200"
                  }`}
                >
                  {/* Header */}
                  <div className="flex items-start justify-between gap-3">
                    <div className="flex items-start gap-3">
                      <div
                        className={`flex h-10 w-10 shrink-0 items-center justify-center rounded-xl text-sm font-black ${
                          STATUS_STYLES[order.status] ?? "bg-slate-100 text-slate-700"
                        }`}
                      >
                        {totalItems}
                      </div>
                      <div>
                        <p className="font-semibold text-slate-900">
                          {order.profiles?.full_name ?? t("Client")}
                        </p>
                        {order.profiles?.phone && (
                          <p className="text-xs text-slate-500">📞 {order.profiles.phone}</p>
                        )}
                        <p className="text-xs text-slate-400">
                          {formatTime(locale, order.created_at)} · #{order.id.slice(0, 6)}
                        </p>
                      </div>
                    </div>
                    <span
                      className={`shrink-0 rounded-full px-2.5 py-0.5 text-xs font-semibold ${
                        STATUS_STYLES[order.status]
                      }`}
                    >
                      {isNew && (
                        <span className="mr-1 inline-block h-1.5 w-1.5 animate-pulse rounded-full bg-amber-500 align-middle" />
                      )}
                      {statusLabel(t, order.status)}
                    </span>
                  </div>

                  {/* Pickup code */}
                  {code && (
                    <div className="mt-3 flex items-center gap-3 rounded-xl bg-indigo-50 px-4 py-3">
                      <div>
                        <p className="text-xs font-semibold text-indigo-500">
                          {t("Pickup code")}
                        </p>
                        <p className="text-2xl font-black tracking-widest text-indigo-800">
                          {code}
                        </p>
                      </div>
                      <p className="text-xs text-indigo-500">
                        {t("Ask the driver for this code before handing over the order.")}
                      </p>
                    </div>
                  )}

                  {/* Items */}
                  <div className="mt-3 space-y-2">
                    {order.order_items.map((oi, idx) => (
                      <div key={idx} className="flex items-start gap-3">
                        {/* Photo */}
                        {oi.menu_items?.image_url ? (
                          <img
                            src={oi.menu_items.image_url}
                            alt={oi.menu_items.name}
                            className="h-11 w-11 shrink-0 rounded-lg object-cover"
                          />
                        ) : (
                          <div className="flex h-11 w-11 shrink-0 items-center justify-center rounded-lg bg-slate-100 text-lg">
                            🍽️
                          </div>
                        )}
                        {/* Details */}
                        <div className="min-w-0 flex-1 pt-0.5">
                          <div className="flex items-baseline justify-between gap-2">
                            <span className="font-semibold text-slate-800">
                              {oi.quantity}× {oi.menu_items?.name}
                            </span>
                            <span className="shrink-0 text-xs text-slate-500">
                              {formatPrice(oi.quantity * oi.unit_price_cents)}
                            </span>
                          </div>
                          <OrderItemOptions options={oi.order_item_options} notes={oi.notes} />
                        </div>
                      </div>
                    ))}
                  </div>

                  {/* Footer */}
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
              );
            })}
          </div>
        )}
      </section>

      {/* ══ ORDER HISTORY ══════════════════════════════════════════════════ */}
      <section>
        <h2 className="mb-4 text-xl font-black text-slate-900">{t("Order history")}</h2>

        {/* View toggle */}
        <div className="mb-3 flex items-center gap-2">
          <Link
            href={dayUrl(selectedDay)}
            className={`rounded-full px-4 py-1.5 text-sm font-semibold transition-colors ${
              view === "day"
                ? "bg-brand-600 text-white shadow-sm"
                : "bg-slate-100 text-slate-600 hover:bg-slate-200"
            }`}
          >
            {t("Day")}
          </Link>
          <Link
            href={monthUrl(rawMonth)}
            className={`rounded-full px-4 py-1.5 text-sm font-semibold transition-colors ${
              view === "month"
                ? "bg-brand-600 text-white shadow-sm"
                : "bg-slate-100 text-slate-600 hover:bg-slate-200"
            }`}
          >
            {t("Month")}
          </Link>
        </div>

        {/* Date navigation */}
        <div className="mb-5 flex items-center gap-2">
          <Link
            href={view === "day" ? dayUrl(prevDayStr) : monthUrl(prevMonthStr)}
            className="flex h-8 w-8 items-center justify-center rounded-full bg-white text-lg text-slate-500 shadow-sm ring-1 ring-slate-200 hover:bg-slate-50"
          >
            ‹
          </Link>
          <div className="flex items-center gap-2">
            <span className="min-w-[9rem] text-center text-sm font-semibold capitalize text-slate-900">
              {view === "day" ? dayDisplayLabel : monthLabel}
            </span>
            {view === "day" && !isToday && (
              <Link
                href={dayUrl(todayStr)}
                className="rounded-full bg-brand-50 px-2.5 py-0.5 text-xs font-semibold text-brand-600 hover:bg-brand-100"
              >
                {t("Today")}
              </Link>
            )}
          </div>
          {!(view === "day" ? isToday : isCurrentMonth) && (
            <Link
              href={view === "day" ? dayUrl(nextDayStr) : monthUrl(nextMonthStr)}
              className="flex h-8 w-8 items-center justify-center rounded-full bg-white text-lg text-slate-500 shadow-sm ring-1 ring-slate-200 hover:bg-slate-50"
            >
              ›
            </Link>
          )}
        </div>

        {/* Period stats */}
        {history.length > 0 && (
          <div className="mb-5 flex flex-wrap items-center gap-x-4 gap-y-1 rounded-xl bg-slate-50 px-4 py-3 text-sm ring-1 ring-slate-100">
            <span className="font-semibold text-slate-700">
              {history.length} {t("orders")}
            </span>
            <span className="text-slate-300">·</span>
            <span className="font-semibold text-slate-700">
              {deliveredCount} {t("delivered")}
            </span>
            {histRevenue > 0 && (
              <>
                <span className="text-slate-300">·</span>
                <span className="font-semibold text-green-700">
                  {formatPrice(histRevenue)} {t("revenue")}
                </span>
              </>
            )}
          </div>
        )}

        {/* History cards */}
        {history.length === 0 ? (
          <div className="rounded-2xl bg-white p-10 text-center text-slate-400 shadow-sm ring-1 ring-slate-100">
            🧾 {t("No orders for this period.")}
          </div>
        ) : (
          <div className="space-y-3">
            {history.map((order) => (
              <div
                key={order.id}
                className="flex items-center gap-4 rounded-xl bg-white px-4 py-3 shadow-sm ring-1 ring-slate-100"
              >
                <span
                  className={`shrink-0 rounded-full px-2.5 py-0.5 text-xs font-semibold ${
                    STATUS_STYLES[order.status] ?? "bg-slate-100 text-slate-600"
                  }`}
                >
                  {statusLabel(t, order.status)}
                </span>
                <div className="min-w-0 flex-1">
                  <p className="truncate text-sm font-semibold text-slate-800">
                    {order.profiles?.full_name ?? t("Client")}
                  </p>
                  <p className="text-xs text-slate-400">
                    {view === "day"
                      ? formatTime(locale, order.created_at)
                      : formatDate(locale, order.created_at)}
                  </p>
                </div>
                <p className="shrink-0 text-sm font-bold text-slate-900">
                  {formatPrice(order.total_cents)}
                </p>
              </div>
            ))}
          </div>
        )}
      </section>
    </div>
  );
}
