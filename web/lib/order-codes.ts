/** Deterministic 4-digit verification codes derived from the order UUID (no DB change needed). */

function hexTo4Digits(hex: string): string {
  return String((parseInt(hex, 16) % 9000) + 1000);
}

/** Shown to the restaurant and driver — restaurant uses it to verify the driver picking up. */
export function pickupCode(orderId: string): string {
  return hexTo4Digits(orderId.replace(/-/g, "").slice(0, 8));
}

/** Shown to the client and driver — driver uses it to confirm they have the right client. */
export function deliveryCode(orderId: string): string {
  return hexTo4Digits(orderId.replace(/-/g, "").slice(-8));
}
