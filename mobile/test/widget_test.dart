import 'package:flutter_test/flutter_test.dart';
import 'package:foodivo/core/money.dart';
import 'package:foodivo/data/models.dart';

void main() {
  test('prices format as TND millimes', () {
    expect(formatPrice(7500), '7.500 TND');
    expect(formatPrice(0), '0.000 TND');
  });

  test('live offer lowers the base price; expired offer does not', () {
    final live = MenuItem.fromJson({
      'id': 'a', 'name': 'Pizza', 'price_cents': 12500, 'offer_price_cents': 9900,
      'offer_ends_at': DateTime.now().add(const Duration(days: 1)).toIso8601String(),
    });
    expect(live.basePrice, 9900);
    expect(live.offer!.percentOff, 21);

    final expired = MenuItem.fromJson({
      'id': 'b', 'name': 'Pizza', 'price_cents': 12500, 'offer_price_cents': 9900,
      'offer_ends_at': DateTime.now().subtract(const Duration(days: 1)).toIso8601String(),
    });
    expect(expired.basePrice, 12500);
    expect(expired.offer, isNull);
  });
}
