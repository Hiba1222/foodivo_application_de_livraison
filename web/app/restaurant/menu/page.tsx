import { formatPrice, PRICE_STEP } from "@/lib/currency";
import { createClient } from "@/lib/supabase/server";
import { getMyRestaurant } from "@/lib/restaurant";
import { addMenuCategory, addMenuItem, toggleItemAvailability, deleteMenuItem } from "../actions";
import Link from "next/link";
import ImageUploader from "@/components/ImageUploader";
import { OFFER_FIELDS, activeOffer } from "@/lib/offers";
import { getT } from "@/lib/i18n/server";
import type { TFn } from "@/lib/i18n/core";

interface MenuItemRow {
  id: string;
  name: string;
  description: string | null;
  price_cents: number;
  is_available: boolean;
  category_id: string | null;
  image_url: string | null;
  menu_option_groups: { count: number }[];
  offer_price_cents: number | null;
  offer_label: string | null;
  offer_ends_at: string | null;
  is_featured: boolean;
}
interface CategoryRow {
  id: string;
  name: string;
}

export default async function RestaurantMenuPage() {
  const restaurant = await getMyRestaurant();
  if (!restaurant) return null;
  const t = getT();

  const supabase = createClient();
  const [{ data: categories }, { data: items }] = await Promise.all([
    supabase
      .from("menu_categories")
      .select("id, name")
      .eq("restaurant_id", restaurant.id)
      .order("sort_order"),
    supabase
      .from("menu_items")
      .select(
        `id, name, description, price_cents, ${OFFER_FIELDS}, is_available, category_id, image_url, menu_option_groups(count)`
      )
      .eq("restaurant_id", restaurant.id)
      .order("name"),
  ]);

  const cats = (categories ?? []) as CategoryRow[];
  const menuItems = (items ?? []) as MenuItemRow[];

  return (
    <div>
      <h1 className="text-xl font-bold text-slate-900">{t("Menu")}</h1>
      <p className="mt-1 text-sm text-slate-500">
        {t("Manage categories and items. Click an item to set up customization (bread, ingredients, extras). Toggle availability to hide an item instantly.")}
      </p>

      {/* Add category */}
      <div className="mt-6 rounded-2xl bg-white p-5 shadow-sm ring-1 ring-slate-200">
        <h2 className="text-sm font-semibold text-slate-900">{t("Add category")}</h2>
        <form
          action={addMenuCategory.bind(null, restaurant.id)}
          className="mt-3 flex gap-2"
        >
          <input
            name="name"
            required
            placeholder={t("e.g. Burgers")}
            className="flex-1 rounded-lg border border-slate-300 px-3 py-2 text-sm"
          />
          <button
            type="submit"
            className="rounded-lg bg-slate-800 px-4 py-2 text-sm font-semibold text-white hover:bg-slate-900"
          >
            {t("Add")}
          </button>
        </form>
      </div>

      {/* Add item */}
      <div className="mt-4 rounded-2xl bg-white p-5 shadow-sm ring-1 ring-slate-200">
        <h2 className="text-sm font-semibold text-slate-900">{t("Add menu item")}</h2>
        <form
          action={addMenuItem.bind(null, restaurant.id)}
          className="mt-3 grid grid-cols-1 gap-3 sm:grid-cols-2"
        >
          <input
            name="name"
            required
            placeholder={t("Item name")}
            className="rounded-lg border border-slate-300 px-3 py-2 text-sm"
          />
          <input
            name="price"
            required
            type="number"
            step={PRICE_STEP}
            min="0"
            placeholder={t("Price (TND)")}
            className="rounded-lg border border-slate-300 px-3 py-2 text-sm"
          />
          <select
            name="category_id"
            className="rounded-lg border border-slate-300 px-3 py-2 text-sm sm:col-span-2"
          >
            <option value="">{t("No category")}</option>
            {cats.map((c) => (
              <option key={c.id} value={c.id}>
                {c.name}
              </option>
            ))}
          </select>
          <textarea
            name="description"
            rows={2}
            placeholder={t("Description (optional)")}
            className="rounded-lg border border-slate-300 px-3 py-2 text-sm sm:col-span-2"
          />
          <button
            type="submit"
            className="rounded-lg bg-brand-600 px-4 py-2 text-sm font-semibold text-white hover:bg-brand-700 sm:col-span-2"
          >
            {t("Add item & set up options")} →
          </button>
        </form>
      </div>

      {/* Item list */}
      <div className="mt-6 overflow-x-auto rounded-2xl bg-white shadow-sm ring-1 ring-slate-200">
        <table className="w-full text-left text-sm">
          <thead className="border-b border-slate-200 bg-slate-50 text-slate-500">
            <tr>
              <th className="px-4 py-3 font-medium">{t("Photo")}</th>
              <th className="px-4 py-3 font-medium">{t("Item")}</th>
              <th className="px-4 py-3 font-medium">{t("Category")}</th>
              <th className="px-4 py-3 font-medium">{t("Price")}</th>
              <th className="px-4 py-3 font-medium">{t("Options")}</th>
              <th className="px-4 py-3 font-medium">{t("Available")}</th>
              <th className="px-4 py-3 font-medium">{t("Actions")}</th>
            </tr>
          </thead>
          <tbody>
            {menuItems.map((item) => (
              <tr key={item.id} className="border-b border-slate-100 last:border-0">
                <td className="px-4 py-3">
                  <ImageUploader
                    label="photo"
                    table="menu_items"
                    column="image_url"
                    rowId={item.id}
                    currentUrl={item.image_url}
                    storagePath={`restaurants/${restaurant.id}/items/${item.id}.jpg`}
                  />
                </td>
                <td className="px-4 py-3">
                  <Link
                    href={`/restaurant/menu/${item.id}`}
                    className="font-medium text-slate-900 hover:text-brand-600"
                  >
                    {item.name}
                  </Link>
                  {item.description && (
                    <p className="text-xs text-slate-500">{item.description}</p>
                  )}
                </td>
                <td className="px-4 py-3 text-slate-600">
                  {cats.find((c) => c.id === item.category_id)?.name ?? "—"}
                </td>
                <td className="px-4 py-3 text-slate-900">
                  <PriceCell item={item} t={t} />
                </td>
                <td className="px-4 py-3">
                  <Link
                    href={`/restaurant/menu/${item.id}`}
                    className="inline-flex items-center gap-1 rounded-lg bg-brand-50 px-2.5 py-1 text-xs font-semibold text-brand-700 hover:bg-brand-100"
                  >
                    {(item.menu_option_groups?.[0]?.count ?? 0) > 0
                      ? `${t(item.menu_option_groups[0].count === 1 ? "{n} group" : "{n} groups", {
                          n: item.menu_option_groups[0].count,
                        })} · ${t("Edit")}`
                      : `+ ${t("Customize")}`}
                  </Link>
                </td>
                <td className="px-4 py-3">
                  <form
                    action={toggleItemAvailability.bind(null, item.id, !item.is_available)}
                  >
                    <button
                      type="submit"
                      className={`rounded-full px-2 py-0.5 text-xs font-semibold ${
                        item.is_available
                          ? "bg-green-100 text-green-700"
                          : "bg-slate-200 text-slate-600"
                      }`}
                    >
                      {item.is_available ? t("Available") : t("Hidden")}
                    </button>
                  </form>
                </td>
                <td className="px-4 py-3">
                  <form action={deleteMenuItem.bind(null, item.id)}>
                    <button
                      type="submit"
                      className="text-xs font-semibold text-red-600 hover:text-red-700"
                    >
                      {t("Delete")}
                    </button>
                  </form>
                </td>
              </tr>
            ))}
            {menuItems.length === 0 && (
              <tr>
                <td colSpan={7} className="px-4 py-8 text-center text-slate-400">
                  {t("No menu items yet — add your first one above.")}
                </td>
              </tr>
            )}
          </tbody>
        </table>
      </div>
    </div>
  );
}

function PriceCell({ item, t }: { item: MenuItemRow; t: TFn }) {
  const offer = activeOffer(item);
  if (!offer) return <>{formatPrice(item.price_cents)}</>;
  return (
    <Link href={`/restaurant/menu/${item.id}`} className="group block" title={t("Edit offer")}>
      {offer.percentOff > 0 ? (
        <>
          <span className="block text-xs text-slate-400 line-through">{formatPrice(item.price_cents)}</span>
          <span className="font-bold text-rose-600">{formatPrice(offer.priceCents)}</span>{" "}
          <span className="rounded-full bg-rose-600 px-1.5 py-0.5 text-[10px] font-bold text-white">
            -{offer.percentOff}%
          </span>
        </>
      ) : (
        <span>{formatPrice(item.price_cents)}</span>
      )}
      {offer.featured && (
        <span className="mt-0.5 block text-[11px] font-semibold text-amber-600">⭐ {t("Featured")}</span>
      )}
    </Link>
  );
}
