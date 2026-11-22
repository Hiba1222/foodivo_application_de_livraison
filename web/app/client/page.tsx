import Link from "next/link";
import { createClient } from "@/lib/supabase/server";
import RestaurantGrid, { type RestaurantDeal } from "./RestaurantGrid";
import { getT } from "@/lib/i18n/server";
import { formatPrice } from "@/lib/currency";
import { OFFER_FIELDS, activeOffer } from "@/lib/offers";

export default async function ClientBrowsePage() {
  const t = getT();
  const supabase = createClient();
  const [{ data: restaurants }, { data: offerRows }] = await Promise.all([
    supabase
      .from("restaurants")
      .select(
        "id, name, description, cuisine_type, address, is_open, avg_prep_time_minutes, logo_url, cover_image_url"
      )
      .eq("is_approved", true)
      .order("name"),
    supabase
      .from("menu_items")
      .select(`id, name, price_cents, ${OFFER_FIELDS}, image_url, restaurant_id`)
      .eq("is_available", true)
      .or("offer_price_cents.not.is.null,is_featured.eq.true"),
  ]);

  // Only live offers from approved restaurants.
  const byId = new Map((restaurants ?? []).map((r) => [r.id as string, r]));
  const deals = (offerRows ?? [])
    .map((item: any) => ({ item, offer: activeOffer(item), restaurant: byId.get(item.restaurant_id) }))
    .filter((d) => d.offer && d.restaurant)
    .sort((a, b) => b.offer!.percentOff - a.offer!.percentOff);

  const dealsByRestaurant: Record<string, RestaurantDeal> = {};
  for (const d of deals) {
    const cur = dealsByRestaurant[d.item.restaurant_id] ?? { count: 0, bestPercent: 0 };
    dealsByRestaurant[d.item.restaurant_id] = {
      count: cur.count + 1,
      bestPercent: Math.max(cur.bestPercent, d.offer!.percentOff),
    };
  }

  return (
    <div>
      <section className="relative overflow-hidden rounded-3xl bg-gradient-to-br from-brand-500 via-brand-600 to-rose-500 px-6 py-8 text-white shadow-glow sm:px-10 sm:py-10">
        <div className="pointer-events-none absolute -right-10 -top-16 h-56 w-56 animate-float rounded-full bg-white/15 blur-2xl" />
        <div className="pointer-events-none absolute -bottom-20 left-1/3 h-48 w-48 animate-float-slow rounded-full bg-yellow-300/25 blur-2xl" />
        <div className="pointer-events-none absolute right-8 top-1/2 hidden -translate-y-1/2 select-none text-7xl sm:block">
          <span className="inline-block animate-float">🍕</span>
          <span className="ml-2 inline-block animate-float-slow">🌮</span>
        </div>
        <p className="relative text-sm font-medium text-white/80">{t("Hungry?")} 👋</p>
        <h1 className="relative mt-1 text-2xl font-extrabold sm:text-3xl">{t("What are you craving today?")}</h1>
        <p className="relative mt-2 max-w-md text-sm text-white/85">
          {t("Order from the best restaurants near you. Delivered hot, fast.")}
        </p>
      </section>

      {deals.length > 0 && (
        <section className="mt-6">
          <div className="flex items-end justify-between">
            <h2 className="flex items-center gap-2 text-lg font-black text-slate-900">
              <span className="inline-block animate-wiggle">🔥</span> {t("Hot deals")}
            </h2>
            <span className="text-xs font-semibold text-slate-400">{t("Swipe for more →")}</span>
          </div>
          <div className="stagger -mx-4 mt-3 flex snap-x gap-4 overflow-x-auto px-4 pb-4 pt-1 md:mx-0 md:px-1">
            {deals.slice(0, 12).map(({ item, offer, restaurant }, i) => (
              <Link
                key={item.id}
                href={`/client/restaurants/${item.restaurant_id}`}
                style={{ "--i": i } as React.CSSProperties}
                className="offer-glow group relative w-56 shrink-0 snap-start overflow-hidden rounded-3xl bg-white transition duration-300 hover:-translate-y-1.5"
              >
                <div className="relative h-32 overflow-hidden bg-gradient-to-br from-rose-100 to-amber-100">
                  {item.image_url ? (
                    // eslint-disable-next-line @next/next/no-img-element
                    <img
                      src={item.image_url}
                      alt={item.name}
                      className="h-full w-full object-cover transition duration-700 group-hover:scale-110"
                    />
                  ) : (
                    <div className="flex h-full items-center justify-center text-5xl">🍽️</div>
                  )}
                  <div className="absolute inset-0 bg-gradient-to-t from-black/50 to-transparent" />
                  {offer!.percentOff > 0 ? (
                    <span className="absolute right-2 top-2 flex h-12 w-12 rotate-12 items-center justify-center rounded-full bg-gradient-to-br from-rose-500 to-red-600 text-sm font-black text-white shadow-lg ring-4 ring-white/70 transition group-hover:rotate-0 group-hover:scale-110">
                      -{offer!.percentOff}%
                    </span>
                  ) : (
                    <span className="absolute right-2 top-2 rounded-full bg-amber-400 px-2 py-0.5 text-[11px] font-black text-amber-950 shadow">
                      ⭐ {t("Special offer")}
                    </span>
                  )}
                  <span className="absolute bottom-2 left-3 right-3 truncate text-xs font-bold text-white drop-shadow">
                    {restaurant!.name}
                  </span>
                </div>
                <div className="p-3">
                  <p className="truncate font-extrabold text-slate-900 group-hover:text-rose-600">{item.name}</p>
                  {offer!.label && (
                    <p className="truncate text-[11px] font-bold uppercase tracking-wide text-amber-600">
                      {offer!.label}
                    </p>
                  )}
                  <div className="mt-1 flex items-center gap-2">
                    <span className={`font-black ${offer!.percentOff > 0 ? "text-rose-600" : "text-slate-900"}`}>
                      {formatPrice(offer!.priceCents)}
                    </span>
                    {offer!.percentOff > 0 && (
                      <span className="text-xs text-slate-400 line-through">{formatPrice(offer!.originalCents)}</span>
                    )}
                  </div>
                </div>
              </Link>
            ))}
          </div>
        </section>
      )}

      <RestaurantGrid restaurants={restaurants ?? []} deals={dealsByRestaurant} />
    </div>
  );
}
