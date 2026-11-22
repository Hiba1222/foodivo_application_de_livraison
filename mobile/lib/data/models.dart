// Plain data classes + the same pricing/option rules as web/lib/offers.ts and web/lib/menu-options.ts.
import '../core/i18n.dart';

int _int(Object? v) => v == null ? 0 : (v as num).toInt();
int? _intOrNull(Object? v) => v == null ? null : (v as num).toInt();

class Restaurant {
  final String id, name;
  final String? description, cuisineType, address, logoUrl, coverUrl;
  final bool isOpen;
  final int? prepMinutes;

  Restaurant.fromJson(Map<String, dynamic> j)
      : id = j['id'],
        name = j['name'] ?? '',
        description = j['description'],
        cuisineType = j['cuisine_type'],
        address = j['address'],
        logoUrl = j['logo_url'],
        coverUrl = j['cover_image_url'],
        isOpen = j['is_open'] ?? false,
        prepMinutes = _intOrNull(j['avg_prep_time_minutes']);
}

// ---------------- Offers ----------------

class ActiveOffer {
  final int priceCents, originalCents, percentOff;
  final String? label;
  final DateTime? endsAt;
  final bool featured;
  const ActiveOffer(this.priceCents, this.originalCents, this.percentOff, this.label, this.endsAt, this.featured);
}

// ---------------- Menu ----------------

enum GroupKind { choice, ingredients }

enum SelectionMode { add, extra, remove }

class MenuOption {
  final String id, name;
  final int priceCents, sortOrder;
  final bool isDefault, allowExtra, isAvailable;

  MenuOption.fromJson(Map<String, dynamic> j)
      : id = j['id'],
        name = j['name'] ?? '',
        priceCents = _int(j['price_cents']),
        sortOrder = _int(j['sort_order']),
        isDefault = j['is_default'] ?? false,
        allowExtra = j['allow_extra'] ?? true,
        isAvailable = j['is_available'] ?? true;
}

class OptionGroup {
  final String id, name;
  final GroupKind kind;
  final int minSelect, sortOrder;
  final int? maxSelect;
  final List<MenuOption> options;

  OptionGroup.fromJson(Map<String, dynamic> j)
      : id = j['id'],
        name = j['name'] ?? '',
        kind = j['kind'] == 'ingredients' ? GroupKind.ingredients : GroupKind.choice,
        minSelect = _int(j['min_select']),
        maxSelect = _intOrNull(j['max_select']),
        sortOrder = _int(j['sort_order']),
        options = ((j['menu_options'] as List?) ?? [])
            .map((o) => MenuOption.fromJson(o))
            .where((o) => o.isAvailable)
            .toList()
          ..sort((a, b) => a.sortOrder != b.sortOrder ? a.sortOrder - b.sortOrder : a.name.compareTo(b.name));

  bool get isRequired => kind == GroupKind.choice && minSelect > 0;

  /// "Choose 1", "Choose up to 3"… (same wording as the website)
  String ruleText(I18n i) {
    if (kind == GroupKind.ingredients) return i.t('Remove anything or ask for extra');
    final min = minSelect, max = maxSelect;
    if (max == 1) return i.t('Choose 1');
    if (max != null && min == max) return i.t('Choose {n}', {'n': min});
    if (max == null) return min > 0 ? i.t('Choose at least {n}', {'n': min}) : i.t('Choose as many as you like');
    return min > 0 ? i.t('Choose {min} to {max}', {'min': min, 'max': max}) : i.t('Choose up to {n}', {'n': max});
  }
}

class MenuItem {
  final String id, name, restaurantId;
  final String? description, imageUrl, categoryId, offerLabel;
  final int priceCents;
  final int? offerPriceCents;
  final DateTime? offerEndsAt;
  final bool isFeatured;
  final List<OptionGroup> groups;

  MenuItem.fromJson(Map<String, dynamic> j)
      : id = j['id'],
        name = j['name'] ?? '',
        restaurantId = j['restaurant_id'] ?? '',
        description = j['description'],
        imageUrl = j['image_url'],
        categoryId = j['category_id'],
        priceCents = _int(j['price_cents']),
        offerPriceCents = _intOrNull(j['offer_price_cents']),
        offerLabel = (j['offer_label'] as String?)?.trim().isEmpty == true ? null : j['offer_label'],
        offerEndsAt = j['offer_ends_at'] == null ? null : DateTime.parse(j['offer_ends_at']),
        isFeatured = j['is_featured'] ?? false,
        groups = ((j['menu_option_groups'] as List?) ?? [])
            .map((g) => OptionGroup.fromJson(g))
            .where((g) => g.options.isNotEmpty)
            .toList()
          ..sort((a, b) => a.sortOrder != b.sortOrder ? a.sortOrder - b.sortOrder : a.name.compareTo(b.name));

  bool _hasDiscount(DateTime now) {
    final o = offerPriceCents;
    if (o == null || o < 0 || o >= priceCents) return false;
    return offerEndsAt == null || offerEndsAt!.isAfter(now);
  }

  /// Same logic as activeOffer() on the website.
  ActiveOffer? get offer {
    final now = DateTime.now();
    final discounted = _hasDiscount(now);
    if (!discounted && !isFeatured) return null;
    final price = discounted ? offerPriceCents! : priceCents;
    return ActiveOffer(
      price,
      priceCents,
      discounted ? ((1 - price / priceCents) * 100).round() : 0,
      offerLabel,
      discounted ? offerEndsAt : null,
      isFeatured,
    );
  }

  /// Base price charged right now (extras are never discounted).
  int get basePrice => _hasDiscount(DateTime.now()) ? offerPriceCents! : priceCents;
}

class Category {
  final String id, name;
  Category(this.id, this.name);
}

// ---------------- Selections & pricing ----------------

class Selection {
  final String optionId;
  final SelectionMode mode;
  const Selection(this.optionId, this.mode);
  Map<String, dynamic> toJson() => {'optionId': optionId, 'mode': mode.name};
}

class PricedSelection {
  final String optionId, optionName;
  final SelectionMode mode;
  final int priceCents;
  const PricedSelection(this.optionId, this.optionName, this.mode, this.priceCents);
}

class Evaluation {
  final int unitPriceCents;
  final List<PricedSelection> priced;
  final Map<String, String> groupErrors;
  const Evaluation(this.unitPriceCents, this.priced, this.groupErrors);
}

/// Mirror of evaluateSelections() — live price + min/max errors in the item sheet.
/// The server (place_order) re-checks everything.
Evaluation evaluateSelections(int basePrice, List<OptionGroup> groups, List<Selection> selections, I18n i) {
  final index = <String, (OptionGroup, MenuOption)>{};
  for (final g in groups) {
    for (final o in g.options) {
      index[o.id] = (g, o);
    }
  }
  var unit = basePrice;
  final priced = <PricedSelection>[];
  final counts = <String, int>{};
  for (final s in selections) {
    final hit = index[s.optionId];
    if (hit == null) continue;
    final (g, o) = hit;
    final price = s.mode == SelectionMode.remove ? 0 : o.priceCents;
    unit += price;
    priced.add(PricedSelection(o.id, o.name, s.mode, price));
    if (g.kind == GroupKind.choice) counts[g.id] = (counts[g.id] ?? 0) + 1;
  }
  final errors = <String, String>{};
  for (final g in groups) {
    if (g.kind != GroupKind.choice) continue;
    final c = counts[g.id] ?? 0;
    if (c < g.minSelect) {
      errors[g.id] = g.minSelect == 1 ? i.t('Please choose an option') : i.t('Choose at least {n}', {'n': g.minSelect});
    } else if (g.maxSelect != null && c > g.maxSelect!) {
      errors[g.id] = i.t('Choose at most {n}', {'n': g.maxSelect});
    }
  }
  return Evaluation(unit, priced, errors);
}

String describeSelection(SelectionMode mode, String name, I18n i) => switch (mode) {
      SelectionMode.extra => i.t('Extra {name}', {'name': name}),
      SelectionMode.remove => i.t('No {name}', {'name': name}),
      SelectionMode.add => name,
    };

// ---------------- Orders ----------------

class OrderSummary {
  final String id, status, createdAt;
  final String? restaurantName;
  final int totalCents;

  OrderSummary.fromJson(Map<String, dynamic> j)
      : id = j['id'],
        status = j['status'],
        createdAt = j['created_at'],
        restaurantName = (j['restaurants'] as Map?)?['name'],
        totalCents = _int(j['total_cents']);

  static const active = {'pending', 'accepted', 'ready_for_pickup', 'driver_assigned', 'picked_up'};
  bool get isActive => active.contains(status);
}

class Address {
  final String id, line;
  final String? label;
  final bool isDefault;
  Address.fromJson(Map<String, dynamic> j)
      : id = j['id'],
        line = j['address_line'] ?? '',
        label = j['label'],
        isDefault = j['is_default'] ?? false;
}

class DriverInfo {
  final String name;
  final String? phone, avatarUrl, vehicle;
  final double? lat, lng;
  DriverInfo.fromJson(Map<String, dynamic> j)
      : name = j['full_name'] ?? '',
        phone = j['phone'],
        avatarUrl = j['avatar_url'],
        vehicle = [j['vehicle_type'], j['license_plate']].whereType<String>().where((s) => s.isNotEmpty).join(' · '),
        lat = (j['current_latitude'] as num?)?.toDouble(),
        lng = (j['current_longitude'] as num?)?.toDouble();
}
