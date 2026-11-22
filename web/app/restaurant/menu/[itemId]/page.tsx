import { PRICE_STEP, priceInputValue } from "@/lib/currency";
import Link from "next/link";
import { createClient } from "@/lib/supabase/server";
import { getMyRestaurant } from "@/lib/restaurant";
import ImageUploader from "@/components/ImageUploader";
import {
  OPTION_GROUP_SELECT,
  OPTION_TEMPLATES,
  formatPrice,
  groupRuleText,
  isRequired,
  sortGroups,
  type MenuOptionGroup,
} from "@/lib/menu-options";
import {
  addOption,
  addOptionGroup,
  addOptionGroupFromTemplate,
  clearItemOffer,
  copyOptionGroups,
  deleteOption,
  deleteOptionGroup,
  moveOptionGroup,
  toggleOptionAvailability,
  updateItemOffer,
  updateMenuItem,
  updateOption,
  updateOptionGroup,
} from "../../actions";
import AddGroupForm from "./AddGroupForm";
import PreviewButton from "./PreviewButton";
import OfferForm from "./OfferForm";
import { OFFER_FIELDS, effectiveBasePrice } from "@/lib/offers";
import { getT } from "@/lib/i18n/server";
import type { TFn } from "@/lib/i18n/core";

const input = "rounded-lg border border-slate-300 px-3 py-2 text-sm";

export default async function MenuItemEditorPage({
  params,
  searchParams,
}: {
  params: { itemId: string };
  searchParams: { new?: string };
}) {
  const restaurant = await getMyRestaurant();
  if (!restaurant) return null;
  const t = getT();

  const supabase = createClient();
  const [{ data: item }, { data: categories }, { data: otherItems }] = await Promise.all([
    supabase
      .from("menu_items")
      .select(
        `id, name, description, price_cents, ${OFFER_FIELDS}, category_id, image_url, is_available, menu_option_groups(${OPTION_GROUP_SELECT})`
      )
      .eq("id", params.itemId)
      .eq("restaurant_id", restaurant.id)
      .maybeSingle(),
    supabase
      .from("menu_categories")
      .select("id, name")
      .eq("restaurant_id", restaurant.id)
      .order("sort_order"),
    supabase
      .from("menu_items")
      .select("id, name, menu_option_groups(count)")
      .eq("restaurant_id", restaurant.id)
      .neq("id", params.itemId)
      .order("name"),
  ]);

  if (!item) {
    return (
      <div>
        <Link href="/restaurant/menu" className="text-sm font-medium text-brand-600">
          ← {t("Back to menu")}
        </Link>
        <p className="mt-4 text-slate-500">{t("Item not found.")}</p>
      </div>
    );
  }

  const groups = sortGroups(item.menu_option_groups as MenuOptionGroup[]);
  const previewGroups = sortGroups(item.menu_option_groups as MenuOptionGroup[], { onlyAvailable: true });
  const copySources = ((otherItems ?? []) as any[]).filter(
    (i) => (i.menu_option_groups?.[0]?.count ?? 0) > 0
  );

  // Most expensive possible configuration, for the "customers pay" hint.
  const maxPrice =
    item.price_cents +
    groups.reduce((sum, g) => {
      const prices = g.menu_options.filter((o) => o.is_available).map((o) => o.price_cents);
      if (g.kind === "ingredients") return sum + prices.reduce((a, b) => a + b, 0);
      const top = prices.sort((a, b) => b - a).slice(0, g.max_select ?? prices.length);
      return sum + top.reduce((a, b) => a + b, 0);
    }, 0);

  return (
    <div className="max-w-3xl">
      <Link href="/restaurant/menu" className="text-sm font-medium text-brand-600">
        ← {t("Back to menu")}
      </Link>

      <div className="mt-3 flex flex-wrap items-start justify-between gap-3">
        <div>
          <h1 className="text-xl font-bold text-slate-900">{item.name}</h1>
          <p className="mt-1 text-sm text-slate-500">
            {t("Base price {price}", { price: formatPrice(item.price_cents) })}
            {maxPrice > item.price_cents && (
              <> · {t("up to {price} with every extra", { price: formatPrice(maxPrice) })}</>
            )}
          </p>
        </div>
        <PreviewButton
          item={{
            id: item.id,
            name: item.name,
            description: item.description,
            price_cents: effectiveBasePrice(item),
            original_price_cents: item.price_cents,
            image_url: item.image_url,
          }}
          groups={previewGroups}
        />
      </div>

      {searchParams.new && (
        <div className="mt-4 rounded-xl bg-green-50 p-4 text-sm text-green-800 ring-1 ring-green-200">
          <strong>{item.name}</strong>{" "}
          {t("was added to your menu. Now set up how customers can customize it — pick a quick start below, or skip this if the item has no options.")}
        </div>
      )}

      {/* Item details */}
      <section className="mt-6 rounded-2xl bg-white p-5 shadow-sm ring-1 ring-slate-200">
        <h2 className="text-sm font-semibold text-slate-900">{t("Item details")}</h2>
        <div className="mt-3 flex flex-col gap-4 sm:flex-row">
          <ImageUploader
            label="photo"
            table="menu_items"
            column="image_url"
            rowId={item.id}
            currentUrl={item.image_url}
            storagePath={`restaurants/${restaurant.id}/items/${item.id}.jpg`}
          />
          <form
            action={updateMenuItem.bind(null, item.id)}
            className="grid flex-1 grid-cols-1 gap-3 sm:grid-cols-2"
          >
            <input name="name" required defaultValue={item.name} placeholder={t("Item name")} className={input} />
            <input
              name="price"
              required
              type="number"
              step={PRICE_STEP}
              min="0"
              defaultValue={priceInputValue(item.price_cents)}
              placeholder={t("Base price (TND)")}
              className={input}
            />
            <select name="category_id" defaultValue={item.category_id ?? ""} className={`${input} sm:col-span-2`}>
              <option value="">{t("No category")}</option>
              {(categories ?? []).map((c) => (
                <option key={c.id} value={c.id}>
                  {c.name}
                </option>
              ))}
            </select>
            <textarea
              name="description"
              rows={2}
              defaultValue={item.description ?? ""}
              placeholder={t("Description (optional)")}
              className={`${input} sm:col-span-2`}
            />
            <button
              type="submit"
              className="rounded-lg bg-slate-800 px-4 py-2 text-sm font-semibold text-white hover:bg-slate-900 sm:col-span-2 sm:justify-self-start"
            >
              {t("Save details")}
            </button>
          </form>
        </div>
      </section>

      <OfferForm
        priceCents={item.price_cents}
        current={{
          offer_price_cents: item.offer_price_cents,
          offer_label: item.offer_label,
          offer_ends_at: item.offer_ends_at,
          is_featured: item.is_featured,
        }}
        action={updateItemOffer.bind(null, item.id)}
        clearAction={clearItemOffer.bind(null, item.id)}
      />

      {/* Customization */}
      <section className="mt-6">
        <h2 className="text-base font-bold text-slate-900">{t("Customization")}</h2>
        <p className="mt-1 text-sm text-slate-500">
          {t("Let customers build their meal: choose the bread, remove or double ingredients, add paid extras. The price updates automatically as they choose, and every choice shows on the order ticket.")}
        </p>

        <div className="mt-4 rounded-2xl bg-white p-5 shadow-sm ring-1 ring-slate-200">
          <h3 className="text-sm font-semibold text-slate-900">{t("Quick start")}</h3>
          <p className="mt-0.5 text-xs text-slate-500">
            {t("Adds a ready-made group with common options. Rename, re-price or delete anything after.")}
          </p>
          <div className="mt-3 flex flex-wrap gap-2">
            {OPTION_TEMPLATES.map((tpl) => (
              <form key={tpl.key} action={addOptionGroupFromTemplate.bind(null, item.id, tpl.key)}>
                <button
                  type="submit"
                  className="rounded-xl border border-slate-200 px-3 py-2 text-left hover:border-brand-500 hover:bg-brand-50"
                >
                  <span className="block text-sm font-semibold text-slate-900">+ {t(tpl.label)}</span>
                  <span className="block text-xs text-slate-500">{t(tpl.hint)}</span>
                </button>
              </form>
            ))}
          </div>

          {copySources.length > 0 && (
            <form
              action={copyOptionGroups.bind(null, item.id)}
              className="mt-4 flex flex-wrap items-center gap-2 border-t border-slate-100 pt-4"
            >
              <span className="text-sm text-slate-700">{t("Or copy all options from")}</span>
              <select name="source_item_id" required className="rounded-lg border border-slate-300 px-2 py-1.5 text-sm">
                {copySources.map((s) => (
                  <option key={s.id} value={s.id}>
                    {s.name}
                  </option>
                ))}
              </select>
              <button
                type="submit"
                className="rounded-lg bg-slate-100 px-3 py-1.5 text-sm font-semibold text-slate-800 hover:bg-slate-200"
              >
                {t("Copy")}
              </button>
            </form>
          )}
        </div>

        <div className="mt-4 space-y-4">
          {groups.map((group, idx) => (
            <GroupEditor
              key={group.id}
              itemId={item.id}
              group={group}
              isFirst={idx === 0}
              isLast={idx === groups.length - 1}
              t={t}
            />
          ))}
          {groups.length === 0 && (
            <div className="rounded-2xl border-2 border-dashed border-slate-200 p-8 text-center text-sm text-slate-400">
              {t("No customization yet. Customers will add this item as-is.")}
            </div>
          )}
        </div>

        <div className="mt-4 rounded-2xl bg-white p-5 shadow-sm ring-1 ring-slate-200">
          <h3 className="mb-3 text-sm font-semibold text-slate-900">{t("Add a custom group")}</h3>
          <AddGroupForm action={addOptionGroup.bind(null, item.id)} />
        </div>
      </section>
    </div>
  );
}

function GroupEditor({
  itemId,
  group,
  isFirst,
  isLast,
  t,
}: {
  itemId: string;
  group: MenuOptionGroup;
  isFirst: boolean;
  isLast: boolean;
  t: TFn;
}) {
  const isIngredients = group.kind === "ingredients";
  const smallBtn =
    "rounded-md px-2 py-1 text-xs font-semibold text-slate-500 hover:bg-slate-100 hover:text-slate-800 disabled:opacity-30";

  return (
    <div className="overflow-hidden rounded-2xl bg-white shadow-sm ring-1 ring-slate-200">
      {/* Header */}
      <div className="flex flex-wrap items-start justify-between gap-2 border-b border-slate-100 bg-slate-50 px-5 py-3">
        <div>
          <div className="flex flex-wrap items-center gap-2">
            <h3 className="font-semibold text-slate-900">{group.name}</h3>
            <span
              className={`rounded-full px-2 py-0.5 text-[11px] font-semibold ${
                isIngredients ? "bg-amber-100 text-amber-800" : "bg-blue-100 text-blue-800"
              }`}
            >
              {isIngredients ? t("Ingredients") : t("Choice")}
            </span>
            {isRequired(group) ? (
              <span className="rounded-full bg-slate-900 px-2 py-0.5 text-[11px] font-semibold text-white">
                {t("Required")}
              </span>
            ) : (
              !isIngredients && (
                <span className="rounded-full bg-slate-200 px-2 py-0.5 text-[11px] font-semibold text-slate-600">
                  {t("Optional")}
                </span>
              )
            )}
          </div>
          <p className="mt-0.5 text-xs text-slate-500">{groupRuleText(group, t)}</p>
        </div>
        <div className="flex items-center gap-1">
          <form action={moveOptionGroup.bind(null, itemId, group.id, "up")}>
            <button type="submit" disabled={isFirst} className={smallBtn} aria-label={t("Move up")}>
              ↑
            </button>
          </form>
          <form action={moveOptionGroup.bind(null, itemId, group.id, "down")}>
            <button type="submit" disabled={isLast} className={smallBtn} aria-label={t("Move down")}>
              ↓
            </button>
          </form>
          <form action={deleteOptionGroup.bind(null, itemId, group.id)}>
            <button type="submit" className="rounded-md px-2 py-1 text-xs font-semibold text-red-600 hover:bg-red-50">
              {t("Delete group")}
            </button>
          </form>
        </div>
      </div>

      {/* Group settings */}
      <details className="border-b border-slate-100 px-5 py-2">
        <summary className="cursor-pointer text-xs font-semibold text-slate-500 hover:text-slate-800">
          {t("Group settings")}
        </summary>
        <form
          action={updateOptionGroup.bind(null, itemId, group.id)}
          className="flex flex-wrap items-end gap-3 py-3"
        >
          <input type="hidden" name="kind" value={group.kind} />
          <label className="flex flex-1 flex-col text-xs text-slate-500">
            {t("Name")}
            <input name="name" defaultValue={group.name} required className={`${input} mt-1`} />
          </label>
          {!isIngredients && (
            <>
              <label className="flex w-28 flex-col text-xs text-slate-500">
                {t("Min picks")}
                <input
                  name="min_select"
                  type="number"
                  min="0"
                  defaultValue={group.min_select}
                  className={`${input} mt-1`}
                />
              </label>
              <label className="flex w-36 flex-col text-xs text-slate-500">
                {t("Max picks (blank = any)")}
                <input
                  name="max_select"
                  type="number"
                  min="1"
                  defaultValue={group.max_select ?? ""}
                  className={`${input} mt-1`}
                />
              </label>
            </>
          )}
          <button type="submit" className="rounded-lg bg-slate-800 px-3 py-2 text-xs font-semibold text-white">
            {t("Save")}
          </button>
        </form>
        {!isIngredients && (
          <p className="pb-2 text-xs text-slate-400">
            {t("Min 1 makes the group required. Min 1 + max 1 = pick exactly one (e.g. bread).")}
          </p>
        )}
      </details>

      {/* Options */}
      <ul className="divide-y divide-slate-100">
        {group.menu_options.map((opt) => (
          <li
            key={opt.id}
            className={`flex flex-wrap items-center gap-2 px-5 py-2 ${opt.is_available ? "" : "bg-slate-50"}`}
          >
            <form
              action={updateOption.bind(null, itemId, opt.id)}
              className="flex flex-1 flex-wrap items-center gap-2"
            >
              <input
                name="name"
                defaultValue={opt.name}
                required
                className={`${input} min-w-[8rem] flex-1 py-1.5 ${opt.is_available ? "" : "text-slate-400 line-through"}`}
              />
              <label className="flex items-center gap-1 text-xs text-slate-500">
                {isIngredients ? `${t("Extra")} +` : "+"}
                <input
                  name="price"
                  type="number"
                  step={PRICE_STEP}
                  min="0"
                  defaultValue={priceInputValue(opt.price_cents)}
                  className={`${input} w-24 py-1.5`}
                />
                TND
              </label>
              {isIngredients ? (
                <label className="flex items-center gap-1 text-xs text-slate-600">
                  <input type="hidden" name="has_allow_extra" value="1" />
                  <input type="checkbox" name="allow_extra" defaultChecked={opt.allow_extra} />
                  {t("Can be extra")}
                </label>
              ) : (
                <label className="flex items-center gap-1 text-xs text-slate-600">
                  <input type="hidden" name="has_is_default" value="1" />
                  <input type="checkbox" name="is_default" defaultChecked={opt.is_default} />
                  {t("Pre-selected")}
                </label>
              )}
              <button
                type="submit"
                className="rounded-md bg-slate-100 px-2.5 py-1.5 text-xs font-semibold text-slate-700 hover:bg-slate-200"
              >
                {t("Save")}
              </button>
            </form>
            <form action={toggleOptionAvailability.bind(null, itemId, opt.id, !opt.is_available)}>
              <button
                type="submit"
                className={`rounded-full px-2 py-0.5 text-xs font-semibold ${
                  opt.is_available ? "bg-green-100 text-green-700" : "bg-slate-200 text-slate-600"
                }`}
              >
                {opt.is_available ? t("In stock") : t("Sold out")}
              </button>
            </form>
            <form action={deleteOption.bind(null, itemId, opt.id)}>
              <button
                type="submit"
                className="rounded-md px-2 py-1 text-xs font-semibold text-red-600 hover:bg-red-50"
                aria-label={t("Delete {name}", { name: opt.name })}
              >
                ✕
              </button>
            </form>
          </li>
        ))}
        {group.menu_options.length === 0 && (
          <li className="px-5 py-3 text-xs text-amber-700">
            {t("No options yet. Customers won't see this group until you add one.")}
          </li>
        )}
      </ul>

      {/* Add option */}
      <form
        action={addOption.bind(null, itemId, group.id)}
        className="flex flex-wrap items-center gap-2 border-t border-slate-100 bg-slate-50/60 px-5 py-3"
      >
        <input
          name="name"
          required
          placeholder={isIngredients ? t("Ingredient, e.g. Onion") : t("Option, e.g. Bacon")}
          className={`${input} min-w-[8rem] flex-1 py-1.5`}
        />
        <label className="flex items-center gap-1 text-xs text-slate-500">
          {isIngredients ? `${t("Extra")} +` : "+"}
          <input
            name="price"
            type="number"
            step={PRICE_STEP}
            min="0"
            placeholder="0.000"
            className={`${input} w-24 py-1.5`}
          />
          TND
        </label>
        <button
          type="submit"
          className="rounded-lg bg-brand-600 px-3 py-1.5 text-xs font-semibold text-white hover:bg-brand-700"
        >
          + {isIngredients ? t("Add ingredient") : t("Add option")}
        </button>
      </form>
    </div>
  );
}
