import { createClient } from "@/lib/supabase/server";
import { formatPrice } from "@/lib/currency";
import { ORDER_ITEMS_SELECT } from "@/lib/order-items";
import { redirect } from "next/navigation";
import InvoiceActions from "./InvoiceActions";

function orderTag(id: string) {
  return id.slice(0, 8).toUpperCase();
}

function fmtDate(iso: string) {
  return new Date(iso).toLocaleDateString("en-GB", { year: "numeric", month: "long", day: "numeric" });
}

export default async function InvoicePage({ params }: { params: { orderId: string } }) {
  const supabase = createClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();
  if (!user) redirect("/login");

  const { data: order } = await supabase
    .from("orders")
    .select(
      `id, status, subtotal_cents, delivery_fee_cents, total_cents,
       created_at, delivered_at, payment_method, payment_status, notes,
       restaurants(name, address),
       profiles!orders_client_id_fkey(full_name),
       client_addresses(address_line),
       ${ORDER_ITEMS_SELECT}`
    )
    .eq("id", params.orderId)
    .eq("client_id", user.id)
    .single();

  if (!order) redirect("/client/orders");

  const restaurant = order.restaurants as any;
  const client = order.profiles as any;
  const address = order.client_addresses as any;
  const items = (order as any).order_items ?? [];

  return (
    <div className="min-h-screen bg-white">
      {/* Actions bar — hidden when printing */}
      <div className="print:hidden sticky top-0 z-10 flex items-center justify-between border-b border-slate-100 bg-white px-6 py-3 shadow-sm">
        <a href={`/client/orders/${order.id}`} className="text-sm text-slate-500 hover:text-slate-700">
          ← Back to order
        </a>
        <InvoiceActions orderId={order.id} />
      </div>

      {/* Invoice body */}
      <div className="mx-auto max-w-2xl px-8 py-10 print:py-6">
        {/* Header */}
        <div className="flex items-start justify-between border-b-2 border-slate-200 pb-6">
          <div>
            <p className="text-2xl font-black text-brand-600">Foodivo</p>
            <p className="text-xs text-slate-400">Food delivery platform</p>
          </div>
          <div className="text-right">
            <p className="text-lg font-bold text-slate-900">INV-{orderTag(order.id)}</p>
            <p className="text-sm text-slate-500">Issued: {fmtDate(order.created_at)}</p>
            {order.delivered_at && (
              <p className="text-sm text-slate-500">Delivered: {fmtDate(order.delivered_at)}</p>
            )}
          </div>
        </div>

        {/* Parties */}
        <div className="mt-6 grid grid-cols-2 gap-6">
          <div>
            <p className="text-xs font-semibold uppercase tracking-wide text-slate-400">From</p>
            <p className="mt-1 font-semibold text-slate-900">{restaurant?.name ?? "—"}</p>
            {restaurant?.address && (
              <p className="text-sm text-slate-500">{restaurant.address}</p>
            )}
          </div>
          <div>
            <p className="text-xs font-semibold uppercase tracking-wide text-slate-400">Bill to</p>
            <p className="mt-1 font-semibold text-slate-900">{client?.full_name ?? "—"}</p>
            {address?.address_line && (
              <p className="text-sm text-slate-500">{address.address_line}</p>
            )}
          </div>
        </div>

        {/* Items table */}
        <div className="mt-8">
          <table className="w-full text-sm">
            <thead>
              <tr className="border-b-2 border-slate-200 text-xs uppercase tracking-wide text-slate-400">
                <th className="pb-2 text-left">Item</th>
                <th className="pb-2 text-right">Qty</th>
                <th className="pb-2 text-right">Unit price</th>
                <th className="pb-2 text-right">Line total</th>
              </tr>
            </thead>
            <tbody>
              {items.map((oi: any, i: number) => (
                <tr key={i} className="border-b border-slate-100">
                  <td className="py-2.5 text-slate-900">
                    {oi.menu_items?.name}
                    {oi.notes && (
                      <span className="ml-1 text-xs text-slate-400">({oi.notes})</span>
                    )}
                    {(oi.order_item_options ?? []).length > 0 && (
                      <ul className="mt-0.5 text-xs text-slate-400">
                        {oi.order_item_options.map((opt: any, j: number) => (
                          <li key={j}>
                            {opt.mode === "remove" ? "No " : opt.mode === "extra" ? "Extra " : ""}
                            {opt.option_name}
                            {opt.price_cents > 0 && ` +${formatPrice(opt.price_cents)}`}
                          </li>
                        ))}
                      </ul>
                    )}
                  </td>
                  <td className="py-2.5 text-right text-slate-500">{oi.quantity}</td>
                  <td className="py-2.5 text-right text-slate-500">{formatPrice(oi.unit_price_cents)}</td>
                  <td className="py-2.5 text-right font-medium text-slate-900">
                    {formatPrice(oi.quantity * oi.unit_price_cents)}
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>

        {/* Totals */}
        <div className="mt-4 flex justify-end">
          <div className="w-56 space-y-2 text-sm">
            <div className="flex justify-between text-slate-500">
              <span>Subtotal</span>
              <span>{formatPrice(order.subtotal_cents)}</span>
            </div>
            <div className="flex justify-between text-slate-500">
              <span>Delivery fee</span>
              <span>{formatPrice(order.delivery_fee_cents)}</span>
            </div>
            <div className="flex justify-between border-t-2 border-slate-200 pt-2 text-base font-bold text-slate-900">
              <span>Total</span>
              <span>{formatPrice(order.total_cents)}</span>
            </div>
          </div>
        </div>

        {/* Payment info */}
        <div className="mt-6 rounded-xl bg-slate-50 px-4 py-3 text-sm ring-1 ring-slate-100">
          <div className="flex gap-8">
            <div>
              <p className="text-xs text-slate-400">Payment method</p>
              <p className="mt-0.5 font-medium capitalize text-slate-700">{order.payment_method}</p>
            </div>
            <div>
              <p className="text-xs text-slate-400">Payment status</p>
              <p
                className={`mt-0.5 font-medium capitalize ${
                  order.payment_status === "paid" ? "text-green-600" : "text-amber-600"
                }`}
              >
                {order.payment_status}
              </p>
            </div>
          </div>
        </div>

        {order.notes && (
          <div className="mt-4 text-sm">
            <p className="text-xs text-slate-400">Order notes</p>
            <p className="mt-0.5 text-slate-600">{order.notes}</p>
          </div>
        )}

        <div className="mt-10 border-t border-slate-100 pt-4 text-center text-xs text-slate-400">
          Thank you for ordering with Foodivo · This is your official receipt
        </div>
      </div>
    </div>
  );
}
