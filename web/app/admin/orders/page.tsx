import { formatPrice } from "@/lib/currency";
import { createClient } from "@/lib/supabase/server";
import type { Order } from "@/lib/types";
import RealtimeRefresher from "@/components/RealtimeRefresher";
import { getLocale, getT } from "@/lib/i18n/server";
import { formatDateTime, statusLabel } from "@/lib/i18n/core";

async function getOrders(): Promise<Order[]> {
  const supabase = createClient();
  const { data } = await supabase
    .from("orders")
    .select("*, restaurants(name), profiles!orders_client_id_fkey(full_name)")
    .order("created_at", { ascending: false })
    .limit(100);
  return (data as unknown as Order[]) ?? [];
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

export default async function AdminOrdersPage() {
  const t = getT();
  const locale = getLocale();
  const orders = await getOrders();

  return (
    <div>
      <RealtimeRefresher table="orders" />
      <h1 className="text-xl font-bold text-slate-900">{t("All orders")}</h1>
      <p className="mt-1 text-sm text-slate-500">
        {t("Every order placed on the platform, most recent first.")}
      </p>

      <div className="mt-6 overflow-hidden rounded-2xl bg-white shadow-sm ring-1 ring-slate-200">
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
                <td className="px-4 py-3 text-slate-900">
                  {formatPrice(o.total_cents)}
                </td>
                <td className="px-4 py-3">
                  <span
                    className={`rounded-full px-2 py-0.5 text-xs font-semibold ${
                      STATUS_STYLES[o.status]
                    }`}
                  >
                    {statusLabel(t, o.status)}
                  </span>
                </td>
                <td className="px-4 py-3 text-slate-500">
                  {formatDateTime(locale, o.created_at)}
                </td>
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
      </div>
    </div>
  );
}
