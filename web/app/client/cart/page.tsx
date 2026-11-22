"use client";

import { formatPrice, DELIVERY_FEE } from "@/lib/currency";
import Link from "next/link";
import { useCart } from "@/lib/cart-context";
import { useI18n } from "@/lib/i18n/client";
import { describeSelection } from "@/lib/menu-options";

export default function CartPage() {
  const { items, restaurantName, updateQuantity, removeItem, subtotalCents, clear, itemCount } = useCart();
  const { t } = useI18n();

  if (items.length === 0) {
    return (
      <div className="flex flex-col items-center py-20 text-center">
        <div className="relative">
          <span className="absolute inset-0 animate-ping rounded-full bg-brand-200/60" />
          <span className="relative flex h-24 w-24 animate-float items-center justify-center rounded-full bg-gradient-to-br from-brand-100 to-rose-100 text-5xl">
            🛒
          </span>
        </div>
        <h1 className="mt-6 text-xl font-extrabold text-slate-900">{t("Your cart is empty")}</h1>
        <p className="mt-1 text-sm text-slate-500">{t("Looks like you haven't added anything yet.")}</p>
        <Link href="/client" className="btn-primary mt-6 px-6">
          {t("Browse restaurants")} →
        </Link>
      </div>
    );
  }

  const qtyBtn =
    "flex h-8 w-8 items-center justify-center rounded-full text-base font-bold text-slate-700 hover:bg-white hover:shadow-sm";

  return (
    <div className="mx-auto max-w-2xl">
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-2xl font-extrabold text-slate-900">{t("Your cart")}</h1>
          <p className="mt-1 text-sm text-slate-500">
            {t(itemCount > 1 ? "{n} items from" : "{n} item from", { n: itemCount })}{" "}
            <span className="font-semibold text-slate-700">{restaurantName}</span>
          </p>
        </div>
        <button
          onClick={clear}
          className="rounded-lg px-3 py-1.5 text-sm font-semibold text-red-600 hover:bg-red-50"
        >
          {t("Clear cart")}
        </button>
      </div>

      <div className="stagger mt-6 space-y-3">
        {items.map((item, i) => (
          <div
            key={item.lineId}
            style={{ "--i": i } as React.CSSProperties}
            className="group flex items-start justify-between gap-4 rounded-2xl bg-white p-4 shadow-soft ring-1 ring-slate-200/70 transition hover:shadow-lift"
          >
            <div className="min-w-0">
              <p className="font-bold text-slate-900">{item.name}</p>
              {item.optionSummary.length > 0 && (
                <div className="mt-1.5 flex flex-wrap gap-1">
                  {item.optionSummary.map((o) => (
                    <span
                      key={`${o.mode}:${o.name}`}
                      className="rounded-full bg-slate-100 px-2 py-0.5 text-[11px] font-medium text-slate-600"
                    >
                      {describeSelection(o.mode, o.name, t)}
                    </span>
                  ))}
                </div>
              )}
              {item.notes && <p className="mt-1.5 text-xs italic text-slate-400">&ldquo;{item.notes}&rdquo;</p>}
              <p className="mt-2 text-sm">
                <span key={item.quantity} className="inline-block animate-fade-in font-extrabold text-slate-900">
                  {formatPrice(item.priceCents * item.quantity)}
                </span>
                {item.quantity > 1 && (
                  <span className="text-slate-400"> · {t("{price} each", { price: formatPrice(item.priceCents) })}</span>
                )}
              </p>
            </div>
            <div className="flex shrink-0 flex-col items-end gap-2">
              <div className="flex items-center rounded-full bg-slate-100 p-0.5">
                <button
                  onClick={() => updateQuantity(item.lineId, item.quantity - 1)}
                  aria-label={item.quantity === 1 ? t("Remove") : t("Decrease quantity")}
                  className={qtyBtn}
                >
                  {item.quantity === 1 ? "🗑" : "−"}
                </button>
                <span key={item.quantity} className="w-6 animate-pop text-center text-sm font-bold">
                  {item.quantity}
                </span>
                <button
                  onClick={() => updateQuantity(item.lineId, item.quantity + 1)}
                  aria-label={t("Increase quantity")}
                  className={qtyBtn}
                >
                  +
                </button>
              </div>
              <button
                onClick={() => removeItem(item.lineId)}
                className="text-xs font-semibold text-slate-400 opacity-100 hover:text-red-600 md:opacity-0 md:group-hover:opacity-100"
              >
                {t("Remove")}
              </button>
            </div>
          </div>
        ))}
      </div>

      <div className="mt-6 space-y-2 rounded-2xl bg-white p-5 shadow-soft ring-1 ring-slate-200/70">
        <div className="flex justify-between text-sm text-slate-600">
          <span>{t("Subtotal")}</span>
          <span>{formatPrice(subtotalCents)}</span>
        </div>
        <div className="flex justify-between text-sm text-slate-600">
          <span>🛵 {t("Delivery fee")}</span>
          <span>{formatPrice(DELIVERY_FEE)}</span>
        </div>
        <div className="flex justify-between border-t border-dashed border-slate-200 pt-3 text-lg font-extrabold text-slate-900">
          <span>{t("Total")}</span>
          <span key={subtotalCents} className="animate-fade-in">
            {formatPrice(subtotalCents + DELIVERY_FEE)}
          </span>
        </div>
      </div>

      <Link href="/client/checkout" className="btn-primary group mt-4 w-full py-3.5 text-base">
        {t("Proceed to checkout")}
        <span className="transition group-hover:translate-x-1">→</span>
      </Link>
    </div>
  );
}
