// Discounts & special offers on menu items. Shared by the UI and checkout,
// so the price a customer sees is exactly the price the server charges.

export const OFFER_FIELDS = "offer_price_cents, offer_label, offer_ends_at, is_featured";

export interface OfferFields {
  price_cents: number;
  offer_price_cents?: number | null;
  offer_label?: string | null;
  offer_ends_at?: string | null;
  is_featured?: boolean | null;
}

export interface ActiveOffer {
  /** Discounted base price (millimes). Equals the normal price when there is no discount. */
  priceCents: number;
  /** Normal base price, for the strike-through. */
  originalCents: number;
  /** Whole-number percentage off (0 when it is a featured item without discount). */
  percentOff: number;
  label: string | null;
  endsAt: string | null;
  featured: boolean;
}

function hasDiscount(item: OfferFields, now: number) {
  const offer = item.offer_price_cents;
  if (offer == null || offer < 0 || offer >= item.price_cents) return false;
  return !item.offer_ends_at || new Date(item.offer_ends_at).getTime() > now;
}

/** The active offer on an item, or null if it has neither a live discount nor the featured flag. */
export function activeOffer(item: OfferFields, now = Date.now()): ActiveOffer | null {
  const discounted = hasDiscount(item, now);
  const featured = !!item.is_featured;
  if (!discounted && !featured) return null;
  const priceCents = discounted ? item.offer_price_cents! : item.price_cents;
  return {
    priceCents,
    originalCents: item.price_cents,
    percentOff: discounted ? Math.round((1 - priceCents / item.price_cents) * 100) : 0,
    label: item.offer_label?.trim() || null,
    endsAt: discounted ? item.offer_ends_at ?? null : null,
    featured,
  };
}

/** Base price to charge right now (discount applied if live). Extras are never discounted. */
export function effectiveBasePrice(item: OfferFields, now = Date.now()) {
  return hasDiscount(item, now) ? item.offer_price_cents! : item.price_cents;
}
