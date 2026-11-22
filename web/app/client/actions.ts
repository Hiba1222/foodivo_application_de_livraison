"use server";

import { DELIVERY_FEE } from "@/lib/currency";
import { revalidatePath } from "next/cache";
import { randomUUID } from "crypto";
import { createClient } from "@/lib/supabase/server";
import { getT } from "@/lib/i18n/server";
import { OFFER_FIELDS, effectiveBasePrice } from "@/lib/offers";
import {
  OPTION_GROUP_SELECT,
  evaluateSelections,
  sortGroups,
  type MenuOptionGroup,
  type OptionSelection,
} from "@/lib/menu-options";


async function requireUser() {
  const supabase = createClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();
  if (!user) throw new Error("Not authenticated");
  return { supabase, user };
}

export async function completeClientProfile(formData: FormData) {
  const { supabase, user } = await requireUser();

  const phone = formData.get("phone") as string;
  if (phone) {
    const { error } = await supabase.from("profiles").update({ phone }).eq("id", user.id);
    if (error) throw new Error(error.message);
  }

  const addressLine = formData.get("address_line") as string;
  if (addressLine) {
    const { error } = await supabase.from("client_addresses").insert({
      client_id: user.id,
      label: (formData.get("label") as string) || getT()("Home"),
      address_line: addressLine,
      latitude: 52.3759,
      longitude: 9.732,
      is_default: true,
    });
    if (error) throw new Error(error.message);
  }

  revalidatePath("/client");
}

export async function addAddress(formData: FormData) {
  const { supabase, user } = await requireUser();

  const { error } = await supabase.from("client_addresses").insert({
    client_id: user.id,
    label: (formData.get("label") as string) || getT()("Address"),
    address_line: formData.get("address_line") as string,
    // Placeholder coordinates — a real build would geocode the address.
    latitude: 52.3759,
    longitude: 9.732,
    is_default: formData.get("is_default") === "on",
  });

  if (error) throw new Error(error.message);
  revalidatePath("/client/checkout");
  revalidatePath("/client/settings");
}

export async function updateClientPhone(formData: FormData) {
  const { supabase, user } = await requireUser();
  const { error } = await supabase
    .from("profiles")
    .update({ phone: formData.get("phone") as string })
    .eq("id", user.id);
  if (error) throw new Error(error.message);
  revalidatePath("/client/settings");
}

export async function deleteAddress(addressId: string) {
  const { supabase, user } = await requireUser();
  const { error } = await supabase
    .from("client_addresses")
    .delete()
    .eq("id", addressId)
    .eq("client_id", user.id);
  if (error) throw new Error(error.message);
  revalidatePath("/client/settings");
}

export async function setDefaultAddress(addressId: string) {
  const { supabase, user } = await requireUser();
  // Only one address can be default: clear the rest, then set this one.
  await supabase.from("client_addresses").update({ is_default: false }).eq("client_id", user.id);
  const { error } = await supabase
    .from("client_addresses")
    .update({ is_default: true })
    .eq("id", addressId)
    .eq("client_id", user.id);
  if (error) throw new Error(error.message);
  revalidatePath("/client/settings");
}

interface PlaceOrderInput {
  restaurantId: string;
  addressId: string;
  items: {
    menuItemId: string;
    quantity: number;
    selections?: OptionSelection[];
    notes?: string;
  }[];
  notes?: string;
}

export async function placeOrder(input: PlaceOrderInput) {
  const { supabase, user } = await requireUser();
  const t = getT();

  if (input.items.length === 0) throw new Error(t("Cart is empty"));

  // Re-fetch current prices AND option rules server-side — never trust
  // client-supplied prices or selections.
  const menuItemIds = Array.from(new Set(input.items.map((i) => i.menuItemId)));
  const { data: menuItems, error: menuError } = await supabase
    .from("menu_items")
    .select(
      `id, name, price_cents, ${OFFER_FIELDS}, is_available, restaurant_id, menu_option_groups(${OPTION_GROUP_SELECT})`
    )
    .in("id", menuItemIds);
  if (menuError) throw new Error(menuError.message);

  const itemById = new Map((menuItems ?? []).map((m: any) => [m.id as string, m]));

  const lines = input.items.map((line) => {
    const menuItem = itemById.get(line.menuItemId);
    if (!menuItem || !menuItem.is_available || menuItem.restaurant_id !== input.restaurantId) {
      throw new Error(t("One or more items are no longer available"));
    }
    if (!Number.isInteger(line.quantity) || line.quantity < 1 || line.quantity > 99) {
      throw new Error(t("Invalid quantity"));
    }
    const groups = sortGroups(menuItem.menu_option_groups as MenuOptionGroup[]);
    // Live discount (if any) applies to the base price; extras keep their price.
    const evaluation = evaluateSelections(effectiveBasePrice(menuItem), groups, line.selections ?? [], t);
    if (evaluation.problem) {
      throw new Error(
        `${menuItem.name}: ${evaluation.problem}. ${t("Please re-add it to your cart.")}`
      );
    }
    const firstGroupError = groups.find((g) => evaluation.groupErrors[g.id]);
    if (firstGroupError) {
      throw new Error(
        `${menuItem.name}: "${firstGroupError.name}" — ${evaluation.groupErrors[firstGroupError.id]}`
      );
    }
    return {
      id: randomUUID(),
      menuItemId: menuItem.id as string,
      quantity: line.quantity,
      unitPriceCents: evaluation.unitPriceCents,
      priced: evaluation.priced,
      notes: line.notes?.trim().slice(0, 200) || null,
    };
  });

  const subtotalCents = lines.reduce((sum, l) => sum + l.unitPriceCents * l.quantity, 0);
  const totalCents = subtotalCents + DELIVERY_FEE;

  const { data: order, error: orderError } = await supabase
    .from("orders")
    .insert({
      client_id: user.id,
      restaurant_id: input.restaurantId,
      delivery_address_id: input.addressId,
      subtotal_cents: subtotalCents,
      delivery_fee_cents: DELIVERY_FEE,
      total_cents: totalCents,
      notes: input.notes ?? null,
    })
    .select("id")
    .single();
  if (orderError) throw new Error(orderError.message);

  // If saving the lines fails, cancel the half-created order so the
  // restaurant never sees an empty / incomplete ticket.
  async function abort(message: string): Promise<never> {
    await supabase.from("orders").update({ status: "cancelled" }).eq("id", order!.id);
    throw new Error(message);
  }

  // Line ids are generated here so each option row can point at its line.
  const { error: itemsError } = await supabase.from("order_items").insert(
    lines.map((l) => ({
      id: l.id,
      order_id: order.id,
      menu_item_id: l.menuItemId,
      quantity: l.quantity,
      unit_price_cents: l.unitPriceCents,
      notes: l.notes,
    }))
  );
  if (itemsError) await abort(itemsError.message);

  const optionRows = lines.flatMap((l) =>
    l.priced.map((p) => ({
      order_item_id: l.id,
      option_id: p.optionId,
      group_name: p.groupName,
      option_name: p.optionName,
      mode: p.mode,
      price_cents: p.priceCents,
    }))
  );
  if (optionRows.length > 0) {
    const { error: optionsError } = await supabase.from("order_item_options").insert(optionRows);
    if (optionsError) await abort(optionsError.message);
  }

  await supabase.from("order_status_history").insert({
    order_id: order.id,
    status: "pending",
    changed_by: user.id,
  });

  revalidatePath("/client/orders");
  return order.id as string;
}
