// All money in the app is Tunisian dinar (TND), stored as integer MILLIMES
// (1 TND = 1000 millimes). DB columns keep their historical "*_cents" names,
// but the values are millimes.

export const CURRENCY = "TND";
export const MINOR_PER_UNIT = 1000;

/** Flat delivery fee: 2.500 TND. */
export const DELIVERY_FEE = 2500;

/** Step for <input type="number"> price fields (1 millime). */
export const PRICE_STEP = "0.001";

/** 7500 -> "7.500 TND" */
export function formatPrice(millimes: number) {
  return `${(millimes / MINOR_PER_UNIT).toFixed(3)} ${CURRENCY}`;
}

/** 7500 -> "7.500" (value for a price input). */
export function priceInputValue(millimes: number) {
  return (millimes / MINOR_PER_UNIT).toFixed(3);
}

/** "7.5" / "7,500" -> 7500. Invalid or negative input -> 0. */
export function parsePrice(value: FormDataEntryValue | string | null | undefined) {
  const n = parseFloat(String(value ?? "").replace(",", "."));
  return Number.isFinite(n) && n > 0 ? Math.round(n * MINOR_PER_UNIT) : 0;
}
