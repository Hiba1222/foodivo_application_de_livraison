import { formatPrice } from "@/lib/currency";
import { createClient } from "@/lib/supabase/server";
import { getMyDriverProfile } from "@/lib/driver";
import { getLocale, getT } from "@/lib/i18n/server";
import { formatDateTime } from "@/lib/i18n/core";

export default async function DriverHistoryPage() {
  const driver = await getMyDriverProfile();
  if (!driver) return null;

  const t = getT();
  const locale = getLocale();
  const supabase = createClient();
  const { data: orders } = await supabase
    .from("orders")
    .select("id, delivery_fee_cents, delivered_at, restaurants(name)")
    .eq("driver_id", driver.id)
    .eq("status", "delivered")
    .order("delivered_at", { ascending: false })
    .limit(100);

  return (
    <div>
      <h1 className="text-xl font-bold text-slate-900">{t("Delivery history")}</h1>

      <div className="mt-6 overflow-hidden rounded-2xl bg-white shadow-sm ring-1 ring-slate-200">
        <table className="w-full text-left text-sm">
          <thead className="border-b border-slate-200 bg-slate-50 text-slate-500">
            <tr>
              <th className="px-4 py-3 font-medium">{t("Restaurant")}</th>
              <th className="px-4 py-3 font-medium">{t("Delivered at")}</th>
              <th className="px-4 py-3 font-medium">{t("Earned")}</th>
            </tr>
          </thead>
          <tbody>
            {(orders ?? []).map((order: any) => (
              <tr key={order.id} className="border-b border-slate-100 last:border-0">
                <td className="px-4 py-3 text-slate-900">{order.restaurants?.name}</td>
                <td className="px-4 py-3 text-slate-500">
                  {order.delivered_at ? formatDateTime(locale, order.delivered_at) : "—"}
                </td>
                <td className="px-4 py-3 font-medium text-slate-900">
                  {formatPrice(order.delivery_fee_cents)}
                </td>
              </tr>
            ))}
            {(orders ?? []).length === 0 && (
              <tr>
                <td colSpan={3} className="px-4 py-8 text-center text-slate-400">
                  {t("No deliveries completed yet.")}
                </td>
              </tr>
            )}
          </tbody>
        </table>
      </div>
    </div>
  );
}
