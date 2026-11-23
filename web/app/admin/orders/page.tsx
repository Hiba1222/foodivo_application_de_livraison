"use client";

import { useEffect, useState } from "react";
import { createClient } from "@/lib/supabase/client";
import { formatPrice } from "@/lib/currency";
import { useI18n } from "@/lib/i18n/client";
import { formatDateTime, statusLabel } from "@/lib/i18n/core";

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

const ACTIVE = ["pending", "accepted", "ready_for_pickup", "driver_assigned", "picked_up"];
const STATUS_TABS = [
  { key: "", label: "All" },
  { key: "active", label: "Active" },
  { key: "delivered", label: "Delivered" },
  { key: "rejected", label: "Rejected" },
];

function localToday() {
  return new Date(
    new Date().toLocaleString("en-US", { timeZone: "Africa/Tunis" })
  ).toLocaleDateString("en-CA");
}

export default function AdminOrdersPage() {
  const { t, locale } = useI18n();
  const supabase = createClient();

  const [orders, setOrders] = useState<any[]>([]);
  const [restaurants, setRestaurants] = useState<{ id: string; name: string }[]>([]);
  const [loading, setLoading] = useState(true);

  // Filters
  const [statusTab, setStatusTab] = useState("");
  const [restaurantId, setRestaurantId] = useState("");
  const [day, setDay] = useState("");

  // Fetch restaurant list once
  useEffect(() => {
    supabase
      .from("restaurants")
      .select("id, name")
      .order("name")
      .then(({ data }) => setRestaurants(data ?? []));
  }, []);

  // Fetch orders whenever filters change
  useEffect(() => {
    setLoading(true);
    let q = supabase
      .from("orders")
      .select("id, status, total_cents, created_at, restaurants(name), profiles!orders_client_id_fkey(full_name)")
      .order("created_at", { ascending: false })
      .limit(200);

    if (restaurantId) q = q.eq("restaurant_id", restaurantId);

    if (day) {
      const from = `${day}T00:00:00+01:00`;
      const to = `${day}T23:59:59+01:00`;
      q = q.gte("created_at", from).lte("created_at", to);
    }

    if (statusTab === "active") q = q.in("status", ACTIVE);
    else if (statusTab === "delivered") q = q.eq("status", "delivered");
    else if (statusTab === "rejected") q = q.in("status", ["rejected", "cancelled"]);

    q.then(({ data }) => {
      setOrders(data ?? []);
      setLoading(false);
    });
  }, [restaurantId, day, statusTab]);

  const total = orders.reduce((s, o) => s + (o.total_cents ?? 0), 0);

  return (
    <div>
      <h1 className="text-xl font-bold text-slate-900">{t("All orders")}</h1>
      <p className="mt-1 text-sm text-slate-500">
        {t("Every order placed on the platform, most recent first.")}
      </p>

      {/* Filter bar */}
      <div className="mt-5 flex flex-wrap items-end gap-3">
        {/* Status tabs */}
        <div className="flex gap-1 rounded-xl bg-slate-100 p-1">
          {STATUS_TABS.map((tab) => (
            <button
              key={tab.key}
              onClick={() => setStatusTab(tab.key)}
              className={`rounded-lg px-3 py-1.5 text-sm font-medium transition ${
                statusTab === tab.key
                  ? "bg-white text-slate-900 shadow-sm"
                  : "text-slate-500 hover:text-slate-700"
              }`}
            >
              {t(tab.label)}
            </button>
          ))}
        </div>

        {/* Restaurant picker */}
        <select
          value={restaurantId}
          onChange={(e) => setRestaurantId(e.target.value)}
          className="rounded-xl border border-slate-200 bg-white px-3 py-2 text-sm text-slate-700 shadow-sm focus:outline-none focus:ring-2 focus:ring-brand-500"
        >
          <option value="">{t("All restaurants")}</option>
          {restaurants.map((r) => (
            <option key={r.id} value={r.id}>
              {r.name}
            </option>
          ))}
        </select>

        {/* Date picker */}
        <div className="flex items-center gap-2">
          <input
            type="date"
            value={day}
            max={localToday()}
            onChange={(e) => setDay(e.target.value)}
            className="rounded-xl border border-slate-200 bg-white px-3 py-2 text-sm text-slate-700 shadow-sm focus:outline-none focus:ring-2 focus:ring-brand-500"
          />
          {day && (
            <button
              onClick={() => setDay("")}
              className="rounded-lg bg-slate-100 px-2 py-2 text-xs text-slate-500 hover:bg-slate-200"
            >
              ✕
            </button>
          )}
        </div>

        {/* Summary */}
        {!loading && orders.length > 0 && (
          <span className="ml-auto text-sm font-semibold text-slate-700">
            {orders.length} {t("orders")} · {formatPrice(total)}
          </span>
        )}
      </div>

      {/* Table */}
      <div className="mt-4 overflow-hidden rounded-2xl bg-white shadow-sm ring-1 ring-slate-200">
        {loading ? (
          <div className="flex items-center justify-center py-16 text-slate-400">{t("Loading…")}</div>
        ) : (
          <table className="w-full text-left text-sm">
            <thead className="border-b border-slate-200 bg-slate-50 text-slate-500">
              <tr>
                <th className="px-4 py-3 font-medium">{t("Order")}</th>
                <th className="px-4 py-3 font-medium">{t("Restaurant")}</th>
                <th className="px-4 py-3 font-medium">{t("Client")}</th>
                <th className="px-4 py-3 font-medium">{t("Total")}</th>
                <th className="px-4 py-3 font-medium">{t("Status")}</th>
                <th className="px-4 py-3 font-medium">{t("Placed")}</th>
              </tr>
            </thead>
            <tbody>
              {orders.map((o) => (
                <tr key={o.id} className="border-b border-slate-100 last:border-0">
                  <td className="px-4 py-3 font-mono text-xs text-slate-500">
                    {o.id.slice(0, 8)}
                  </td>
                  <td className="px-4 py-3 text-slate-900">{o.restaurants?.name ?? "—"}</td>
                  <td className="px-4 py-3 text-slate-600">{o.profiles?.full_name ?? "—"}</td>
                  <td className="px-4 py-3 text-slate-900">{formatPrice(o.total_cents)}</td>
                  <td className="px-4 py-3">
                    <span className={`rounded-full px-2 py-0.5 text-xs font-semibold ${STATUS_STYLES[o.status] ?? ""}`}>
                      {statusLabel(t, o.status)}
                    </span>
                  </td>
                  <td className="px-4 py-3 text-slate-500">{formatDateTime(locale, o.created_at)}</td>
                </tr>
              ))}
              {orders.length === 0 && (
                <tr>
                  <td colSpan={6} className="px-4 py-8 text-center text-slate-400">
                    {t("No orders yet.")}
                  </td>
                </tr>
              )}
            </tbody>
          </table>
        )}
      </div>
    </div>
  );
}
