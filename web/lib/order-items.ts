// Shared order-line query + types. Kept OUT of "use client" files on purpose:
// a value exported from a client component reaches Server Components as a
// client reference object (it rendered as "[object Object]" in the query).
import type { SelectionMode } from "./menu-options";

export interface OrderItemOptionRow {
  group_name: string;
  option_name: string;
  mode: SelectionMode;
  price_cents: number;
}

export const ORDER_ITEMS_SELECT =
  "order_items(quantity, unit_price_cents, notes, menu_items(name, image_url), order_item_options(group_name, option_name, mode, price_cents))";
