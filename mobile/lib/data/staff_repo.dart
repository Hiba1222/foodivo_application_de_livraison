// Restaurant-owner and driver data access — same queries/rules as
// web/app/restaurant/actions.ts and web/app/driver/actions.ts.
import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import 'repo.dart';

const _offerFields = 'offer_price_cents, offer_label, offer_ends_at, is_featured';
const orderItemsSelect =
    'order_items(quantity, unit_price_cents, notes, menu_items(name), order_item_options(group_name, option_name, mode, price_cents))';
const _editorGroupSelect =
    'id, name, kind, min_select, max_select, sort_order, created_at, menu_options(id, name, price_cents, is_default, allow_extra, is_available, sort_order)';

String get _uid => sb.auth.currentUser!.id;

/// "7.5" / "7,500" -> 7500 millimes. Invalid or negative -> 0 (web parsePrice()).
int parsePrice(String raw) {
  final n = double.tryParse(raw.trim().replaceAll(',', '.'));
  return n != null && n > 0 ? (n * 1000).round() : 0;
}

/// 7500 -> "7.500" (value for a price field).
String priceInput(int millimes) => (millimes / 1000).toStringAsFixed(3);

DateTime _startOfToday() {
  final n = DateTime.now();
  return DateTime(n.year, n.month, n.day);
}

/// Ready-made option groups (web OPTION_TEMPLATES). Names are English keys, translated on insert.
class OptionTemplate {
  final String key, label, hint, name, kind;
  final int min;
  final int? max;
  final List<(String, int, bool)> options; // name, price, isDefault
  const OptionTemplate(this.key, this.label, this.hint, this.name, this.kind, this.min, this.max, this.options);
}

const optionTemplates = [
  OptionTemplate('bread', 'Bread choice', 'Required · pick 1', 'Choose your bread', 'choice', 1, 1, [
    ('Baguette', 0, true),
    ('Mlawi', 500, false),
    ('Chapati', 500, false),
    ('Libanais (wrap)', 0, false),
    ('Panini bread', 500, false),
  ]),
  OptionTemplate('ingredients', 'Ingredients', 'No / Regular / Extra', "What's inside", 'ingredients', 0, null, [
    ('Harissa', 0, false),
    ('Lettuce', 0, false),
    ('Tomato', 0, false),
    ('Onion', 0, false),
    ('Olives', 0, false),
    ('Cheese', 1000, false),
  ]),
  OptionTemplate('extras', 'Paid extras', 'Optional · any number', 'Add extras', 'choice', 0, null, [
    ('Extra cheese', 1000, false),
    ('Egg', 500, false),
    ('Tuna', 1500, false),
    ('Double meat', 3000, false),
    ('Fries inside', 1000, false),
  ]),
  OptionTemplate('sauces', 'Sauces', 'Optional · up to 2', 'Sauces', 'choice', 0, 2, [
    ('Mayonnaise', 0, false),
    ('Ketchup', 0, false),
    ('Algerian', 0, false),
    ('Samurai', 0, false),
    ('BBQ', 0, false),
  ]),
];

/// Normalises min/max so the rules are always satisfiable (web groupRules()).
(int, int?) groupRules(String kind, int? min, int? max) {
  if (kind == 'ingredients') return (0, null);
  final minSel = (min ?? 0) < 0 ? 0 : (min ?? 0);
  int? maxSel = max == null ? null : (max < 1 ? 1 : max);
  if (maxSel != null && maxSel < minSel) maxSel = minSel;
  return (minSel, maxSel);
}

class RestaurantRepo {
  static Future<Map<String, dynamic>?> mine() =>
      sb.from('restaurants').select().eq('owner_id', _uid).maybeSingle();

  static Future<void> create(Map<String, dynamic> fields) async {
    await sb.from('restaurants').insert({
      'owner_id': _uid,
      ...fields,
      // Same placeholder coordinates as the website (no geocoding yet).
      'latitude': 52.3759,
      'longitude': 9.732,
    });
  }

  static Future<void> update(String id, Map<String, dynamic> fields) => sb.from('restaurants').update(fields).eq('id', id);

  static Future<void> setOpen(String id, bool open) => update(id, {'is_open': open});

  static Future<(int, int, int)> stats(String id) async {
    final r = await Future.wait([
      sb.from('orders').select('id').eq('restaurant_id', id).eq('status', 'pending'),
      sb.from('orders').select('id').eq('restaurant_id', id).inFilter('status', ['accepted', 'ready_for_pickup', 'driver_assigned', 'picked_up']),
      sb.from('orders').select('total_cents').eq('restaurant_id', id).gte('created_at', _startOfToday().toUtc().toIso8601String()),
    ]);
    final revenue = (r[2] as List).fold<int>(0, (s, o) => s + ((o['total_cents'] as num?)?.toInt() ?? 0));
    return ((r[0] as List).length, (r[1] as List).length, revenue);
  }

  static Future<List<Map<String, dynamic>>> orders(String id) => sb
      .from('orders')
      .select('id, status, total_cents, created_at, notes, profiles!orders_client_id_fkey(full_name, phone), $orderItemsSelect')
      .eq('restaurant_id', id)
      .order('created_at', ascending: false)
      .limit(50);

  static const _allowed = {
    'pending': ['accepted', 'rejected'],
    'accepted': ['ready_for_pickup'],
  };

  static Future<void> setOrderStatus(String orderId, String newStatus) async {
    final order = await sb.from('orders').select('status').eq('id', orderId).single();
    if (!(_allowed[order['status']] ?? const []).contains(newStatus)) {
      throw Exception('Cannot move order from ${order['status']} to $newStatus');
    }
    final ts = newStatus == 'accepted' ? 'accepted_at' : newStatus == 'ready_for_pickup' ? 'ready_at' : null;
    await sb.from('orders').update({
      'status': newStatus,
      ?ts: DateTime.now().toUtc().toIso8601String(),
    }).eq('id', orderId);
    await sb.from('order_status_history').insert({'order_id': orderId, 'status': newStatus, 'changed_by': _uid});
  }

  // ---------- Menu ----------
  static Future<(List<Map<String, dynamic>>, List<Map<String, dynamic>>)> menu(String restaurantId) async {
    final r = await Future.wait([
      sb.from('menu_categories').select('id, name').eq('restaurant_id', restaurantId).order('sort_order'),
      sb
          .from('menu_items')
          .select('id, name, description, price_cents, $_offerFields, is_available, category_id, image_url, menu_option_groups(count)')
          .eq('restaurant_id', restaurantId)
          .order('name'),
    ]);
    return (r[0], r[1]);
  }

  static Future<void> addCategory(String restaurantId, String name) =>
      sb.from('menu_categories').insert({'restaurant_id': restaurantId, 'name': name});

  static Future<String> addItem(String restaurantId, {required String name, required int price, String? categoryId, String? description}) async {
    final row = await sb
        .from('menu_items')
        .insert({
          'restaurant_id': restaurantId,
          'category_id': categoryId,
          'name': name,
          'description': description,
          'price_cents': price,
        })
        .select('id')
        .single();
    return row['id'] as String;
  }

  static Future<Map<String, dynamic>?> item(String restaurantId, String itemId) => sb
      .from('menu_items')
      .select('id, name, description, price_cents, $_offerFields, category_id, image_url, is_available, menu_option_groups($_editorGroupSelect)')
      .eq('id', itemId)
      .eq('restaurant_id', restaurantId)
      .maybeSingle();

  static Future<List<Map<String, dynamic>>> otherItemsWithOptions(String restaurantId, String itemId) async {
    final rows = await sb.from('menu_items').select('id, name, menu_option_groups(count)').eq('restaurant_id', restaurantId).neq('id', itemId).order('name');
    return rows.where((i) => ((i['menu_option_groups'] as List?)?.firstOrNull?['count'] ?? 0) > 0).toList();
  }

  static Future<void> updateItem(String itemId, Map<String, dynamic> fields) => sb.from('menu_items').update(fields).eq('id', itemId);
  static Future<void> deleteItem(String itemId) => sb.from('menu_items').delete().eq('id', itemId);

  static Future<void> setOffer(String itemId, {int? offerPrice, String? label, DateTime? endsAt, required bool featured}) => updateItem(itemId, {
        'offer_price_cents': offerPrice,
        'offer_label': (label == null || label.trim().isEmpty) ? null : label.trim().substring(0, label.trim().length.clamp(0, 40)),
        'offer_ends_at': endsAt?.toUtc().toIso8601String(),
        'is_featured': featured,
      });

  static Future<void> clearOffer(String itemId) =>
      updateItem(itemId, {'offer_price_cents': null, 'offer_label': null, 'offer_ends_at': null, 'is_featured': false});

  // ---------- Option groups ----------
  static Future<int> _nextGroupSort(String itemId) async {
    final rows = await sb.from('menu_option_groups').select('sort_order').eq('menu_item_id', itemId).order('sort_order', ascending: false).limit(1);
    return rows.isEmpty ? 0 : ((rows.first['sort_order'] as num?)?.toInt() ?? -1) + 1;
  }

  static Future<void> _insertGroup(String itemId, String name, String kind, int min, int? max, List<Map<String, dynamic>> options, int sort) async {
    final g = await sb
        .from('menu_option_groups')
        .insert({'menu_item_id': itemId, 'name': name, 'kind': kind, 'min_select': min, 'max_select': max, 'sort_order': sort})
        .select('id')
        .single();
    if (options.isEmpty) return;
    await sb.from('menu_options').insert([
      for (var i = 0; i < options.length; i++)
        {
          'group_id': g['id'],
          'name': options[i]['name'],
          'price_cents': options[i]['price_cents'] ?? 0,
          'is_default': options[i]['is_default'] ?? false,
          'allow_extra': options[i]['allow_extra'] ?? true,
          'is_available': options[i]['is_available'] ?? true,
          'sort_order': i,
        }
    ]);
  }

  static Future<void> addGroup(String itemId, {required String name, required String kind, required bool required, int? max}) async {
    final (mn, mx) = groupRules(kind, required ? 1 : 0, max);
    await _insertGroup(itemId, name, kind, mn, mx, [], await _nextGroupSort(itemId));
  }

  static Future<void> addGroupFromTemplate(String itemId, OptionTemplate t, String Function(String) tr) async {
    await _insertGroup(
      itemId,
      tr(t.name),
      t.kind,
      t.min,
      t.max,
      [for (final o in t.options) {'name': tr(o.$1), 'price_cents': o.$2, 'is_default': o.$3}],
      await _nextGroupSort(itemId),
    );
  }

  static Future<void> copyGroups(String targetItemId, String sourceItemId) async {
    final groups = await sb
        .from('menu_option_groups')
        .select('name, kind, min_select, max_select, sort_order, menu_options(name, price_cents, is_default, allow_extra, is_available, sort_order)')
        .eq('menu_item_id', sourceItemId)
        .order('sort_order');
    var sort = await _nextGroupSort(targetItemId);
    for (final g in groups) {
      final opts = [...((g['menu_options'] as List?) ?? []).cast<Map<String, dynamic>>()]
        ..sort((a, b) => ((a['sort_order'] as num?) ?? 0).compareTo((b['sort_order'] as num?) ?? 0));
      await _insertGroup(targetItemId, g['name'], g['kind'], (g['min_select'] as num).toInt(), (g['max_select'] as num?)?.toInt(), opts, sort++);
    }
  }

  static Future<void> updateGroup(String groupId, {required String name, required String kind, int? min, int? max}) async {
    final (mn, mx) = groupRules(kind, min, max);
    await sb.from('menu_option_groups').update({'name': name.isEmpty ? 'Options' : name, 'kind': kind, 'min_select': mn, 'max_select': mx}).eq('id', groupId);
  }

  static Future<void> deleteGroup(String groupId) => sb.from('menu_option_groups').delete().eq('id', groupId);

  static Future<void> moveGroup(String itemId, String groupId, int delta) async {
    final rows = await sb.from('menu_option_groups').select('id').eq('menu_item_id', itemId).order('sort_order').order('created_at');
    final ids = rows.map((r) => r['id'] as String).toList();
    final from = ids.indexOf(groupId), to = from + delta;
    if (from < 0 || to < 0 || to >= ids.length) return;
    final tmp = ids[from];
    ids[from] = ids[to];
    ids[to] = tmp;
    await Future.wait([for (var i = 0; i < ids.length; i++) sb.from('menu_option_groups').update({'sort_order': i}).eq('id', ids[i])]);
  }

  static Future<void> addOption(String groupId, String name, int price) async {
    final last = await sb.from('menu_options').select('sort_order').eq('group_id', groupId).order('sort_order', ascending: false).limit(1);
    await sb.from('menu_options').insert({
      'group_id': groupId,
      'name': name,
      'price_cents': price,
      'sort_order': last.isEmpty ? 0 : ((last.first['sort_order'] as num?)?.toInt() ?? -1) + 1,
    });
  }

  static Future<void> updateOption(String optionId, Map<String, dynamic> fields) => sb.from('menu_options').update(fields).eq('id', optionId);
  static Future<void> deleteOption(String optionId) => sb.from('menu_options').delete().eq('id', optionId);

  // ---------- Images (same bucket/paths as the website's ImageUploader) ----------
  static Future<String> uploadImage({
    required Uint8List bytes,
    required String storagePath,
    required String table,
    required String column,
    required String rowId,
  }) async {
    await sb.storage.from('media').uploadBinary(storagePath, bytes, fileOptions: const FileOptions(upsert: true, cacheControl: '3600', contentType: 'image/jpeg'));
    final url = '${sb.storage.from('media').getPublicUrl(storagePath)}?t=${DateTime.now().millisecondsSinceEpoch}';
    await sb.from(table).update({column: url}).eq('id', rowId);
    return url;
  }
}

class DriverRepo {
  static Future<Map<String, dynamic>?> mine() => sb.from('driver_profiles').select().eq('id', _uid).maybeSingle();

  static Future<void> create({required String vehicle, String? plate, String? phone}) async {
    await sb.from('driver_profiles').insert({'id': _uid, 'vehicle_type': vehicle, 'license_plate': plate});
    if (phone != null && phone.isNotEmpty) await sb.from('profiles').update({'phone': phone}).eq('id', _uid);
  }

  static Future<void> update({required String vehicle, String? plate, required String phone}) async {
    await sb.from('driver_profiles').update({'vehicle_type': vehicle, 'license_plate': plate}).eq('id', _uid);
    await sb.from('profiles').update({'phone': phone}).eq('id', _uid);
  }

  static Future<void> setOnline(bool online) => sb.from('driver_profiles').update({'is_online': online}).eq('id', _uid);

  static Future<void> updateLocation(double lat, double lng) async {
    await sb.from('driver_profiles').update({
      'current_latitude': lat,
      'current_longitude': lng,
      'last_location_update': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', _uid);
    await sb.from('driver_locations_history').insert({'driver_id': _uid, 'latitude': lat, 'longitude': lng});
  }

  static Future<(int, int, int)> stats() async {
    final r = await Future.wait([
      sb.from('orders').select('id').eq('driver_id', _uid).inFilter('status', ['driver_assigned', 'picked_up']),
      sb.from('orders').select('delivery_fee_cents').eq('driver_id', _uid).eq('status', 'delivered').gte('delivered_at', _startOfToday().toUtc().toIso8601String()),
    ]);
    final today = r[1] as List;
    final earned = today.fold<int>(0, (s, o) => s + ((o['delivery_fee_cents'] as num?)?.toInt() ?? 0));
    return ((r[0] as List).length, today.length, earned);
  }

  static Future<List<Map<String, dynamic>>> available() => sb
      .from('orders')
      .select('id, delivery_fee_cents, created_at, restaurants(name, address), client_addresses(address_line)')
      .eq('status', 'ready_for_pickup')
      .isFilter('driver_id', null)
      .order('ready_at', ascending: true);

  static Future<List<Map<String, dynamic>>> active() => sb
      .from('orders')
      .select('id, status, total_cents, restaurants(name, address, phone), client_addresses(address_line, latitude, longitude), profiles!orders_client_id_fkey(full_name, phone)')
      .eq('driver_id', _uid)
      .inFilter('status', ['driver_assigned', 'picked_up'])
      .order('created_at', ascending: true);

  static Future<List<Map<String, dynamic>>> history() => sb
      .from('orders')
      .select('id, delivery_fee_cents, delivered_at, restaurants(name)')
      .eq('driver_id', _uid)
      .eq('status', 'delivered')
      .order('delivered_at', ascending: false)
      .limit(100);

  /// Only succeeds if the order is still unassigned — guards against two drivers accepting at once.
  static Future<bool> accept(String orderId) async {
    final row = await sb
        .from('orders')
        .update({'driver_id': _uid, 'status': 'driver_assigned'})
        .eq('id', orderId)
        .eq('status', 'ready_for_pickup')
        .isFilter('driver_id', null)
        .select('id')
        .maybeSingle();
    if (row == null) return false;
    await sb.from('order_status_history').insert({'order_id': orderId, 'status': 'driver_assigned', 'changed_by': _uid});
    return true;
  }

  static Future<void> markPickedUp(String orderId) async {
    await sb.from('orders').update({'status': 'picked_up', 'picked_up_at': DateTime.now().toUtc().toIso8601String()}).eq('id', orderId).eq('driver_id', _uid);
    await sb.from('order_status_history').insert({'order_id': orderId, 'status': 'picked_up', 'changed_by': _uid});
  }

  static Future<void> markDelivered(String orderId) async {
    await sb.from('orders').update({
      'status': 'delivered',
      'delivered_at': DateTime.now().toUtc().toIso8601String(),
      'payment_status': 'paid',
    }).eq('id', orderId).eq('driver_id', _uid);
    await sb.from('order_status_history').insert({'order_id': orderId, 'status': 'delivered', 'changed_by': _uid});
  }
}
