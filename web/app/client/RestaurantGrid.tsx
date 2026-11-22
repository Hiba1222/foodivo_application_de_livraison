"use client";

import Link from "next/link";
import { useMemo, useState } from "react";
import { useI18n } from "@/lib/i18n/client";

interface Restaurant {
  id: string;
  name: string;
  description: string | null;
  cuisine_type: string | null;
  address: string | null;
  is_open: boolean;
  avg_prep_time_minutes: number | null;
  logo_url: string | null;
  cover_image_url: string | null;
}

export interface RestaurantDeal {
  count: number;
  /** Biggest live discount at this restaurant (0 = featured offers only). */
  bestPercent: number;
}

export default function RestaurantGrid({
  restaurants,
  deals = {},
}: {
  restaurants: Restaurant[];
  deals?: Record<string, RestaurantDeal>;
}) {
  const { t } = useI18n();
  const [query, setQuery] = useState("");
  const [cuisine, setCuisine] = useState<string | null>(null);
  const [openOnly, setOpenOnly] = useState(false);
  const [dealsOnly, setDealsOnly] = useState(false);

  const cuisines = useMemo(
    () => Array.from(new Set(restaurants.map((r) => r.cuisine_type).filter(Boolean))) as string[],
    [restaurants]
  );

  const q = query.trim().toLowerCase();
  const filtered = restaurants.filter((r) => {
    if (q && !`${r.name} ${r.cuisine_type ?? ""} ${r.description ?? ""}`.toLowerCase().includes(q))
      return false;
    if (cuisine && r.cuisine_type !== cuisine) return false;
    if (openOnly && !r.is_open) return false;
    if (dealsOnly && !deals[r.id]) return false;
    return true;
  });

  const chip = (active: boolean) =>
    `shrink-0 rounded-full px-4 py-1.5 text-sm font-semibold ring-1 transition ${
      active
        ? "bg-slate-900 text-white ring-slate-900 shadow-md"
        : "bg-white text-slate-600 ring-slate-200 hover:-translate-y-0.5 hover:ring-slate-300"
    }`;

  function resetFilters() {
    setQuery("");
    setCuisine(null);
    setOpenOnly(false);
    setDealsOnly(false);
  }

  return (
    <div className="mt-6">
      <div className="relative">
        <svg
          viewBox="0 0 24 24"
          fill="none"
          stroke="currentColor"
          strokeWidth={2}
          className="pointer-events-none absolute left-4 top-1/2 h-5 w-5 -translate-y-1/2 text-slate-400"
          aria-hidden="true"
        >
          <path strokeLinecap="round" d="m21 21-5.2-5.2m0 0A7.5 7.5 0 1 0 5.2 5.2a7.5 7.5 0 0 0 10.6 10.6Z" />
        </svg>
        <input
          value={query}
          onChange={(e) => setQuery(e.target.value)}
          placeholder={t("Search restaurants, cuisines…")}
          className="w-full rounded-2xl border border-slate-200 bg-white py-3.5 pl-12 pr-4 text-sm shadow-soft"
        />
      </div>

      <div className="-mx-1 mt-4 flex gap-2 overflow-x-auto px-1 pb-1">
        <button type="button" className={chip(!cuisine)} onClick={() => setCuisine(null)}>
          {t("All")}
        </button>
        {cuisines.map((c) => (
          <button
            key={c}
            type="button"
            className={chip(cuisine === c)}
            onClick={() => setCuisine(cuisine === c ? null : c)}
          >
            {c}
          </button>
        ))}
        <button type="button" className={chip(openOnly)} onClick={() => setOpenOnly((v) => !v)}>
          <span className="mr-1.5 inline-block h-2 w-2 rounded-full bg-green-500" />
          {t("Open now")}
        </button>
        {Object.keys(deals).length > 0 && (
          <button
            type="button"
            className={
              dealsOnly
                ? "shrink-0 rounded-full bg-gradient-to-r from-rose-600 to-amber-500 px-4 py-1.5 text-sm font-semibold text-white shadow-md ring-1 ring-rose-600"
                : chip(false)
            }
            onClick={() => setDealsOnly((v) => !v)}
          >
            🔥 {t("Deals")}
          </button>
        )}
      </div>

      {/* Re-keyed on filter change so the cards replay their entrance. */}
      <div
        key={`${q}|${cuisine}|${openOnly}|${dealsOnly}`}
        className="stagger mt-6 grid grid-cols-1 gap-5 sm:grid-cols-2 lg:grid-cols-3"
      >
        {filtered.map((r, i) => (
          <Link
            key={r.id}
            href={`/client/restaurants/${r.id}`}
            style={{ "--i": i } as React.CSSProperties}
            className={`card-hover group block overflow-hidden rounded-3xl bg-white shadow-soft ring-1 ring-slate-200/70 ${
              !r.is_open ? "opacity-70 grayscale-[40%]" : ""
            }`}
          >
            <div className="relative aspect-[16/9] w-full overflow-hidden bg-gradient-to-br from-brand-100 to-rose-100">
              {r.cover_image_url ? (
                // eslint-disable-next-line @next/next/no-img-element
                <img
                  src={r.cover_image_url}
                  alt={r.name}
                  className="h-full w-full object-cover transition duration-700 ease-out group-hover:scale-110"
                />
              ) : (
                <div className="flex h-full items-center justify-center text-5xl transition duration-500 group-hover:rotate-6 group-hover:scale-125">
                  🍽️
                </div>
              )}
              <div className="absolute inset-0 bg-gradient-to-t from-black/40 via-transparent to-transparent opacity-0 transition duration-300 group-hover:opacity-100" />
              <span
                className={`absolute left-3 top-3 flex items-center gap-1.5 rounded-full px-2.5 py-1 text-xs font-bold shadow backdrop-blur ${
                  r.is_open ? "bg-white/90 text-green-700" : "bg-slate-900/70 text-white"
                }`}
              >
                <span className={`h-2 w-2 rounded-full ${r.is_open ? "live-dot bg-green-500" : "bg-slate-400"}`} />
                {r.is_open ? t("Open") : t("Closed")}
              </span>
              {deals[r.id] && (
                <span className="shine absolute right-3 top-3 flex items-center gap-1 rounded-full bg-gradient-to-r from-rose-600 to-amber-500 px-2.5 py-1 text-xs font-black text-white shadow-lg">
                  🔥{" "}
                  {deals[r.id].bestPercent > 0
                    ? t("Up to -{p}%", { p: deals[r.id].bestPercent })
                    : t(deals[r.id].count > 1 ? "{n} offers" : "{n} offer", { n: deals[r.id].count })}
                </span>
              )}
              {r.avg_prep_time_minutes != null && (
                <span className="absolute bottom-3 right-3 rounded-full bg-white/90 px-2.5 py-1 text-xs font-bold text-slate-800 shadow backdrop-blur">
                  ⏱ {r.avg_prep_time_minutes} min
                </span>
              )}
            </div>
            <div className="p-5">
              <div className="flex items-center gap-3">
                {r.logo_url && (
                  // eslint-disable-next-line @next/next/no-img-element
                  <img
                    src={r.logo_url}
                    alt=""
                    className="-mt-10 h-12 w-12 rounded-2xl border-4 border-white object-cover shadow-md transition duration-300 group-hover:-rotate-6"
                  />
                )}
                <div className="min-w-0">
                  <p className="truncate font-bold text-slate-900 transition group-hover:text-brand-600">{r.name}</p>
                  {r.cuisine_type && <p className="text-xs font-medium text-brand-600">{r.cuisine_type}</p>}
                </div>
                <span className="ml-auto flex h-8 w-8 shrink-0 items-center justify-center rounded-full bg-slate-100 text-slate-500 transition duration-300 group-hover:translate-x-1 group-hover:bg-brand-600 group-hover:text-white">
                  →
                </span>
              </div>
              {r.description && <p className="mt-3 line-clamp-2 text-sm text-slate-600">{r.description}</p>}
              {r.address && <p className="mt-3 truncate text-xs text-slate-400">📍 {r.address}</p>}
            </div>
          </Link>
        ))}

        {filtered.length === 0 && (
          <div className="col-span-full flex flex-col items-center py-16 text-center">
            <span className="animate-wiggle text-5xl">🔍</span>
            <p className="mt-3 font-semibold text-slate-700">
              {restaurants.length === 0 ? t("No restaurants available yet.") : t("No restaurants match your search.")}
            </p>
            {restaurants.length > 0 && (
              <button
                type="button"
                onClick={resetFilters}
                className="mt-3 text-sm font-semibold text-brand-600 hover:underline"
              >
                {t("Clear filters")}
              </button>
            )}
          </div>
        )}
      </div>
    </div>
  );
}
