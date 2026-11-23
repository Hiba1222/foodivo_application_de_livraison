/// Deterministic 4-digit verification codes from an order UUID (mirrors web/lib/order-codes.ts).

int _hexTo4Digits(String hex) => int.parse(hex, radix: 16) % 9000 + 1000;

/// Shown to the restaurant and driver — restaurant uses it to verify the driver picking up.
String pickupCode(String orderId) {
  final hex = orderId.replaceAll('-', '').substring(0, 8);
  return _hexTo4Digits(hex).toString();
}

/// Shown to the client and driver — driver uses it to confirm they have the right client.
String deliveryCode(String orderId) {
  final hex = orderId.replaceAll('-', '');
  return _hexTo4Digits(hex.substring(hex.length - 8)).toString();
}
