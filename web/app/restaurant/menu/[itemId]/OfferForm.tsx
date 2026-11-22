"use client";

import { useEffect, useRef, useState } from "react";
import { useI18n } from "@/lib/i18n/client";
import { formatPrice, parsePrice, priceInputValue } from "@/lib/currency";
import { activeOffer } from "@/lib/offers";

const QUICK_PERCENTS = [10, 15, 20, 25, 30, 50];
const LABEL_SUGGESTIONS = ["Limited offer", "Deal of the day", "New", "Best seller"];

/** ISO -> value for <input type="datetime-local"> in the browser's timezone. */
function toLocalInput(iso: string | null) {
  if (!iso) return "";
  const d = new Date(iso);
  const pad = (n: number) => String(n).padStart(2, "0");
  return `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())}T${pad(d.getHours())}:${pad(d.getMinutes())}`;
}

export default function OfferForm({
  priceCents,
  current,
  action,
  clearAction,
}: {
  priceCents: number;
  current: {
    offer_price_cents: number | null;
    offer_label: string | null;
    offer_ends_at: string | null;
    is_featured: boolean;
  };
  action: (formData: FormData) => Promise<{ error?: string }>;
  clearAction: () => Promise<void>;
}) {
  const { t, locale } = useI18n();
  const [offerPrice, setOfferPrice] = useState(
    current.offer_price_cents != null ? priceInputValue(current.offer_price_cents) : ""
  );
  const [label, setLabel] = useState(current.offer_label ?? "");
  const [endsLocal, setEndsLocal] = useState("");
  const [featured, setFeatured] = useState(current.is_featured);
  const [pending, setPending] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [saved, setSaved] = useState(false);
  const savedTimer = useRef<ReturnType<typeof setTimeout>>();

  // Timezone-dependent, so fill it in after mount (avoids hydration mismatch).
  useEffect(() => setEndsLocal(toLocalInput(current.offer_ends_at)), [current.offer_ends_at]);
  useEffect(() => () => clearTimeout(savedTimer.current), []);

  const offerCents = offerPrice ? parsePrice(offerPrice) : null;
  const invalid = offerCents !== null && (offerCents <= 0 || offerCents >= priceCents);
  const percent = offerCents && !invalid ? Math.round((1 - offerCents / priceCents) * 100) : 0;

  const live = activeOffer({ price_cents: priceCents, ...current });
  const expired =
    current.offer_price_cents != null && current.offer_ends_at && new Date(current.offer_ends_at) <= new Date();
  const hasAnything = current.offer_price_cents != null || current.is_featured || !!current.offer_label;

  function applyPercent(p: number) {
    // Round to 100 millimes so prices stay clean (e.g. 8.500 TND).
    const cents = Math.max(100, Math.round((priceCents * (1 - p / 100)) / 100) * 100);
    setOfferPrice(priceInputValue(cents));
  }

  async function submit(fd: FormData) {
    if (invalid) return;
    setPending(true);
    setError(null);
    fd.set("offer_ends_at", endsLocal ? new Date(endsLocal).toISOString() : "");
    const res = await action(fd);
    setPending(false);
    if (res?.error) return setError(res.error);
    setSaved(true);
    clearTimeout(savedTimer.current);
    savedTimer.current = setTimeout(() => setSaved(false), 2000);
  }

  async function remove() {
    setPending(true);
    setError(null);
    await clearAction();
    setOfferPrice("");
    setLabel("");
    setEndsLocal("");
    setFeatured(false);
    setPending(false);
  }

  const chip = (active: boolean) =>
    `rounded-full px-3 py-1 text-xs font-bold ring-1 transition hover:-translate-y-0.5 ${
      active ? "bg-rose-600 text-white ring-rose-600 shadow-md" : "bg-white text-rose-700 ring-rose-200 hover:bg-rose-50"
    }`;

  return (
    <section className="mt-6 overflow-hidden rounded-2xl bg-white shadow-soft ring-1 ring-rose-200/70">
      <div className="flex flex-wrap items-center justify-between gap-2 bg-gradient-to-r from-rose-500 via-brand-500 to-amber-400 px-5 py-3 text-white">
        <h2 className="flex items-center gap-2 text-sm font-extrabold">
          <span className="text-lg">🔥</span> {t("Promotion")}
        </h2>
        <span className="rounded-full bg-white/25 px-2.5 py-0.5 text-xs font-bold backdrop-blur">
          {live && live.percentOff > 0
            ? t("Live · -{p}%", { p: live.percentOff })
            : live?.featured
            ? t("Featured")
            : expired
            ? t("Ended")
            : t("No offer")}
        </span>
      </div>

      <form action={submit} className="space-y-5 p-5">
        <div>
          <label className="text-sm font-semibold text-slate-800">{t("Discount")}</label>
          <p className="text-xs text-slate-500">
            {t("Normal price {price}. Pick a quick discount or type the new price.", {
              price: formatPrice(priceCents),
            })}
          </p>
          <div className="mt-2 flex flex-wrap gap-2">
            {QUICK_PERCENTS.map((p) => (
              <button key={p} type="button" onClick={() => applyPercent(p)} className={chip(percent === p)}>
                -{p}%
              </button>
            ))}
          </div>
          <div className="mt-3 flex flex-wrap items-center gap-3">
            <div className="relative">
              <input
                name="offer_price"
                type="number"
                step="0.001"
                min="0"
                value={offerPrice}
                onChange={(e) => setOfferPrice(e.target.value)}
                placeholder={t("Offer price")}
                className={`w-40 rounded-lg border px-3 py-2 pr-12 text-sm ${invalid ? "border-red-400" : "border-slate-300"}`}
              />
              <span className="pointer-events-none absolute right-3 top-1/2 -translate-y-1/2 text-xs font-semibold text-slate-400">
                TND
              </span>
            </div>
            {offerCents !== null && !invalid && (
              <span key={offerCents} className="flex animate-fade-in items-center gap-2 text-sm">
                <span className="text-slate-400 line-through">{formatPrice(priceCents)}</span>
                <span className="font-extrabold text-rose-600">{formatPrice(offerCents)}</span>
                <span className="animate-pop rounded-full bg-rose-600 px-2 py-0.5 text-xs font-bold text-white">
                  -{percent}%
                </span>
              </span>
            )}
            {offerPrice && (
              <button
                type="button"
                onClick={() => setOfferPrice("")}
                className="text-xs font-semibold text-slate-400 hover:text-slate-700"
              >
                {t("No discount")}
              </button>
            )}
          </div>
          {invalid && (
            <p className="mt-1 text-xs font-medium text-red-600">
              {t("The offer price must be lower than the normal price.")}
            </p>
          )}
        </div>

        <div className="grid gap-4 sm:grid-cols-2">
          <div>
            <label className="text-sm font-semibold text-slate-800">{t("Offer label (optional)")}</label>
            <input
              name="offer_label"
              value={label}
              maxLength={40}
              onChange={(e) => setLabel(e.target.value)}
              placeholder={t("e.g. Ramadan promo")}
              className="mt-1 w-full rounded-lg border border-slate-300 px-3 py-2 text-sm"
            />
            <div className="mt-2 flex flex-wrap gap-1.5">
              {LABEL_SUGGESTIONS.map((s) => (
                <button
                  key={s}
                  type="button"
                  onClick={() => setLabel(t(s))}
                  className="rounded-full bg-slate-100 px-2.5 py-0.5 text-[11px] font-semibold text-slate-600 hover:bg-slate-200"
                >
                  {t(s)}
                </button>
              ))}
            </div>
          </div>
          <div>
            <label className="text-sm font-semibold text-slate-800">{t("Ends on (optional)")}</label>
            <input
              type="datetime-local"
              value={endsLocal}
              lang={locale}
              onChange={(e) => setEndsLocal(e.target.value)}
              className="mt-1 w-full rounded-lg border border-slate-300 px-3 py-2 text-sm"
            />
            <p className="mt-1 text-xs text-slate-400">{t("Leave empty to keep the offer until you remove it.")}</p>
          </div>
        </div>

        <label className="flex cursor-pointer items-start gap-3 rounded-xl bg-amber-50 p-3 ring-1 ring-amber-200">
          <input
            type="checkbox"
            name="is_featured"
            checked={featured}
            onChange={(e) => setFeatured(e.target.checked)}
            className="mt-0.5 h-4 w-4 accent-brand-600"
          />
          <span>
            <span className="block text-sm font-semibold text-slate-900">⭐ {t("Feature in Special offers")}</span>
            <span className="block text-xs text-slate-600">
              {t("Shows this dish in the highlighted section at the top of your menu and in Hot deals — great for combos.")}
            </span>
          </span>
        </label>

        {error && <p className="animate-shake text-sm font-medium text-red-600">{error}</p>}

        <div className="flex flex-wrap items-center gap-3">
          <button type="submit" disabled={pending || invalid} className="btn-primary">
            {pending ? t("Saving…") : t("Save offer")}
          </button>
          {hasAnything && (
            <button
              type="button"
              onClick={remove}
              disabled={pending}
              className="rounded-xl px-4 py-2.5 text-sm font-semibold text-red-600 hover:bg-red-50 disabled:opacity-50"
            >
              {t("Remove offer")}
            </button>
          )}
          {saved && <span className="animate-pop text-sm font-semibold text-green-600">✓ {t("Saved")}</span>}
        </div>
      </form>
    </section>
  );
}
