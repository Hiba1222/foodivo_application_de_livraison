"use client";

import { useI18n } from "@/lib/i18n/client";
import { describeSelection, formatPrice, type SelectionMode } from "@/lib/menu-options";
import type { OrderItemOptionRow } from "@/lib/order-items";

const MODE_ORDER: Record<SelectionMode, number> = { add: 0, extra: 1, remove: 2 };

/** Customizations under an order line: choices, then extras, then removals (in red, for the kitchen). */
export default function OrderItemOptions({
  options,
  notes,
}: {
  options?: OrderItemOptionRow[] | null;
  notes?: string | null;
}) {
  const { t } = useI18n();
  const sorted = [...(options ?? [])].sort((a, b) => MODE_ORDER[a.mode] - MODE_ORDER[b.mode]);
  if (sorted.length === 0 && !notes) return null;

  return (
    <ul className="ml-6 mt-0.5 space-y-0.5 text-xs">
      {sorted.map((o, idx) => (
        <li
          key={idx}
          className={
            o.mode === "remove"
              ? "font-semibold text-red-600"
              : o.mode === "extra"
              ? "font-semibold text-brand-700"
              : "text-slate-500"
          }
        >
          {describeSelection(o.mode, o.option_name, t)}
          {o.price_cents > 0 && <span className="font-normal text-slate-400"> (+{formatPrice(o.price_cents)})</span>}
        </li>
      ))}
      {notes && <li className="italic text-slate-500">&ldquo;{notes}&rdquo;</li>}
    </ul>
  );
}
