import Link from "next/link";
import { createClient } from "@/lib/supabase/server";
import MenuItemCard from "./MenuItemCard";
import FloatingCartBar from "./FloatingCartBar";
import { OPTION_GROUP_SELECT, sortGroups, type MenuOptionGroup } from "@/lib/menu-options";
import { OFFER_FIELDS, activeOffer } from "@/lib/offers";
import { getT } from "@/lib/i18n/server";

export default async function RestaurantMenuPage({ params }: { params: { id: string } }) {
  const t = getT();
  const supabase = createClient();

  const [{ data: restaurant }, { data: categories }, { data: items }] = await Promise.all([
    supabase.from("restaurants").select("*").eq("id", params.id).single(),
    supabase
      .from("menu_categories")
      .select("id, name")
      .eq("restaurant_id", params.id)
      .order("sort_order"),
    supabase
      .from("menu_items")
      .select(
        `id, name, description, price_cents, ${OFFER_FIELDS}, category_id, image_url, menu_option_groups(${OPTION_GROUP_SELECT})`
      )
      .eq("restaurant_id", params.id)
      .eq("is_available", true)
      .order("name"),
  ]);

  if (!restaurant) {
    return (
      <div className="flex flex-col items-center py-20 text-center">
        <span className="text-5xl">🤷</span>
        <p className="mt-3 text-slate-500">{t("Restaurant not found.")}</p>
        <Link href="/client" className="mt-3 text-sm font-semibold text-brand-600">
          ← {t("Back to restaurants")}
        </Link>
      </div>
    );
  }

  const menuItems = (items ?? []).map((i: any) => ({
    ...i,
    groups: sortGroups(i.menu_option_groups as MenuOptionGroup[], { onlyAvailable: true }),
  }));
  const sections = [
    ...(categories ?? []).map((c) => ({
      id: c.id as string,
      name: c.name as string,
      items: menuItems.filter((i) => i.category_id === c.id),
    })),
    {
      id: "other",
      name: (categories ?? []).length > 0 ? t("Other") : t("Menu"),
      items: menuItems.filter((i) => !i.category_id),
    },
  ].filter((s) => s.items.length > 0);

  // Live discounts first (biggest first), then featured items without discount.
  const specials = menuItems
    .map((i) => ({ item: i, offer: activeOffer(i) }))
    .filter((x) => x.offer)
    .sort((a, b) => b.offer!.percentOff - a.offer!.percentOff)
    .map((x) => x.item);
  const bestDeal = specials.length ? activeOffer(specials[0])!.percentOff : 0;

  return (
    <div>
      <Link
        href="/client"
        className="group mb-4 inline-flex items-center gap-1 text-sm font-semibold text-slate-500 hover:text-brand-600"
      >
        <span className="transition group-hover:-translate-x-1">←</span> {t("All restaurants")}
      </Link>

      <section className="relative overflow-hidden rounded-3xl bg-gradient-to-br from-brand-500 to-rose-500 shadow-lift">
        {restaurant.cover_image_url && (
          // eslint-disable-next-line @next/next/no-img-element
          <img
            src={restaurant.cover_image_url}
            alt={restaurant.name}
            className="absolute inset-0 h-full w-full animate-[scale-in_1.2s_ease-out_both] object-cover"
          />
        )}
        <div className="absolute inset-0 bg-gradient-to-t from-black/75 via-black/30 to-black/5" />
        <div className="relative flex min-h-[220px] flex-col justify-end p-6 text-white sm:min-h-[260px] sm:p-8">
          <div className="flex items-end gap-4">
            {restaurant.logo_url && (
              // eslint-disable-next-line @next/next/no-img-element
              <img
                src={restaurant.logo_url}
                alt=""
                className="h-16 w-16 animate-scale-in rounded-2xl border-4 border-white/90 object-cover shadow-lg sm:h-20 sm:w-20"
              />
            )}
            <div className="min-w-0 animate-fade-up">
              <div className="flex flex-wrap items-center gap-2">
                <h1 className="text-2xl font-extrabold drop-shadow sm:text-3xl">{restaurant.name}</h1>
                <span
                  className={`flex items-center gap-1.5 rounded-full px-2.5 py-0.5 text-xs font-bold backdrop-blur ${
                    restaurant.is_open ? "bg-green-500/90" : "bg-slate-900/70"
                  }`}
                >
                  <span className={`h-1.5 w-1.5 rounded-full bg-white ${restaurant.is_open ? "live-dot" : ""}`} />
                  {restaurant.is_open ? t("Open now") : t("Closed")}
                </span>
              </div>
              {restaurant.description && (
                <p className="mt-1 line-clamp-2 max-w-xl text-sm text-white/85">{restaurant.description}</p>
              )}
              <div className="mt-2 flex flex-wrap gap-2 text-xs font-semibold">
                {restaurant.cuisine_type && (
                  <span className="rounded-full bg-white/20 px-2.5 py-1 backdrop-blur">{restaurant.cuisine_type}</span>
                )}
                {restaurant.avg_prep_time_minutes != null && (
                  <span className="rounded-full bg-white/20 px-2.5 py-1 backdrop-blur">
                    ⏱ ~{restaurant.avg_prep_time_minutes} min
                  </span>
                )}
                {restaurant.address && (
                  <span className="rounded-full bg-white/20 px-2.5 py-1 backdrop-blur">📍 {restaurant.address}</span>
                )}
              </div>
            </div>
          </div>
        </div>
      </section>

      {specials.length > 0 && (
        <section className="mt-6 animate-fade-up">
          <div className="shine flex items-center justify-between gap-3 rounded-2xl bg-gradient-to-r from-rose-600 via-red-500 to-amber-500 px-5 py-3 text-white shadow-lift">
            <div>
              <h2 className="flex items-center gap-2 text-lg font-black">
                <span className="inline-block animate-wiggle">🔥</span> {t("Special offers")}
              </h2>
              <p className="text-xs font-medium text-white/85">
                {t("Limited-time deals from this restaurant")}
              </p>
            </div>
            {bestDeal > 0 && (
              <span className="shrink-0 rounded-xl bg-white px-3 py-1.5 text-sm font-black text-rose-600 shadow">
                {t("Up to -{p}%", { p: bestDeal })}
              </span>
            )}
          </div>
          <div className="stagger -mx-4 mt-4 flex snap-x gap-4 overflow-x-auto px-4 pb-4 pt-1 md:mx-0 md:px-1">
            {specials.map((item, i) => (
              <div key={item.id} style={{ "--i": i } as React.CSSProperties} className="flex">
                <MenuItemCard
                  restaurantId={restaurant.id}
                  restaurantName={restaurant.name}
                  item={item}
                  groups={item.groups}
                  variant="spotlight"
                />
              </div>
            ))}
          </div>
        </section>
      )}

      {sections.length > 1 && (
        <nav className="sticky top-14 z-20 -mx-4 mt-6 flex gap-2 overflow-x-auto bg-slate-50/85 px-4 py-3 backdrop-blur md:top-0 md:mx-0 md:rounded-2xl md:px-2">
          {sections.map((s) => (
            <a
              key={s.id}
              href={`#cat-${s.id}`}
              className="shrink-0 rounded-full bg-white px-4 py-1.5 text-sm font-semibold text-slate-600 ring-1 ring-slate-200 hover:-translate-y-0.5 hover:bg-slate-900 hover:text-white hover:ring-slate-900"
            >
              {s.name}
              <span className="ml-1.5 text-xs opacity-60">{s.items.length}</span>
            </a>
          ))}
        </nav>
      )}

      <div className="mt-6 space-y-8">
        {sections.map((s) => (
          <section key={s.id} id={`cat-${s.id}`} className="scroll-mt-32">
            <h2 className="mb-3 flex items-center gap-3 text-lg font-extrabold text-slate-900">
              {s.name}
              <span className="h-px flex-1 bg-gradient-to-r from-slate-200 to-transparent" />
            </h2>
            <div className="stagger grid grid-cols-1 gap-3 lg:grid-cols-2">
              {s.items.map((item, i) => (
                <div key={item.id} style={{ "--i": i } as React.CSSProperties}>
                  <MenuItemCard
                    restaurantId={restaurant.id}
                    restaurantName={restaurant.name}
                    item={item}
                    groups={item.groups}
                  />
                </div>
              ))}
            </div>
          </section>
        ))}

        {menuItems.length === 0 && (
          <div className="flex flex-col items-center py-16 text-center">
            <span className="animate-wiggle text-5xl">🍳</span>
            <p className="mt-3 text-slate-500">{t("No menu items available right now.")}</p>
          </div>
        )}
      </div>

      <FloatingCartBar />
    </div>
  );
}
