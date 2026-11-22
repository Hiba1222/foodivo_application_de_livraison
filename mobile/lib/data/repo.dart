import 'package:supabase_flutter/supabase_flutter.dart';

import 'models.dart';

SupabaseClient get sb => Supabase.instance.client;

const _offerFields = 'offer_price_cents, offer_label, offer_ends_at, is_featured';
const _groupSelect =
    'id, name, kind, min_select, max_select, sort_order, menu_options(id, name, price_cents, is_default, allow_extra, is_available, sort_order)';

/// All Supabase reads/writes the customer app needs (same queries as the website).
class Repo {
  // ---------- Profile ----------
  static Future<Map<String, dynamic>?> myProfile() async {
    final user = sb.auth.currentUser;
    if (user == null) return null;
    return sb.from('profiles').select('id, role, full_name, phone, avatar_url').eq('id', user.id).maybeSingle();
  }

  static Future<void> updatePhone(String phone) async {
    await sb.from('profiles').update({'phone': phone}).eq('id', sb.auth.currentUser!.id);
  }

  // ---------- Browse ----------
  static Future<List<Restaurant>> restaurants() async {
    final rows = await sb
        .from('restaurants')
        .select('id, name, description, cuisine_type, address, is_open, avg_prep_time_minutes, logo_url, cover_image_url')
        .eq('is_approved', true)
        .order('name');
    return rows.map(Restaurant.fromJson).toList();
  }

  /// Items with a live offer or featured flag, across all restaurants (home "Hot deals").
  static Future<List<MenuItem>> dealItems() async {
    final rows = await sb
        .from('menu_items')
        .select('id, name, price_cents, $_offerFields, image_url, restaurant_id')
        .eq('is_available', true)
        .or('offer_price_cents.not.is.null,is_featured.eq.true');
    return rows.map(MenuItem.fromJson).where((i) => i.offer != null).toList()
      ..sort((a, b) => b.offer!.percentOff - a.offer!.percentOff);
  }

  // ---------- Restaurant menu ----------
  static Future<(Restaurant, List<Category>, List<MenuItem>)> menu(String restaurantId) async {
    final results = await Future.wait([
      sb.from('restaurants').select().eq('id', restaurantId).single(),
      sb.from('menu_categories').select('id, name').eq('restaurant_id', restaurantId).order('sort_order'),
      sb
          .from('menu_items')
          .select(
              'id, name, description, price_cents, $_offerFields, category_id, image_url, restaurant_id, menu_option_groups($_groupSelect)')
          .eq('restaurant_id', restaurantId)
          .eq('is_available', true)
          .order('name'),
    ]);
    final restaurant = Restaurant.fromJson(results[0] as Map<String, dynamic>);
    final cats = (results[1] as List).map((c) => Category(c['id'], c['name'])).toList();
    final items = (results[2] as List).map((i) => MenuItem.fromJson(i)).toList();
    return (restaurant, cats, items);
  }

  // ---------- Addresses ----------
  static Future<List<Address>> addresses() async {
    final rows = await sb
        .from('client_addresses')
        .select('id, label, address_line, is_default')
        .eq('client_id', sb.auth.currentUser!.id)
        .order('is_default', ascending: false);
    return rows.map(Address.fromJson).toList();
  }

  static Future<void> addAddress({required String label, required String line, bool isDefault = false}) async {
    final uid = sb.auth.currentUser!.id;
    if (isDefault) {
      await sb.from('client_addresses').update({'is_default': false}).eq('client_id', uid);
    }
    await sb.from('client_addresses').insert({
      'client_id': uid,
      'label': label,
      'address_line': line,
      // Placeholder coordinates, same as the website (no geocoding yet).
      'latitude': 52.3759,
      'longitude': 9.732,
      'is_default': isDefault,
    });
  }

  static Future<void> setDefaultAddress(String id) async {
    final uid = sb.auth.currentUser!.id;
    await sb.from('client_addresses').update({'is_default': false}).eq('client_id', uid);
    await sb.from('client_addresses').update({'is_default': true}).eq('id', id).eq('client_id', uid);
  }

  static Future<void> deleteAddress(String id) async {
    await sb.from('client_addresses').delete().eq('id', id).eq('client_id', sb.auth.currentUser!.id);
  }

  // ---------- Orders ----------
  /// Checkout runs inside the database (migrations/2026-11-16_place_order_function.sql).
  static Future<String> placeOrder({
    required String restaurantId,
    required String addressId,
    required List<Map<String, dynamic>> items,
    String? notes,
  }) async {
    final id = await sb.rpc('place_order', params: {
      'p_restaurant_id': restaurantId,
      'p_address_id': addressId,
      'p_items': items,
      'p_notes': notes,
    });
    return id as String;
  }

  static Future<List<OrderSummary>> myOrders() async {
    final rows = await sb
        .from('orders')
        .select('id, status, total_cents, created_at, restaurants(name)')
        .eq('client_id', sb.auth.currentUser!.id)
        .order('created_at', ascending: false);
    return rows.map(OrderSummary.fromJson).toList();
  }

  static Future<Map<String, dynamic>?> orderDetail(String id) async {
    return sb
        .from('orders')
        .select(
            'id, status, driver_id, subtotal_cents, delivery_fee_cents, total_cents, created_at, restaurants(name, address), '
            'order_items(quantity, unit_price_cents, notes, menu_items(name), order_item_options(group_name, option_name, mode, price_cents))')
        .eq('id', id)
        .maybeSingle();
  }

  static Future<List<Map<String, dynamic>>> statusHistory(String orderId) async {
    final rows = await sb
        .from('order_status_history')
        .select('status, changed_at')
        .eq('order_id', orderId)
        .order('changed_at');
    return rows;
  }

  /// Driver name/phone — only returned to the order's client while delivering (get_order_driver()).
  static Future<DriverInfo?> orderDriver(String orderId) async {
    final rows = await sb.rpc('get_order_driver', params: {'p_order_id': orderId}) as List;
    return rows.isEmpty ? null : DriverInfo.fromJson(rows.first);
  }
}

/// Turns Supabase/Postgres errors into a short user-facing message.
String errorMessage(Object e) {
  if (e is PostgrestException) return e.message;
  if (e is AuthException) return e.message;
  final s = e.toString();
  if (s.contains('SocketException') || s.contains('Failed host lookup')) return 'No internet connection';
  return s.replaceFirst('Exception: ', '');
}
