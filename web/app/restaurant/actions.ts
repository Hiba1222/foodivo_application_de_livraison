"use server";

import { revalidatePath } from "next/cache";
import { redirect } from "next/navigation";
import { createClient } from "@/lib/supabase/server";
import { getT } from "@/lib/i18n/server";
import type { OrderStatus } from "@/lib/types";
import { parsePrice } from "@/lib/currency";
import { OPTION_TEMPLATES, type OptionGroupKind } from "@/lib/menu-options";

async function requireUser() {
  const supabase = createClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();
  if (!user) throw new Error("Not authenticated");
  return { supabase, user };
}

// ---------- Onboarding / settings ----------

export async function createRestaurant(formData: FormData) {
  const { supabase, user } = await requireUser();

  const { error } = await supabase.from("restaurants").insert({
    owner_id: user.id,
    name: formData.get("name") as string,
    description: formData.get("description") as string,
    cuisine_type: formData.get("cuisine_type") as string,
    address: formData.get("address") as string,
    phone: formData.get("phone") as string,
    // Simple placeholders — a real build would geocode the address.
    latitude: parseFloat((formData.get("latitude") as string) || "52.3759"),
    longitude: parseFloat((formData.get("longitude") as string) || "9.7320"),
  });

  if (error) throw new Error(error.message);
  revalidatePath("/restaurant");
}

export async function updateRestaurant(restaurantId: string, formData: FormData) {
  const { supabase } = await requireUser();

  const { error } = await supabase
    .from("restaurants")
    .update({
      name: formData.get("name") as string,
      description: formData.get("description") as string,
      cuisine_type: formData.get("cuisine_type") as string,
      address: formData.get("address") as string,
      phone: formData.get("phone") as string,
    })
    .eq("id", restaurantId);

  if (error) throw new Error(error.message);
  revalidatePath("/restaurant/settings");
  revalidatePath("/restaurant");
}

export async function toggleRestaurantOpen(restaurantId: string, isOpen: boolean) {
  const { supabase } = await requireUser();
  const { error } = await supabase
    .from("restaurants")
    .update({ is_open: isOpen })
    .eq("id", restaurantId);
  if (error) throw new Error(error.message);
  revalidatePath("/restaurant");
  revalidatePath("/restaurant/settings");
}

// ---------- Menu ----------

export async function addMenuCategory(restaurantId: string, formData: FormData) {
  const { supabase } = await requireUser();
  const { error } = await supabase.from("menu_categories").insert({
    restaurant_id: restaurantId,
    name: formData.get("name") as string,
  });
  if (error) throw new Error(error.message);
  revalidatePath("/restaurant/menu");
}

export async function addMenuItem(restaurantId: string, formData: FormData) {
  const { supabase } = await requireUser();
  const { data, error } = await supabase
    .from("menu_items")
    .insert({
      restaurant_id: restaurantId,
      category_id: (formData.get("category_id") as string) || null,
      name: formData.get("name") as string,
      description: formData.get("description") as string,
      price_cents: parseCents(formData.get("price")),
    })
    .select("id")
    .single();
  if (error) throw new Error(error.message);
  revalidatePath("/restaurant/menu");
  // Straight to the customization page so the owner can add bread, extras, etc.
  redirect(`/restaurant/menu/${data.id}?new=1`);
}

export async function updateMenuItem(itemId: string, formData: FormData) {
  const { supabase } = await requireUser();
  const { error } = await supabase
    .from("menu_items")
    .update({
      name: formData.get("name") as string,
      description: (formData.get("description") as string) || null,
      category_id: (formData.get("category_id") as string) || null,
      price_cents: parseCents(formData.get("price")),
    })
    .eq("id", itemId);
  if (error) throw new Error(error.message);
  revalidateItem(itemId);
}

// ---------- Discounts & special offers ----------

/** Returns { error } instead of throwing so the form can show the message (Next hides thrown messages in production). */
export async function updateItemOffer(itemId: string, formData: FormData): Promise<{ error?: string }> {
  const { supabase } = await requireUser();
  const t = getT();
  const { data: item, error: fetchError } = await supabase
    .from("menu_items")
    .select("price_cents")
    .eq("id", itemId)
    .single();
  if (fetchError) return { error: fetchError.message };

  const rawPrice = String(formData.get("offer_price") ?? "").trim();
  const offerPrice = rawPrice ? parsePrice(rawPrice) : null;
  if (offerPrice !== null && (offerPrice <= 0 || offerPrice >= item.price_cents)) {
    return { error: t("The offer price must be lower than the normal price.") };
  }
  const endsAt = String(formData.get("offer_ends_at") ?? "").trim();
  const label = String(formData.get("offer_label") ?? "").trim().slice(0, 40);

  const { error } = await supabase
    .from("menu_items")
    .update({
      offer_price_cents: offerPrice,
      offer_label: label || null,
      offer_ends_at: endsAt ? new Date(endsAt).toISOString() : null,
      is_featured: formData.get("is_featured") === "on",
    })
    .eq("id", itemId);
  if (error) return { error: error.message };
  revalidateItem(itemId);
  return {};
}

export async function clearItemOffer(itemId: string) {
  const { supabase } = await requireUser();
  const { error } = await supabase
    .from("menu_items")
    .update({ offer_price_cents: null, offer_label: null, offer_ends_at: null, is_featured: false })
    .eq("id", itemId);
  if (error) throw new Error(error.message);
  revalidateItem(itemId);
}

export async function toggleItemAvailability(itemId: string, isAvailable: boolean) {
  const { supabase } = await requireUser();
  const { error } = await supabase
    .from("menu_items")
    .update({ is_available: isAvailable })
    .eq("id", itemId);
  if (error) throw new Error(error.message);
  revalidatePath("/restaurant/menu");
}

export async function deleteMenuItem(itemId: string) {
  const { supabase } = await requireUser();
  const { error } = await supabase.from("menu_items").delete().eq("id", itemId);
  if (error) throw new Error(error.message);
  revalidatePath("/restaurant/menu");
}

// ---------- Meal customization (option groups & options) ----------

// Form prices are typed in TND ("7.500") and stored as millimes (7500).
const parseCents = parsePrice;

function parseIntOrNull(value: FormDataEntryValue | null) {
  const raw = String(value ?? "").trim();
  if (raw === "") return null;
  const n = parseInt(raw, 10);
  return Number.isFinite(n) ? n : null;
}

function revalidateItem(itemId: string) {
  revalidatePath("/restaurant/menu");
  revalidatePath(`/restaurant/menu/${itemId}`);
}

/** Normalises min/max so the rules are always satisfiable. */
function groupRules(kind: OptionGroupKind, min: number | null, max: number | null) {
  if (kind === "ingredients") return { min_select: 0, max_select: null };
  const minSel = Math.max(0, min ?? 0);
  let maxSel = max === null ? null : Math.max(1, max);
  if (maxSel !== null && maxSel < minSel) maxSel = minSel;
  return { min_select: minSel, max_select: maxSel };
}

type Supabase = ReturnType<typeof createClient>;

async function nextGroupSortOrder(supabase: Supabase, itemId: string) {
  const { data } = await supabase
    .from("menu_option_groups")
    .select("sort_order")
    .eq("menu_item_id", itemId)
    .order("sort_order", { ascending: false })
    .limit(1);
  return (data?.[0]?.sort_order ?? -1) + 1;
}

async function insertGroupWithOptions(
  supabase: Supabase,
  itemId: string,
  group: { name: string; kind: OptionGroupKind; min_select: number; max_select: number | null },
  options: {
    name: string;
    price_cents: number;
    is_default?: boolean;
    allow_extra?: boolean;
    is_available?: boolean;
  }[],
  sortOrder: number
) {
  const { data: created, error } = await supabase
    .from("menu_option_groups")
    .insert({ menu_item_id: itemId, sort_order: sortOrder, ...group })
    .select("id")
    .single();
  if (error) throw new Error(error.message);
  if (options.length === 0) return;
  const { error: optError } = await supabase.from("menu_options").insert(
    options.map((o, idx) => ({
      group_id: created.id,
      name: o.name,
      price_cents: o.price_cents,
      is_default: o.is_default ?? false,
      allow_extra: o.allow_extra ?? true,
      is_available: o.is_available ?? true,
      sort_order: idx,
    }))
  );
  if (optError) throw new Error(optError.message);
}

export async function addOptionGroup(itemId: string, formData: FormData) {
  const { supabase } = await requireUser();
  const kind: OptionGroupKind = formData.get("kind") === "ingredients" ? "ingredients" : "choice";
  const required = formData.get("required") === "on";
  const rules = groupRules(kind, required ? 1 : 0, parseIntOrNull(formData.get("max_select")));
  const name = String(formData.get("name") ?? "").trim();
  if (!name) throw new Error(getT()("Group name is required"));

  await insertGroupWithOptions(
    supabase,
    itemId,
    { name, kind, ...rules },
    [],
    await nextGroupSortOrder(supabase, itemId)
  );
  revalidateItem(itemId);
}

export async function addOptionGroupFromTemplate(itemId: string, templateKey: string) {
  const { supabase } = await requireUser();
  const template = OPTION_TEMPLATES.find((t) => t.key === templateKey);
  if (!template) throw new Error("Unknown template");
  // Insert names in the owner's current language (e.g. "Choisissez votre pain").
  const t = getT();
  await insertGroupWithOptions(
    supabase,
    itemId,
    { ...template.group, name: t(template.group.name) },
    template.options.map((o) => ({ ...o, name: t(o.name) })),
    await nextGroupSortOrder(supabase, itemId)
  );
  revalidateItem(itemId);
}

export async function copyOptionGroups(targetItemId: string, formData: FormData) {
  const { supabase } = await requireUser();
  const sourceItemId = formData.get("source_item_id") as string;
  if (!sourceItemId || sourceItemId === targetItemId) return;

  const { data: groups, error } = await supabase
    .from("menu_option_groups")
    .select(
      "name, kind, min_select, max_select, sort_order, menu_options(name, price_cents, is_default, allow_extra, is_available, sort_order)"
    )
    .eq("menu_item_id", sourceItemId)
    .order("sort_order");
  if (error) throw new Error(error.message);

  let sort = await nextGroupSortOrder(supabase, targetItemId);
  for (const g of (groups ?? []) as any[]) {
    const options = [...(g.menu_options ?? [])].sort((a: any, b: any) => a.sort_order - b.sort_order);
    await insertGroupWithOptions(
      supabase,
      targetItemId,
      { name: g.name, kind: g.kind, min_select: g.min_select, max_select: g.max_select },
      options,
      sort++
    );
  }
  revalidateItem(targetItemId);
}

export async function updateOptionGroup(itemId: string, groupId: string, formData: FormData) {
  const { supabase } = await requireUser();
  const kind: OptionGroupKind = formData.get("kind") === "ingredients" ? "ingredients" : "choice";
  const rules = groupRules(
    kind,
    parseIntOrNull(formData.get("min_select")),
    parseIntOrNull(formData.get("max_select"))
  );
  const { error } = await supabase
    .from("menu_option_groups")
    .update({ name: String(formData.get("name") ?? "").trim() || "Options", kind, ...rules })
    .eq("id", groupId);
  if (error) throw new Error(error.message);
  revalidateItem(itemId);
}

export async function deleteOptionGroup(itemId: string, groupId: string) {
  const { supabase } = await requireUser();
  const { error } = await supabase.from("menu_option_groups").delete().eq("id", groupId);
  if (error) throw new Error(error.message);
  revalidateItem(itemId);
}

export async function moveOptionGroup(itemId: string, groupId: string, direction: "up" | "down") {
  const { supabase } = await requireUser();
  const { data: groups, error } = await supabase
    .from("menu_option_groups")
    .select("id, sort_order, created_at")
    .eq("menu_item_id", itemId)
    .order("sort_order")
    .order("created_at");
  if (error) throw new Error(error.message);

  const ids = (groups ?? []).map((g) => g.id as string);
  const from = ids.indexOf(groupId);
  const to = direction === "up" ? from - 1 : from + 1;
  if (from < 0 || to < 0 || to >= ids.length) return;
  [ids[from], ids[to]] = [ids[to], ids[from]];

  await Promise.all(
    ids.map((id, idx) => supabase.from("menu_option_groups").update({ sort_order: idx }).eq("id", id))
  );
  revalidateItem(itemId);
}

export async function addOption(itemId: string, groupId: string, formData: FormData) {
  const { supabase } = await requireUser();
  const name = String(formData.get("name") ?? "").trim();
  if (!name) throw new Error(getT()("Option name is required"));

  const { data: last } = await supabase
    .from("menu_options")
    .select("sort_order")
    .eq("group_id", groupId)
    .order("sort_order", { ascending: false })
    .limit(1);

  const { error } = await supabase.from("menu_options").insert({
    group_id: groupId,
    name,
    price_cents: parseCents(formData.get("price")),
    sort_order: (last?.[0]?.sort_order ?? -1) + 1,
  });
  if (error) throw new Error(error.message);
  revalidateItem(itemId);
}

export async function updateOption(itemId: string, optionId: string, formData: FormData) {
  const { supabase } = await requireUser();
  const update: Record<string, unknown> = {
    name: String(formData.get("name") ?? "").trim() || "Option",
    price_cents: parseCents(formData.get("price")),
  };
  // Each group kind only shows one of these checkboxes; leave the other untouched.
  if (formData.has("has_is_default")) update.is_default = formData.get("is_default") === "on";
  if (formData.has("has_allow_extra")) update.allow_extra = formData.get("allow_extra") === "on";

  const { error } = await supabase.from("menu_options").update(update).eq("id", optionId);
  if (error) throw new Error(error.message);
  revalidateItem(itemId);
}

export async function toggleOptionAvailability(itemId: string, optionId: string, isAvailable: boolean) {
  const { supabase } = await requireUser();
  const { error } = await supabase
    .from("menu_options")
    .update({ is_available: isAvailable })
    .eq("id", optionId);
  if (error) throw new Error(error.message);
  revalidateItem(itemId);
}

export async function deleteOption(itemId: string, optionId: string) {
  const { supabase } = await requireUser();
  const { error } = await supabase.from("menu_options").delete().eq("id", optionId);
  if (error) throw new Error(error.message);
  revalidateItem(itemId);
}


// ---------- Orders ----------

// Only these transitions are allowed from the restaurant side; driver/client
// transitions (picked_up, delivered) happen elsewhere.
const ALLOWED_TRANSITIONS: Record<string, OrderStatus[]> = {
  pending: ["accepted", "rejected"],
  accepted: ["ready_for_pickup"],
};

export async function updateOrderStatus(orderId: string, newStatus: OrderStatus) {
  const { supabase, user } = await requireUser();

  const { data: order, error: fetchError } = await supabase
    .from("orders")
    .select("status")
    .eq("id", orderId)
    .single();
  if (fetchError) throw new Error(fetchError.message);

  const allowed = ALLOWED_TRANSITIONS[order.status] ?? [];
  if (!allowed.includes(newStatus)) {
    throw new Error(`Cannot move order from ${order.status} to ${newStatus}`);
  }

  const timestampField =
    newStatus === "accepted" ? "accepted_at" : newStatus === "ready_for_pickup" ? "ready_at" : null;

  const { error } = await supabase
    .from("orders")
    .update({
      status: newStatus,
      ...(timestampField ? { [timestampField]: new Date().toISOString() } : {}),
    })
    .eq("id", orderId);
  if (error) throw new Error(error.message);

  await supabase.from("order_status_history").insert({
    order_id: orderId,
    status: newStatus,
    changed_by: user.id,
  });

  revalidatePath("/restaurant/orders");
}
