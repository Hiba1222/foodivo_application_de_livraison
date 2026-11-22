import 'package:flutter/foundation.dart';

import '../data/models.dart';

class CartLine {
  /// Same menu item + same choices + same notes => same line (quantities merge).
  final String lineId;
  final String menuItemId, name;
  final String? imageUrl;
  final int unitPriceCents;
  final List<Selection> selections;
  final List<PricedSelection> summary;
  final String notes;
  int quantity;

  CartLine({
    required this.lineId,
    required this.menuItemId,
    required this.name,
    required this.imageUrl,
    required this.unitPriceCents,
    required this.selections,
    required this.summary,
    required this.notes,
    required this.quantity,
  });

  Map<String, dynamic> toOrderJson() => {
        'menuItemId': menuItemId,
        'quantity': quantity,
        'notes': notes.isEmpty ? null : notes,
        'selections': selections.map((s) => s.toJson()).toList(),
      };
}

class Cart extends ChangeNotifier {
  String? restaurantId, restaurantName;
  final List<CartLine> lines = [];

  /// Bumps on every add — UI uses it to play the "pop" animation.
  int addTick = 0;

  int get itemCount => lines.fold(0, (s, l) => s + l.quantity);
  int get subtotal => lines.fold(0, (s, l) => s + l.unitPriceCents * l.quantity);
  bool get isEmpty => lines.isEmpty;

  bool isOtherRestaurant(String id) => restaurantId != null && restaurantId != id && lines.isNotEmpty;

  static String _key(String itemId, List<Selection> sel, String notes) {
    final s = sel.map((e) => '${e.optionId}:${e.mode.name}').toList()..sort();
    return '$itemId|${s.join(',')}|${notes.trim().toLowerCase()}';
  }

  /// Call [isOtherRestaurant] first and confirm with the user before replacing.
  void add({
    required String restaurantId,
    required String restaurantName,
    required MenuItem item,
    required int unitPriceCents,
    required List<Selection> selections,
    required List<PricedSelection> summary,
    required String notes,
    required int quantity,
  }) {
    if (isOtherRestaurant(restaurantId)) lines.clear();
    this.restaurantId = restaurantId;
    this.restaurantName = restaurantName;
    final key = _key(item.id, selections, notes);
    final existing = lines.where((l) => l.lineId == key).firstOrNull;
    if (existing != null) {
      existing.quantity = (existing.quantity + quantity).clamp(1, 99);
    } else {
      lines.add(CartLine(
        lineId: key,
        menuItemId: item.id,
        name: item.name,
        imageUrl: item.imageUrl,
        unitPriceCents: unitPriceCents,
        selections: selections,
        summary: summary,
        notes: notes.trim(),
        quantity: quantity,
      ));
    }
    addTick++;
    notifyListeners();
  }

  void setQuantity(String lineId, int q) {
    if (q <= 0) {
      lines.removeWhere((l) => l.lineId == lineId);
    } else {
      lines.firstWhere((l) => l.lineId == lineId).quantity = q.clamp(1, 99);
    }
    if (lines.isEmpty) restaurantId = restaurantName = null;
    notifyListeners();
  }

  void clear() {
    lines.clear();
    restaurantId = restaurantName = null;
    notifyListeners();
  }
}
