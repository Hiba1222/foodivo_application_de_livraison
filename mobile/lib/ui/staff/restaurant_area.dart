import 'dart:async';

import 'package:flutter/services.dart';

import 'package:material_ui/material_ui.dart';

import '../../core/money.dart';
import '../../core/theme.dart';
import '../../data/repo.dart';
import '../../data/staff_repo.dart';
import '../auth_gate.dart';
import '../widgets.dart';
import 'restaurant_menu.dart';
import 'staff_fx.dart';
import 'staff_widgets.dart';

/// Restaurant owner app: onboarding if no restaurant yet, otherwise Overview · Orders · Menu · Settings.
class RestaurantArea extends StatefulWidget {
  const RestaurantArea({super.key});
  @override
  State<RestaurantArea> createState() => _RestaurantAreaState();
}

class _RestaurantAreaState extends State<RestaurantArea> {
  Map<String, dynamic>? _r;
  bool _loading = true;
  String? _error;
  int _pending = 0;
  StreamSubscription? _live;
  final _tab = ValueNotifier<int>(0);
  bool _firstSnapshot = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _live?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final r = await RestaurantRepo.mine();
      if (!mounted) return;
      setState(() {
        _r = r;
        _loading = false;
        _error = null;
      });
      if (r != null && _live == null) {
        // Live badge on the Orders tab with the number of new orders waiting.
        _live = sb.from('orders').stream(primaryKey: ['id']).eq('restaurant_id', r['id']).listen((rows) {
          final pending = rows.where((o) => o['status'] == 'pending').length;
          // A new order arrived: vibrate + toast (not on the first load).
          if (!_firstSnapshot && pending > _pending && mounted) {
            HapticFeedback.heavyImpact();
            showToast(context, '🔔 ${context.i18n.t('New order!')}', icon: Icons.notifications_active, iconColor: C.amber400);
          }
          _firstSnapshot = false;
          if (mounted) setState(() => _pending = pending);
        });
      }
    } catch (e) {
      if (mounted) setState(() => (_error = errorMessage(e), _loading = false));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Scaffold(body: Center(child: CircularProgressIndicator(color: C.brand600)));
    if (_error != null) {
      return Scaffold(body: EmptyState(emoji: '📡', title: context.t(_error!), action: PrimaryButton(context.t('Retry'), expand: false, onPressed: _load)));
    }
    final r = _r;
    if (r == null) return _CreateRestaurant(onDone: _load);
    return RoleShell(
      controller: _tab,
      badgeTab: 1,
      badgeCount: _pending,
      tabs: [
        (Icons.dashboard_outlined, 'Overview', _Overview(restaurant: r, onChanged: _load, pending: _pending, onOpenTab: (i) => _tab.value = i)),
        (Icons.receipt_long_outlined, 'Orders', _Orders(restaurant: r)),
        (Icons.restaurant_menu, 'Menu', RestaurantMenuScreen(restaurant: r)),
        (Icons.settings_outlined, 'Settings', _Settings(restaurant: r, onSaved: _load)),
      ],
    );
  }
}

// ---------------- Onboarding ----------------

class _CreateRestaurant extends StatefulWidget {
  final VoidCallback onDone;
  const _CreateRestaurant({required this.onDone});
  @override
  State<_CreateRestaurant> createState() => _CreateRestaurantState();
}

class _CreateRestaurantState extends State<_CreateRestaurant> {
  final _name = TextEditingController(), _cuisine = TextEditingController(), _desc = TextEditingController();
  final _address = TextEditingController(), _phone = TextEditingController();
  bool _busy = false;
  String? _error;

  Future<void> _submit() async {
    final i = context.i18n;
    if ([_name, _address, _phone].any((c) => c.text.trim().isEmpty)) return setState(() => _error = i.t('Required field'));
    setState(() => (_busy = true, _error = null));
    try {
      await RestaurantRepo.create({
        'name': _name.text.trim(),
        'cuisine_type': _cuisine.text.trim(),
        'description': _desc.text.trim(),
        'address': _address.text.trim(),
        'phone': _phone.text.trim(),
      });
      widget.onDone();
    } catch (e) {
      if (mounted) setState(() => (_error = i.t(errorMessage(e)), _busy = false));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AuthBackground(
        child: SafeArea(
          child: ListView(padding: const EdgeInsets.all(20), children: [
            Row(children: [
              const Logo(height: 44),
              const Spacer(),
              TextButton(onPressed: () => sb.auth.signOut(), child: Text(context.t('Sign out'))),
            ]),
            const SizedBox(height: 16),
            CardBox(
              padding: const EdgeInsets.all(20),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Text(context.t('Set up your restaurant'), style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
                const SizedBox(height: 4),
                Text(context.t('One more step before you can manage your menu and orders.'), style: const TextStyle(color: C.slate500)),
                const SizedBox(height: 18),
                TextField(controller: _name, decoration: InputDecoration(labelText: context.t('Restaurant name'))),
                const SizedBox(height: 12),
                TextField(controller: _cuisine, decoration: InputDecoration(labelText: context.t('Cuisine type'), hintText: context.t('Italian, Lebanese, Burgers…'))),
                const SizedBox(height: 12),
                TextField(controller: _desc, maxLines: 2, decoration: InputDecoration(labelText: context.t('Description'))),
                const SizedBox(height: 12),
                TextField(controller: _address, decoration: InputDecoration(labelText: context.t('Address'), prefixIcon: const Icon(Icons.location_on_outlined))),
                const SizedBox(height: 12),
                TextField(controller: _phone, keyboardType: TextInputType.phone, decoration: InputDecoration(labelText: context.t('Phone number'), prefixIcon: const Icon(Icons.phone_outlined))),
                if (_error != null) ...[const SizedBox(height: 10), Text(_error!, style: const TextStyle(color: C.red600, fontWeight: FontWeight.w600))],
                const SizedBox(height: 18),
                PrimaryButton(context.t('Create restaurant'), loading: _busy, onPressed: _submit),
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}

// ---------------- Overview ----------------

class _Overview extends StatefulWidget {
  final Map<String, dynamic> restaurant;
  final VoidCallback onChanged;
  final int pending;
  final ValueChanged<int> onOpenTab;
  const _Overview({required this.restaurant, required this.onChanged, required this.pending, required this.onOpenTab});
  @override
  State<_Overview> createState() => _OverviewState();
}

class _OverviewState extends State<_Overview> {
  (int, int, int)? _stats;
  bool _toggling = false;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  @override
  void didUpdateWidget(covariant _Overview old) {
    super.didUpdateWidget(old);
    if (old.pending != widget.pending) _refresh(); // an order changed → refresh numbers
  }

  Future<void> _refresh() async {
    try {
      final s = await RestaurantRepo.stats(widget.restaurant['id']);
      if (mounted) setState(() => _stats = s);
    } catch (_) {}
  }

  Future<void> _toggleOpen() async {
    setState(() => _toggling = true);
    try {
      await RestaurantRepo.setOpen(widget.restaurant['id'], !(widget.restaurant['is_open'] == true));
      widget.onChanged();
    } catch (e) {
      if (mounted) showError(context, errorMessage(e));
    } finally {
      if (mounted) setState(() => _toggling = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.restaurant;
    final s = _stats;
    return SafeArea(
      child: RefreshIndicator(
        color: C.brand600,
        onRefresh: () async {
          widget.onChanged();
          await _refresh();
        },
        child: ListView(padding: const EdgeInsets.fromLTRB(16, 12, 16, 24), children: [
          HeroHeader(
            greeting: '${context.t(greetingKey())} 👋',
            title: r['name'] ?? '',
            subtitle: r['address'],
            imageUrl: r['logo_url'],
            emoji: '🍳',
          ),
          const SizedBox(height: 16),
          if (r['is_approved'] != true) ApprovalBanner(context.t("Your restaurant is awaiting admin approval. It won't appear to clients until approved.")),
          StatusToggle(
            on: r['is_open'] == true,
            busy: _toggling,
            onText: context.t('Open — accepting orders'),
            offText: context.t('Closed — tap to open'),
            onTap: _toggleOpen,
          ),
          const SizedBox(height: 16),
          StatRow(
            StatCard(
              index: 0,
              emoji: '🔔',
              tint: C.amber500,
              highlight: (s?.$1 ?? 0) > 0,
              label: context.t('New orders waiting'),
              value: s?.$1,
              onTap: () => widget.onOpenTab(1),
            ),
            StatCard(index: 1, emoji: '🍳', tint: C.blue700, label: context.t('In progress'), value: s?.$2, onTap: () => widget.onOpenTab(1)),
          ),
          const SizedBox(height: 12),
          StatCard(index: 2, emoji: '💰', tint: C.green600, label: context.t('Revenue today'), value: s?.$3, format: formatPrice),
          const SizedBox(height: 12),
          FadeInUp(
            index: 3,
            child: Pressable(
              onTap: () => widget.onOpenTab(2),
              child: CardBox(
                child: Row(children: [
                  const Text('📋', style: TextStyle(fontSize: 26)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(context.t('Menu'), style: const TextStyle(fontWeight: FontWeight.w900)),
                      Text(context.t('Tap an item to edit its photo, price, offer and options. Use the switch to hide it instantly.'),
                          maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, color: C.slate500)),
                    ]),
                  ),
                  const Icon(Icons.chevron_right, color: C.slate300),
                ]),
              ),
            ),
          ),
        ]),
      ),
    );
  }
}

// ---------------- Orders ----------------

class _Orders extends StatefulWidget {
  final Map<String, dynamic> restaurant;
  const _Orders({required this.restaurant});
  @override
  State<_Orders> createState() => _OrdersState();
}

class _OrdersState extends State<_Orders> {
  List<Map<String, dynamic>>? _orders;
  String? _error;
  final _busy = <String>{};
  StreamSubscription? _live;

  @override
  void initState() {
    super.initState();
    _refresh();
    _live = sb.from('orders').stream(primaryKey: ['id']).eq('restaurant_id', widget.restaurant['id']).listen((_) => _refresh());
  }

  @override
  void dispose() {
    _live?.cancel();
    super.dispose();
  }

  Future<void> _refresh() async {
    try {
      final o = await RestaurantRepo.orders(widget.restaurant['id']);
      if (mounted) setState(() => (_orders = o, _error = null));
    } catch (e) {
      if (mounted) setState(() => _error = errorMessage(e));
    }
  }

  int _filter = 0; // 0 New · 1 In progress · 2 Done · 3 All

  static const _inProgress = ['accepted', 'ready_for_pickup', 'driver_assigned', 'picked_up'];
  static const _done = ['delivered', 'rejected', 'cancelled'];

  bool _match(String status, int f) => switch (f) {
        0 => status == 'pending',
        1 => _inProgress.contains(status),
        2 => _done.contains(status),
        _ => true,
      };

  Future<void> _set(String id, String status) async {
    HapticFeedback.mediumImpact();
    setState(() => _busy.add(id));
    try {
      await RestaurantRepo.setOrderStatus(id, status);
      if (mounted) {
        if (status == 'ready_for_pickup') celebrate(context, emojis: const ['📦', '✨', '🛵', '🧡']);
        showToast(context, context.i18n.status(status));
      }
      await _refresh();
    } catch (e) {
      if (mounted) showError(context, errorMessage(e));
    } finally {
      if (mounted) setState(() => _busy.remove(id));
    }
  }

  @override
  Widget build(BuildContext context) {
    final orders = _orders;
    final count = [for (var f = 0; f < 4; f++) (orders ?? []).where((o) => _match(o['status'], f)).length];
    final shown = (orders ?? []).where((o) => _match(o['status'], _filter)).toList();
    return SafeArea(
      child: RefreshIndicator(
        color: C.brand600,
        onRefresh: _refresh,
        child: ListView(padding: const EdgeInsets.fromLTRB(16, 12, 16, 24), children: [
          PageHeader(context.t('Orders'), subtitle: context.t('New orders need a response. Accepted orders should be marked ready when the food is packed.')),
          FilterTabs(
            tabs: [
              ('🔔 ${context.t('New')}', count[0]),
              ('🍳 ${context.t('In progress')}', count[1]),
              ('✅ ${context.t('Completed')}', count[2]),
              (context.t('All'), count[3]),
            ],
            selected: _filter,
            onSelect: (i) => setState(() => _filter = i),
          ),
          const SizedBox(height: 14),
          if (orders == null && _error == null)
            const Padding(padding: EdgeInsets.all(40), child: Center(child: CircularProgressIndicator(color: C.brand600)))
          else if (orders == null)
            EmptyState(emoji: '📡', title: context.t(_error!), action: PrimaryButton(context.t('Retry'), expand: false, onPressed: _refresh))
          else if (shown.isEmpty)
            EmptyState(emoji: _filter == 0 ? '😌' : '🧾', title: context.t(_filter == 0 ? 'No new orders right now.' : 'No orders yet.'))
          else
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: Column(
                key: ValueKey(_filter),
                children: [
                  for (var i = 0; i < shown.length; i++)
                    Padding(
                      key: ValueKey(shown[i]['id']),
                      padding: const EdgeInsets.only(bottom: 12),
                      child: FadeInUp(index: i, child: _orderCard(shown[i])),
                    ),
                ],
              ),
            ),
        ]),
      ),
    );
  }

  static int _step(String status) => switch (status) {
        'pending' => 0,
        'accepted' => 1,
        'ready_for_pickup' => 2,
        'driver_assigned' || 'picked_up' => 3,
        'delivered' => 4,
        _ => -1,
      };

  Widget _orderCard(Map<String, dynamic> o) {
    final status = o['status'] as String;
    final (bg, fg) = statusColors(status);
    final busy = _busy.contains(o['id']);
    final isNew = status == 'pending';
    final step = _step(status);
    final items = (o['order_items'] as List?) ?? const [];
    final itemCount = items.fold<int>(0, (s, oi) => s + ((oi['quantity'] as num?)?.toInt() ?? 0));
    return PulseBorder(
      active: isNew,
      child: CardBox(
        borderColor: isNew ? C.amber400 : null,
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              width: 42,
              height: 42,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(14)),
              child: Text('$itemCount', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 17, color: fg)),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(o['profiles']?['full_name'] ?? context.t('Client'), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: C.slate900)),
                Text('#${(o['id'] as String).substring(0, 6)} · ${context.i18n.time(o['created_at'])}', style: const TextStyle(fontSize: 12, color: C.slate500)),
              ]),
            ),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              transitionBuilder: (c, a) => ScaleTransition(scale: a, child: c),
              child: Pill(context.i18n.status(status), key: ValueKey(status), bg: bg, fg: fg, leading: isNew ? LiveDot(color: fg, size: 6) : null),
            ),
          ]),
          if (step >= 0) ...[
            const SizedBox(height: 14),
            StepTracker(
              current: step,
              steps: [
                ('🔔', context.t('New')),
                ('🍳', context.t('Accepted')),
                ('📦', context.t('Ready')),
                ('🛵', context.t('On the way')),
                ('✅', context.t('Delivered')),
              ],
            ),
          ],
          const SizedBox(height: 12),
          OrderLines(items),
          if ((o['notes'] as String?)?.isNotEmpty == true)
            Container(
              margin: const EdgeInsets.only(top: 4),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: C.slate50, borderRadius: BorderRadius.circular(10)),
              child: Text('💬 ${o['notes']}', style: const TextStyle(fontSize: 13, color: C.slate700)),
            ),
          const Divider(height: 24),
          Row(children: [
            Expanded(child: Text('${context.t('Total')}: ${formatPrice((o['total_cents'] as num).toInt())}', style: const TextStyle(fontWeight: FontWeight.w900, color: C.slate900))),
            if (status == 'pending') ...[
              ActionChipButton(context.t('Reject'), bg: const Color(0xFFFEF2F2), fg: const Color(0xFFB91C1C), onTap: busy
                  ? null
                  : () async {
                      if (await confirm(context, context.i18n.t('Reject this order?'), confirmLabel: 'Reject')) _set(o['id'], 'rejected');
                    }),
              const SizedBox(width: 8),
              ActionChipButton(context.t('Accept'), bg: C.brand600, busy: busy, icon: Icons.check, onTap: () => _set(o['id'], 'accepted')),
            ],
          ]),
          if (status == 'accepted') ...[
            const SizedBox(height: 12),
            SlideToConfirm(
              label: context.t('Slide when ready for pickup'),
              color: const Color(0xFF4F46E5),
              icon: Icons.inventory_2_outlined,
              onConfirm: () => _set(o['id'], 'ready_for_pickup'),
            ),
          ],
        ]),
      ),
    );
  }
}

// ---------------- Settings ----------------

class _Settings extends StatefulWidget {
  final Map<String, dynamic> restaurant;
  final VoidCallback onSaved;
  const _Settings({required this.restaurant, required this.onSaved});
  @override
  State<_Settings> createState() => _SettingsState();
}

class _SettingsState extends State<_Settings> {
  late final _r = widget.restaurant;
  late final _name = TextEditingController(text: _r['name'] ?? '');
  late final _cuisine = TextEditingController(text: _r['cuisine_type'] ?? '');
  late final _desc = TextEditingController(text: _r['description'] ?? '');
  late final _address = TextEditingController(text: _r['address'] ?? '');
  late final _phone = TextEditingController(text: _r['phone'] ?? '');
  bool _saving = false;

  Future<void> _save() async {
    final i = context.i18n;
    if ([_name, _address, _phone].any((c) => c.text.trim().isEmpty)) return showError(context, i.t('Required field'));
    setState(() => _saving = true);
    try {
      await RestaurantRepo.update(_r['id'], {
        'name': _name.text.trim(),
        'cuisine_type': _cuisine.text.trim(),
        'description': _desc.text.trim(),
        'address': _address.text.trim(),
        'phone': _phone.text.trim(),
      });
      if (mounted) showToast(context, i.t('Saved'));
      widget.onSaved();
    } catch (e) {
      if (mounted) showError(context, errorMessage(e));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final id = _r['id'];
    return SafeArea(
      child: ListView(padding: const EdgeInsets.fromLTRB(16, 12, 16, 24), children: [
        PageHeader(context.t('Settings'), subtitle: context.t("Update your restaurant's public profile.")),
        CardBox(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(context.t('Logo'), style: const TextStyle(fontWeight: FontWeight.w800)),
            const SizedBox(height: 10),
            PhotoPicker(
              currentUrl: _r['logo_url'],
              circle: true,
              storagePath: 'restaurants/$id/logo.jpg',
              table: 'restaurants',
              column: 'logo_url',
              rowId: id,
              addLabel: 'Add logo',
              changeLabel: 'Change logo',
            ),
            const SizedBox(height: 18),
            Text(context.t('Cover photo — shown to clients browsing restaurants'), style: const TextStyle(fontWeight: FontWeight.w800)),
            const SizedBox(height: 10),
            PhotoPicker(
              currentUrl: _r['cover_image_url'],
              wide: true,
              storagePath: 'restaurants/$id/cover.jpg',
              table: 'restaurants',
              column: 'cover_image_url',
              rowId: id,
              addLabel: 'Add cover photo',
              changeLabel: 'Change cover photo',
            ),
          ]),
        ),
        const SizedBox(height: 12),
        CardBox(
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            TextField(controller: _name, decoration: InputDecoration(labelText: context.t('Name'))),
            const SizedBox(height: 12),
            TextField(controller: _cuisine, decoration: InputDecoration(labelText: context.t('Cuisine type'))),
            const SizedBox(height: 12),
            TextField(controller: _desc, maxLines: 3, decoration: InputDecoration(labelText: context.t('Description'))),
            const SizedBox(height: 12),
            TextField(controller: _address, decoration: InputDecoration(labelText: context.t('Address'))),
            const SizedBox(height: 12),
            TextField(controller: _phone, keyboardType: TextInputType.phone, decoration: InputDecoration(labelText: context.t('Phone number'))),
            const SizedBox(height: 16),
            PrimaryButton(context.t('Save changes'), loading: _saving, onPressed: _save),
          ]),
        ),
        const SizedBox(height: 12),
        const AccountCard(),
      ]),
    );
  }
}
