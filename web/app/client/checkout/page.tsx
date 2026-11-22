"use client";

import { formatPrice, DELIVERY_FEE } from "@/lib/currency";
import { useEffect, useState } from "react";
import { useRouter } from "next/navigation";
import { createClient } from "@/lib/supabase/client";
import { useCart } from "@/lib/cart-context";
import { useI18n } from "@/lib/i18n/client";
import { addAddress, placeOrder } from "../actions";

interface Address {
  id: string;
  label: string | null;
  address_line: string;
  is_default: boolean;
}


export default function CheckoutPage() {
  const router = useRouter();
  const supabase = createClient();
  const { items, restaurantId, restaurantName, subtotalCents, clear } = useCart();
  const { t } = useI18n();

  const [addresses, setAddresses] = useState<Address[]>([]);
  const [selectedAddressId, setSelectedAddressId] = useState<string>("");
  const [notes, setNotes] = useState("");
  const [showAddForm, setShowAddForm] = useState(false);
  const [placing, setPlacing] = useState(false);
  const [error, setError] = useState<string | null>(null);

  async function loadAddresses() {
    const {
      data: { user },
    } = await supabase.auth.getUser();
    if (!user) return;
    const { data } = await supabase
      .from("client_addresses")
      .select("id, label, address_line, is_default")
      .eq("client_id", user.id)
      .order("is_default", { ascending: false });
    setAddresses(data ?? []);
    if (data && data.length > 0) setSelectedAddressId(data[0].id);
  }

  useEffect(() => {
    loadAddresses();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  async function handleAddAddress(formData: FormData) {
    await addAddress(formData);
    setShowAddForm(false);
    await loadAddresses();
  }

  async function handlePlaceOrder() {
    if (!restaurantId || !selectedAddressId) return;
    setPlacing(true);
    setError(null);
    try {
      const orderId = await placeOrder({
        restaurantId,
        addressId: selectedAddressId,
        items: items.map((i) => ({
          menuItemId: i.menuItemId,
          quantity: i.quantity,
          selections: i.selections,
          notes: i.notes || undefined,
        })),
        notes: notes || undefined,
      });
      clear();
      router.push(`/client/orders/${orderId}`);
    } catch (e) {
      setError(e instanceof Error ? e.message : t("Something went wrong"));
      setPlacing(false);
    }
  }

  if (items.length === 0) {
    return <p className="py-16 text-center text-slate-500">{t("Your cart is empty.")}</p>;
  }

  return (
    <div className="max-w-xl">
      <h1 className="text-xl font-bold text-slate-900">{t("Checkout")}</h1>
      <p className="mt-1 text-sm text-slate-500">{t("Order from {name}", { name: restaurantName ?? "" })}</p>

      <div className="mt-6">
        <h2 className="text-sm font-semibold text-slate-900">{t("Delivery address")}</h2>
        <div className="mt-2 space-y-2">
          {addresses.map((addr) => (
            <label
              key={addr.id}
              className="flex items-center gap-3 rounded-xl border border-slate-200 bg-white p-3 text-sm"
            >
              <input
                type="radio"
                name="address"
                checked={selectedAddressId === addr.id}
                onChange={() => setSelectedAddressId(addr.id)}
              />
              <span>
                <span className="font-medium text-slate-900">{addr.label}</span>{" "}
                <span className="text-slate-500">— {addr.address_line}</span>
              </span>
            </label>
          ))}
        </div>

        {!showAddForm ? (
          <button
            onClick={() => setShowAddForm(true)}
            className="mt-2 text-sm font-medium text-brand-600"
          >
            + {t("Add a new address")}
          </button>
        ) : (
          <form action={handleAddAddress} className="mt-3 space-y-2 rounded-xl bg-white p-4 ring-1 ring-slate-200">
            <input
              name="label"
              placeholder={t("Label (e.g. Home)")}
              className="w-full rounded-lg border border-slate-300 px-3 py-2 text-sm"
            />
            <input
              name="address_line"
              required
              placeholder={t("Full address")}
              className="w-full rounded-lg border border-slate-300 px-3 py-2 text-sm"
            />
            <label className="flex items-center gap-2 text-xs text-slate-500">
              <input type="checkbox" name="is_default" /> {t("Set as default")}
            </label>
            <button
              type="submit"
              className="rounded-lg bg-slate-800 px-3 py-1.5 text-xs font-semibold text-white"
            >
              {t("Save address")}
            </button>
          </form>
        )}
      </div>

      <div className="mt-6">
        <h2 className="text-sm font-semibold text-slate-900">{t("Notes for the restaurant (optional)")}</h2>
        <textarea
          value={notes}
          onChange={(e) => setNotes(e.target.value)}
          rows={2}
          placeholder={t("Allergies, delivery instructions…")}
          className="mt-2 w-full rounded-lg border border-slate-300 px-3 py-2 text-sm"
        />
      </div>

      <div className="mt-6 space-y-1 rounded-2xl bg-white p-5 shadow-sm ring-1 ring-slate-200">
        <div className="flex justify-between text-sm text-slate-600">
          <span>{t("Subtotal")}</span>
          <span>{formatPrice(subtotalCents)}</span>
        </div>
        <div className="flex justify-between text-sm text-slate-600">
          <span>{t("Delivery fee")}</span>
          <span>{formatPrice(DELIVERY_FEE)}</span>
        </div>
        <div className="flex justify-between border-t border-slate-100 pt-2 text-base font-bold text-slate-900">
          <span>{t("Total")}</span>
          <span>{formatPrice((subtotalCents + DELIVERY_FEE))}</span>
        </div>
      </div>

      {error && <p className="mt-3 text-sm text-red-600">{error}</p>}

      <button
        onClick={handlePlaceOrder}
        disabled={placing || !selectedAddressId}
        className="mt-4 w-full rounded-lg bg-brand-600 px-4 py-3 text-sm font-semibold text-white hover:bg-brand-700 disabled:opacity-50"
      >
        {placing ? t("Placing order…") : t("Place order")}
      </button>
    </div>
  );
}
