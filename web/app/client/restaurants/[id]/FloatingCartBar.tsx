"use client";

import Link from "next/link";
import { useEffect, useState } from "react";
import { useCart } from "@/lib/cart-context";
import { formatPrice } from "@/lib/currency";
import { useI18n } from "@/lib/i18n/client";

/** Sticky "View cart" pill that slides up once the cart has items, and bounces on each add. */
export default function FloatingCartBar() {
  const { itemCount, subtotalCents, addTick } = useCart();
  const { t } = useI18n();
  const [bump, setBump] = useState(false);

  useEffect(() => {
    if (!addTick) return;
    setBump(true);
    const timer = setTimeout(() => setBump(false), 500);
    return () => clearTimeout(timer);
  }, [addTick]);

  if (itemCount === 0) return null;

  return (
    <div className="pointer-events-none fixed inset-x-0 bottom-20 z-40 flex justify-center px-4 md:bottom-6 md:pl-64">
      <Link
        href="/client/cart"
        className={`pointer-events-auto flex w-full max-w-md animate-sheet-up items-center gap-3 rounded-2xl bg-slate-900 px-4 py-3 text-white shadow-lift hover:-translate-y-1 hover:bg-black ${
          bump ? "animate-pop" : ""
        }`}
      >
        <span className="flex h-8 min-w-8 items-center justify-center rounded-lg bg-brand-600 px-2 text-sm font-bold">
          {itemCount}
        </span>
        <span className="flex-1 text-sm font-semibold">{t("View cart")}</span>
        <span className="text-sm font-bold">{formatPrice(subtotalCents)}</span>
        <span aria-hidden="true">→</span>
      </Link>
    </div>
  );
}
