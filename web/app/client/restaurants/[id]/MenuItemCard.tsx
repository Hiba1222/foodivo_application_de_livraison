"use client";

import { useCallback, useEffect, useState } from "react";
import { useCart } from "@/lib/cart-context";
import { formatPrice, type MenuOptionGroup } from "@/lib/menu-options";
import { activeOffer, type OfferFields } from "@/lib/offers";
import ItemCustomizer, { type CustomizedLine } from "@/components/ItemCustomizer";
import OfferCountdown from "@/components/OfferCountdown";
import Toast from "@/components/Toast";
import { useI18n } from "@/lib/i18n/client";

export interface MenuCardItem extends OfferFields {
  id: string;
  name: string;
  description: string | null;
  price_cents: number;
  image_url?: string | null;
}

export default function MenuItemCard({
  restaurantId,
  restaurantName,
  item,
  groups,
  variant = "row",
}: {
  restaurantId: string;
  restaurantName: string;
  item: MenuCardItem;
  /** Sorted, available-only option groups for this item. */
  groups: MenuOptionGroup[];
  /** "spotlight" = big card for the Special offers section. */
  variant?: "row" | "spotlight";
}) {
  const { addItem } = useCart();
  const { t } = useI18n();
  const [open, setOpen] = useState(false);
  const [justAdded, setJustAdded] = useState<number | null>(null);
  const close = useCallback(() => setOpen(false), []);

  useEffect(() => {
    if (justAdded === null) return;
    const timer = setTimeout(() => setJustAdded(null), 2200);
    return () => clearTimeout(timer);
  }, [justAdded]);

  const offer = activeOffer(item);
  const discounted = !!offer && offer.percentOff > 0;
  const basePrice = offer ? offer.priceCents : item.price_cents;

  function handleAdd(line: CustomizedLine) {
    const added = addItem(
      restaurantId,
      restaurantName,
      {
        menuItemId: item.id,
        name: item.name,
        priceCents: line.unitPriceCents,
        selections: line.selections,
        optionSummary: line.priced.map((p) => ({ mode: p.mode, name: p.optionName })),
        notes: line.notes,
      },
      line.quantity
    );
    if (added) {
      setOpen(false);
      setJustAdded(line.quantity);
    }
  }

  const customizable = groups.length > 0;

  const priceBlock = (
    <div className="flex flex-wrap items-center gap-2">
      <span
        className={`font-extrabold ${discounted ? "text-rose-600" : "text-slate-900"} ${
          variant === "spotlight" ? "text-lg" : "text-sm"
        }`}
      >
        {formatPrice(basePrice)}
      </span>
      {discounted && <span className="text-xs text-slate-400 line-through">{formatPrice(item.price_cents)}</span>}
      {customizable && variant === "row" && (
        <span className="rounded-full bg-brand-50 px-2 py-0.5 text-[11px] font-semibold text-brand-700">
          ✨ {t("Customizable")}
        </span>
      )}
    </div>
  );

  const addBadge = (
    <span
      key={justAdded ?? "idle"}
      className={`flex h-9 min-w-9 items-center justify-center rounded-full px-2 text-base font-bold shadow-md ring-2 ring-white transition duration-300 ${
        justAdded !== null
          ? "animate-pop bg-green-600 text-white"
          : discounted
          ? "bg-rose-600 text-white group-hover:rotate-90"
          : "bg-slate-900 text-white group-hover:rotate-90 group-hover:bg-brand-600"
      }`}
    >
      {justAdded !== null ? "✓" : "+"}
    </span>
  );

  const offerTag = offer?.label ? (
    <>🔥 {offer.label}</>
  ) : offer?.featured ? (
    <>⭐ {t("Special offer")}</>
  ) : null;

  return (
    <>
      {variant === "spotlight" ? (
        <button
          type="button"
          onClick={() => setOpen(true)}
          className="offer-glow group relative flex h-full w-64 shrink-0 snap-start flex-col overflow-hidden rounded-3xl bg-white text-left shadow-lift transition duration-300 hover:-translate-y-1.5 sm:w-72"
        >
          <div className="relative h-40 w-full overflow-hidden bg-gradient-to-br from-rose-100 to-amber-100">
            {item.image_url ? (
              // eslint-disable-next-line @next/next/no-img-element
              <img
                src={item.image_url}
                alt={item.name}
                className="h-full w-full object-cover transition duration-700 group-hover:scale-110"
              />
            ) : (
              <div className="flex h-full items-center justify-center text-6xl">🍽️</div>
            )}
            <div className="absolute inset-0 bg-gradient-to-t from-black/50 via-transparent to-transparent" />
            {discounted && (
              <span className="absolute right-3 top-3 flex h-14 w-14 rotate-12 items-center justify-center rounded-full bg-gradient-to-br from-rose-500 to-red-600 text-base font-black text-white shadow-lg ring-4 ring-white/70 transition duration-300 group-hover:rotate-0 group-hover:scale-110">
                -{offer!.percentOff}%
              </span>
            )}
            <div className="absolute bottom-3 left-3 right-3 flex flex-wrap gap-1.5">
              {offerTag && (
                <span className="rounded-full bg-amber-400 px-2.5 py-0.5 text-[11px] font-black uppercase tracking-wide text-amber-950 shadow">
                  {offerTag}
                </span>
              )}
              {offer?.endsAt && <OfferCountdown endsAt={offer.endsAt} />}
            </div>
          </div>
          <div className="flex flex-1 flex-col p-4">
            <p className="font-extrabold text-slate-900 transition group-hover:text-rose-600">{item.name}</p>
            {item.description && <p className="mt-1 line-clamp-2 text-xs text-slate-500">{item.description}</p>}
            <div className="mt-auto flex items-end justify-between gap-2 pt-3">
              {priceBlock}
              {addBadge}
            </div>
          </div>
        </button>
      ) : (
        <button
          type="button"
          onClick={() => setOpen(true)}
          className={`group relative flex h-full w-full items-center justify-between gap-4 overflow-hidden rounded-2xl bg-white p-4 text-left shadow-soft transition duration-300 hover:-translate-y-0.5 hover:shadow-lift ${
            justAdded !== null
              ? "ring-2 ring-green-500"
              : discounted
              ? "bg-gradient-to-r from-rose-50/80 to-white ring-2 ring-rose-300 hover:ring-rose-400"
              : "ring-1 ring-slate-200/70 hover:ring-brand-200"
          }`}
        >
          {discounted && (
            <span className="pointer-events-none absolute -left-9 top-4 w-32 -rotate-45 bg-gradient-to-r from-rose-500 to-red-600 py-0.5 text-center text-[10px] font-black text-white shadow">
              -{offer!.percentOff}%
            </span>
          )}
          <div className={`min-w-0 flex-1 ${discounted ? "pl-5" : ""}`}>
            <p className="font-bold text-slate-900 transition group-hover:text-brand-600">{item.name}</p>
            {(offerTag || offer?.endsAt) && (
              <div className="mt-1 flex flex-wrap gap-1.5">
                {offerTag && (
                  <span className="rounded-full bg-amber-100 px-2 py-0.5 text-[11px] font-bold text-amber-800">
                    {offerTag}
                  </span>
                )}
                {offer?.endsAt && <OfferCountdown endsAt={offer.endsAt} />}
              </div>
            )}
            {item.description && <p className="mt-1 line-clamp-2 text-sm text-slate-500">{item.description}</p>}
            <div className="mt-2">{priceBlock}</div>
          </div>
          <div className="relative shrink-0">
            {item.image_url ? (
              <div className="h-24 w-24 overflow-hidden rounded-xl">
                {/* eslint-disable-next-line @next/next/no-img-element */}
                <img
                  src={item.image_url}
                  alt={item.name}
                  className="h-full w-full object-cover transition duration-500 group-hover:scale-110"
                />
              </div>
            ) : (
              <div className="h-12 w-12" />
            )}
            <span className="absolute -bottom-2 -right-2">{addBadge}</span>
          </div>
        </button>
      )}

      {open && (
        <ItemCustomizer
          item={{
            ...item,
            price_cents: basePrice,
            original_price_cents: discounted ? item.price_cents : null,
            offer_label: offer?.label ?? null,
          }}
          groups={groups}
          onClose={close}
          onAdd={handleAdd}
        />
      )}
      {justAdded !== null && (
        <Toast>
          <span className="text-green-400">✓</span>{" "}
          {t("Added {item} to your cart", { item: justAdded > 1 ? `${justAdded} × ${item.name}` : item.name })}
        </Toast>
      )}
    </>
  );
}
