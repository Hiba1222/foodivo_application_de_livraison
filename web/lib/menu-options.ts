// Shared meal-customization logic. Used by the client item popup (live price)
// AND by the server at checkout (authoritative price), so both always agree.

export type OptionGroupKind = "choice" | "ingredients";
export type SelectionMode = "add" | "extra" | "remove";

export interface MenuOption {
  id: string;
  name: string;
  price_cents: number;
  is_default: boolean;
  allow_extra: boolean;
  is_available: boolean;
  sort_order: number;
}

export interface MenuOptionGroup {
  id: string;
  name: string;
  kind: OptionGroupKind;
  min_select: number;
  max_select: number | null;
  sort_order: number;
  menu_options: MenuOption[];
}

export interface OptionSelection {
  optionId: string;
  mode: SelectionMode;
}

export interface PricedSelection {
  optionId: string;
  groupName: string;
  optionName: string;
  mode: SelectionMode;
  priceCents: number;
}

export const OPTION_GROUP_SELECT =
  "id, name, kind, min_select, max_select, sort_order, menu_options(id, name, price_cents, is_default, allow_extra, is_available, sort_order)";

import { englishT, type TFn } from "./i18n/core";

// Money is TND millimes (1 TND = 1000) — see lib/currency.ts.
export { formatPrice } from "./currency";

export function describeSelection(mode: SelectionMode, optionName: string, t: TFn = englishT) {
  if (mode === "extra") return t("Extra {name}", { name: optionName });
  if (mode === "remove") return t("No {name}", { name: optionName });
  return optionName;
}

/** Sort groups and their options; optionally drop options that are 86'd. */
export function sortGroups(
  groups: MenuOptionGroup[] | null | undefined,
  { onlyAvailable = false } = {}
): MenuOptionGroup[] {
  const bySort = <T extends { sort_order: number; name: string }>(a: T, b: T) =>
    a.sort_order - b.sort_order || a.name.localeCompare(b.name);
  return [...(groups ?? [])]
    .map((g) => ({
      ...g,
      menu_options: [...(g.menu_options ?? [])]
        .filter((o) => !onlyAvailable || o.is_available)
        .sort(bySort),
    }))
    .filter((g) => !onlyAvailable || g.menu_options.length > 0)
    .sort(bySort);
}

export function isRequired(group: Pick<MenuOptionGroup, "kind" | "min_select">) {
  return group.kind === "choice" && group.min_select > 0;
}

/** Human rule shown under a group title, e.g. "Choose 1" or "Choose up to 3". */
export function groupRuleText(
  group: Pick<MenuOptionGroup, "kind" | "min_select" | "max_select">,
  t: TFn = englishT
) {
  if (group.kind === "ingredients") return t("Remove anything or ask for extra");
  const { min_select: min, max_select: max } = group;
  if (max === 1) return t("Choose 1");
  if (max !== null && min === max) return t("Choose {n}", { n: min });
  if (max === null) return min > 0 ? t("Choose at least {n}", { n: min }) : t("Choose as many as you like");
  return min > 0 ? t("Choose {min} to {max}", { min, max }) : t("Choose up to {n}", { n: max });
}

export interface Evaluation {
  unitPriceCents: number;
  priced: PricedSelection[];
  /** groupId -> message, for unmet min/max rules. */
  groupErrors: Record<string, string>;
  /** Structural problem (unknown/unavailable option, bad mode) — means tampered or stale data. */
  problem: string | null;
}

export function evaluateSelections(
  basePriceCents: number,
  groups: MenuOptionGroup[],
  selections: OptionSelection[],
  t: TFn = englishT
): Evaluation {
  const optionIndex = new Map<string, { group: MenuOptionGroup; option: MenuOption }>();
  for (const group of groups) {
    for (const option of group.menu_options) optionIndex.set(option.id, { group, option });
  }

  const priced: PricedSelection[] = [];
  const groupErrors: Record<string, string> = {};
  const countByGroup = new Map<string, number>();
  const seen = new Set<string>();
  let problem: string | null = null;
  let unitPriceCents = basePriceCents;

  for (const sel of selections) {
    const hit = optionIndex.get(sel.optionId);
    if (!hit || seen.has(sel.optionId)) {
      problem = t("One of the selected options no longer exists");
      continue;
    }
    seen.add(sel.optionId);
    const { group, option } = hit;
    if (!option.is_available) {
      problem = t("\"{name}\" is no longer available", { name: option.name });
      continue;
    }

    const modeOk =
      group.kind === "choice"
        ? sel.mode === "add"
        : sel.mode === "remove" || (sel.mode === "extra" && option.allow_extra);
    if (!modeOk) {
      problem = t("Invalid choice for \"{name}\"", { name: option.name });
      continue;
    }

    // Removing an ingredient is free; "add" and "extra" cost the option price.
    const priceCents = sel.mode === "remove" ? 0 : option.price_cents;
    unitPriceCents += priceCents;
    priced.push({
      optionId: option.id,
      groupName: group.name,
      optionName: option.name,
      mode: sel.mode,
      priceCents,
    });
    if (group.kind === "choice") countByGroup.set(group.id, (countByGroup.get(group.id) ?? 0) + 1);
  }

  for (const group of groups) {
    if (group.kind !== "choice") continue;
    const count = countByGroup.get(group.id) ?? 0;
    if (count < group.min_select) {
      groupErrors[group.id] =
        group.min_select === 1
          ? t("Please choose an option")
          : t("Choose at least {n}", { n: group.min_select });
    } else if (group.max_select !== null && count > group.max_select) {
      groupErrors[group.id] = t("Choose at most {n}", { n: group.max_select });
    }
  }

  return { unitPriceCents, priced, groupErrors, problem };
}

/** Stable key so two identical configurations merge into one cart line. */
export function selectionKey(menuItemId: string, selections: OptionSelection[], notes: string) {
  const sel = selections
    .map((s) => `${s.optionId}:${s.mode}`)
    .sort()
    .join(",");
  return `${menuItemId}|${sel}|${notes.trim().toLowerCase()}`;
}

// ---------- Restaurant quick-start templates ----------

export interface OptionTemplate {
  key: string;
  label: string;
  hint: string;
  group: { name: string; kind: OptionGroupKind; min_select: number; max_select: number | null };
  options: { name: string; price_cents: number; is_default?: boolean; allow_extra?: boolean }[];
}

// Prices in TND millimes: 500 = 0.500 TND, 1500 = 1.500 TND.
// Labels/names are English keys — translate with t() when showing or inserting them.
export const OPTION_TEMPLATES: OptionTemplate[] = [
  {
    key: "bread",
    label: "Bread choice",
    hint: "Required · pick 1",
    group: { name: "Choose your bread", kind: "choice", min_select: 1, max_select: 1 },
    options: [
      { name: "Baguette", price_cents: 0, is_default: true },
      { name: "Mlawi", price_cents: 500 },
      { name: "Chapati", price_cents: 500 },
      { name: "Libanais (wrap)", price_cents: 0 },
      { name: "Panini bread", price_cents: 500 },
    ],
  },
  {
    key: "ingredients",
    label: "Ingredients",
    hint: "No / Regular / Extra",
    group: { name: "What's inside", kind: "ingredients", min_select: 0, max_select: null },
    options: [
      { name: "Harissa", price_cents: 0 },
      { name: "Lettuce", price_cents: 0 },
      { name: "Tomato", price_cents: 0 },
      { name: "Onion", price_cents: 0 },
      { name: "Olives", price_cents: 0 },
      { name: "Cheese", price_cents: 1000 },
    ],
  },
  {
    key: "extras",
    label: "Paid extras",
    hint: "Optional · any number",
    group: { name: "Add extras", kind: "choice", min_select: 0, max_select: null },
    options: [
      { name: "Extra cheese", price_cents: 1000 },
      { name: "Egg", price_cents: 500 },
      { name: "Tuna", price_cents: 1500 },
      { name: "Double meat", price_cents: 3000 },
      { name: "Fries inside", price_cents: 1000 },
    ],
  },
  {
    key: "sauces",
    label: "Sauces",
    hint: "Optional · up to 2",
    group: { name: "Sauces", kind: "choice", min_select: 0, max_select: 2 },
    options: [
      { name: "Mayonnaise", price_cents: 0 },
      { name: "Ketchup", price_cents: 0 },
      { name: "Algerian", price_cents: 0 },
      { name: "Samurai", price_cents: 0 },
      { name: "BBQ", price_cents: 0 },
    ],
  },
  {
    key: "size",
    label: "Size",
    hint: "Required · pick 1",
    group: { name: "Size", kind: "choice", min_select: 1, max_select: 1 },
    options: [
      { name: "Regular", price_cents: 0, is_default: true },
      { name: "Large", price_cents: 3000 },
    ],
  },
  {
    key: "side",
    label: "Make it a meal",
    hint: "Optional · pick 1",
    group: { name: "Add a side", kind: "choice", min_select: 0, max_select: 1 },
    options: [
      { name: "Fries", price_cents: 2500 },
      { name: "Salade méchouia", price_cents: 3000 },
      { name: "Salade tunisienne", price_cents: 3000 },
    ],
  },
  {
    key: "drink",
    label: "Drink",
    hint: "Optional · pick 1",
    group: { name: "Add a drink", kind: "choice", min_select: 0, max_select: 1 },
    options: [
      { name: "Water 0.5L", price_cents: 1000 },
      { name: "Boga", price_cents: 2000 },
      { name: "Coca-Cola", price_cents: 2500 },
      { name: "Fresh orange juice", price_cents: 3500 },
    ],
  },
];
