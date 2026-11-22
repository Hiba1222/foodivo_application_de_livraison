"use client";

import { createContext, useContext, useState } from "react";
import { selectionKey, type OptionSelection, type SelectionMode } from "./menu-options";
import { useI18n } from "./i18n/client";

export interface CartItem {
  /** Unique per menu item + exact customization, so identical setups merge. */
  lineId: string;
  menuItemId: string;
  name: string;
  /** Unit price INCLUDING selected options. Display only — server re-prices. */
  priceCents: number;
  quantity: number;
  selections: OptionSelection[];
  /** Chosen options; render with describeSelection(mode, name, t) so they follow the language. */
  optionSummary: { mode: SelectionMode; name: string }[];
  notes: string;
}

interface CartState {
  restaurantId: string | null;
  restaurantName: string | null;
  items: CartItem[];
}

export type NewCartLine = Omit<CartItem, "lineId" | "quantity">;

interface CartContextValue extends CartState {
  addItem: (
    restaurantId: string,
    restaurantName: string,
    item: NewCartLine,
    quantity?: number
  ) => boolean;
  updateQuantity: (lineId: string, quantity: number) => void;
  removeItem: (lineId: string) => void;
  clear: () => void;
  subtotalCents: number;
  itemCount: number;
  /** Increments on every successful add, so UI can play an animation. */
  addTick: number;
}

const CartContext = createContext<CartContextValue | null>(null);

export function CartProvider({ children }: { children: React.ReactNode }) {
  const [state, setState] = useState<CartState>({
    restaurantId: null,
    restaurantName: null,
    items: [],
  });
  const [addTick, setAddTick] = useState(0);
  const { t } = useI18n();

  /** Returns false if the user declined to replace a cart from another restaurant. */
  function addItem(
    restaurantId: string,
    restaurantName: string,
    item: NewCartLine,
    quantity = 1
  ) {
    const lineId = selectionKey(item.menuItemId, item.selections, item.notes);
    const line: CartItem = { ...item, lineId, quantity };

    // Cart can only hold items from one restaurant at a time. Ask outside the
    // state updater (updaters must be pure — React may run them twice).
    if (state.restaurantId && state.restaurantId !== restaurantId && state.items.length > 0) {
      const confirmed = window.confirm(
        t("Your cart has items from another restaurant. Clear it and start a new order?")
      );
      if (!confirmed) return false;
      setState({ restaurantId, restaurantName, items: [line] });
      setAddTick((t) => t + 1);
      return true;
    }

    setState((prev) => {
      const existing = prev.items.find((i) => i.lineId === lineId);
      const items = existing
        ? prev.items.map((i) =>
            i.lineId === lineId ? { ...i, quantity: Math.min(99, i.quantity + quantity) } : i
          )
        : [...prev.items, line];
      return { restaurantId, restaurantName, items };
    });
    setAddTick((t) => t + 1);
    return true;
  }

  function updateQuantity(lineId: string, quantity: number) {
    setState((prev) => ({
      ...prev,
      items:
        quantity <= 0
          ? prev.items.filter((i) => i.lineId !== lineId)
          : prev.items.map((i) =>
              i.lineId === lineId ? { ...i, quantity: Math.min(99, quantity) } : i
            ),
    }));
  }

  function removeItem(lineId: string) {
    updateQuantity(lineId, 0);
  }

  function clear() {
    setState({ restaurantId: null, restaurantName: null, items: [] });
  }

  const subtotalCents = state.items.reduce((sum, i) => sum + i.priceCents * i.quantity, 0);
  const itemCount = state.items.reduce((sum, i) => sum + i.quantity, 0);

  return (
    <CartContext.Provider
      value={{ ...state, addItem, updateQuantity, removeItem, clear, subtotalCents, itemCount, addTick }}
    >
      {children}
    </CartContext.Provider>
  );
}

/** Like useCart, but returns null outside a CartProvider (e.g. admin/driver shells). */
export function useOptionalCart() {
  return useContext(CartContext);
}

export function useCart() {
  const ctx = useContext(CartContext);
  if (!ctx) throw new Error("useCart must be used within CartProvider");
  return ctx;
}
