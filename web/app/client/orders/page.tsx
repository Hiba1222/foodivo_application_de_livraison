import { formatPrice } from "@/lib/currency";
import Link from "next/link";
import { createClient } from "@/lib/supabase/server";
import RealtimeRefresher from "@/components/RealtimeRefresher";
import { getLocale, getT } from "@/lib/i18n/server";
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

const ACTIVE = new Set(["pending", "accepted", "ready_for_pickup", "driver_assigned", "picked_up"]);

export default async function ClientOrdersPage() {
  const t = getT();
  const locale = getLocale();
  const supabase = createClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();

  const { data: orders } = await supabase
    .from("orders")
    .select("id, status, total_cents, created_at, restaurants(name)")
    .eq("client_id", user!.id)
    .order("created_at", { ascending: false });

  return (
    <div>
      <RealtimeRefresher table="orders" filter={`client_id=eq.${user!.id}`} />
      <h1 className="text-2xl font-extrabold text-slate-900">{t("My orders")}</h1>
      <p className="mt-1 text-sm text-slate-500">{t("Updates live as your order moves along.")}</p>

      <div className="stagger mt-6 space-y-3">
        {(orders ?? []).map((order: any, i: number) => (
          <Link
            key={order.id}
            href={`/client/orders/${order.id}`}
            style={{ "--i": i } as React.CSSProperties}
            className="card-hover group flex items-center justify-between gap-3 rounded-2xl bg-white p-4 shadow-soft ring-1 ring-slate-200/70"
          >
            <span
              className={`flex h-11 w-11 shrink-0 items-center justify-center rounded-xl text-xl transition duration-300 group-hover:scale-110 ${
                ACTIVE.has(order.status) ? "bg-brand-50" : "bg-slate-100"
              }`}
            >
              {order.status === "delivered" ? "✅" : order.status === "picked_up" ? "🛵" : ACTIVE.has(order.status) ? "🍳" : "🧾"}
            </span>
            <div className="min-w-0 flex-1">
              <p className="truncate font-bold text-slate-900 group-hover:text-brand-600">{order.restaurants?.name}</p>
              <p className="text-xs text-slate-500">
                {formatDateTime(locale, order.created_at)}
              </p>
            </div>
            <div className="flex items-center gap-3">
              <span className="text-sm font-semibold text-slate-900">
                {formatPrice(order.total_cents)}
              </span>
              <span
                className={`flex items-center gap-1.5 rounded-full px-2.5 py-1 text-xs font-semibold capitalize ${
                  STATUS_STYLES[order.status]
                }`}
              >
                {ACTIVE.has(order.status) && <span className="live-dot h-1.5 w-1.5 rounded-full bg-current" />}
                {statusLabel(t, order.status)}
              </span>
              <span className="text-slate-300 transition group-hover:translate-x-1 group-hover:text-brand-600">→</span>
            </div>
          </Link>
        ))}

        {(orders ?? []).length === 0 && (
          <div className="flex flex-col items-center py-16 text-center">
            <span className="animate-float text-5xl">🧾</span>
            <p className="mt-3 font-semibold text-slate-700">{t("No orders yet")}</p>
            <Link href="/client" className="btn-primary mt-4">
              {t("Find something tasty")} →
            </Link>
          </div>
        )}
      </div>
    </div>
  );
}
