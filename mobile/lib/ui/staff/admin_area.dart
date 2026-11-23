import 'dart:async';

import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/money.dart';
import '../../core/theme.dart';
import '../../data/repo.dart';
import '../widgets.dart';
import 'staff_fx.dart';
import 'staff_widgets.dart';

// ---------------- Data (same queries as web/app/admin) ----------------

class AdminRepo {
  static const _active = ['pending', 'accepted', 'ready_for_pickup', 'driver_assigned', 'picked_up'];

  static Future<Map<String, int>> stats() async {
    final r = await Future.wait([
      sb.from('orders').select('id'),
      sb.from('orders').select('id').inFilter('status', _active),
      sb.from('restaurants').select('id').eq('is_approved', false),
      sb.from('driver_profiles').select('id').eq('is_approved', false),
      sb.from('orders').select('subtotal_cents, delivery_fee_cents').eq('status', 'delivered'),
      sb.from('profiles').select('id'),
    ]);
    final delivered = r[4] as List;
    final restaurantFee = delivered.fold<int>(0, (s, o) => s + (((o['subtotal_cents'] as num?)?.toInt() ?? 0) ~/ 10));
    final driverFee = delivered.fold<int>(0, (s, o) => s + (((o['delivery_fee_cents'] as num?)?.toInt() ?? 0) ~/ 10));
    return {
      'orders': (r[0] as List).length,
      'active': (r[1] as List).length,
      'pendingRestaurants': (r[2] as List).length,
      'pendingDrivers': (r[3] as List).length,
      'platformFee': restaurantFee + driverFee,
      'restaurantFee': restaurantFee,
      'driverFee': driverFee,
      'users': (r[5] as List).length,
    };
  }

  static Future<void> disapproveRestaurant(String id) => sb.from('restaurants').delete().eq('id', id);
  static Future<void> disapproveDriver(String id) => sb.from('driver_profiles').delete().eq('id', id);

  static Future<List<Map<String, dynamic>>> restaurants() => sb.from('restaurants').select().order('created_at', ascending: false);

  static Future<List<Map<String, dynamic>>> drivers() =>
      sb.from('driver_profiles').select('*, profiles(full_name, phone, avatar_url)').order('id', ascending: false);

  static Future<List<Map<String, dynamic>>> orders({String? restaurantId, DateTime? day}) {
    var q = sb
        .from('orders')
        .select('id, status, total_cents, created_at, restaurant_id, restaurants(name), profiles!orders_client_id_fkey(full_name)');
    if (restaurantId != null) q = q.eq('restaurant_id', restaurantId);
    if (day != null) {
      final from = DateTime(day.year, day.month, day.day);
      final to = DateTime(day.year, day.month, day.day, 23, 59, 59);
      q = q.gte('created_at', from.toUtc().toIso8601String()).lte('created_at', to.toUtc().toIso8601String());
    }
    return q.order('created_at', ascending: false).limit(200);
  }

  static Future<List<Map<String, dynamic>>> restaurantList() =>
      sb.from('restaurants').select('id, name').order('name');

  static Future<List<Map<String, dynamic>>> users() => sb.from('profiles').select().order('created_at', ascending: false);

  static Future<void> setRestaurantApproval(String id, bool approved) => sb.from('restaurants').update({'is_approved': approved}).eq('id', id);
  static Future<void> setDriverApproval(String id, bool approved) => sb.from('driver_profiles').update({'is_approved': approved}).eq('id', id);
}

void _call(String? phone) {
  if (phone == null || phone.isEmpty) return;
  launchUrl(Uri(scheme: 'tel', path: phone.replaceAll(RegExp(r'[^+\d]'), '')));
}

const _vehicleEmoji = {'bike': '🚲', 'scooter': '🛵', 'car': '🚗'};
const _vehicleText = {'bike': 'Bike', 'scooter': 'Scooter', 'car': 'Car'};
const _roleText = {'admin': 'Admin', 'restaurant_owner': 'Restaurant owner', 'client': 'Client', 'driver': 'Driver'};
const _roleEmoji = {'admin': '🛡️', 'restaurant_owner': '🧑‍🍳', 'client': '🙂', 'driver': '🛵'};

// ---------------- Shell ----------------

/// Admin app: Overview · Restaurants · Drivers · Orders · Users (+ settings in the header).
class AdminArea extends StatefulWidget {
  const AdminArea({super.key});
  @override
  State<AdminArea> createState() => _AdminAreaState();
}

class _AdminAreaState extends State<AdminArea> {
  final _tab = ValueNotifier<int>(0);
  int _pending = 0;
  StreamSubscription? _r, _d;
  int _pr = 0, _pd = 0;

  @override
  void initState() {
    super.initState();
    // Live count of approvals waiting (badge on Restaurants/Drivers).
    _r = sb.from('restaurants').stream(primaryKey: ['id']).listen((rows) => _setCounts(pr: rows.where((x) => x['is_approved'] != true).length));
    _d = sb.from('driver_profiles').stream(primaryKey: ['id']).listen((rows) => _setCounts(pd: rows.where((x) => x['is_approved'] != true).length));
  }

  void _setCounts({int? pr, int? pd}) {
    if (!mounted) return;
    setState(() {
      _pr = pr ?? _pr;
      _pd = pd ?? _pd;
      _pending = _pr + _pd;
    });
  }

  @override
  void dispose() {
    _r?.cancel();
    _d?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RoleShell(
      controller: _tab,
      badgeTab: _pr > 0 ? 1 : (_pd > 0 ? 2 : null),
      badgeCount: _pr > 0 ? _pr : _pd,
      tabs: [
        (Icons.dashboard_outlined, 'Overview', _Overview(onOpenTab: (i) => _tab.value = i, pendingApprovals: _pending)),
        (Icons.storefront_outlined, 'Restaurants', const _Restaurants()),
        (Icons.delivery_dining_outlined, 'Drivers', const _Drivers()),
        (Icons.receipt_long_outlined, 'Orders', const _Orders()),
        (Icons.people_outline, 'Users', const _Users()),
      ],
    );
  }
}

// ---------------- Overview ----------------

class _Overview extends StatefulWidget {
  final ValueChanged<int> onOpenTab;
  final int pendingApprovals;
  const _Overview({required this.onOpenTab, required this.pendingApprovals});
  @override
  State<_Overview> createState() => _OverviewState();
}

class _OverviewState extends State<_Overview> {
  Map<String, int>? _s;
  String? _name;
  StreamSubscription? _live;

  @override
  void initState() {
    super.initState();
    Repo.myProfile().then((p) {
      if (mounted) setState(() => _name = p?['full_name']);
    });
    _refresh();
    _live = sb.from('orders').stream(primaryKey: ['id']).listen((_) => _refresh());
  }

  @override
  void didUpdateWidget(covariant _Overview old) {
    super.didUpdateWidget(old);
    if (old.pendingApprovals != widget.pendingApprovals) _refresh();
  }

  @override
  void dispose() {
    _live?.cancel();
    super.dispose();
  }

  Future<void> _refresh() async {
    try {
      final s = await AdminRepo.stats();
      if (mounted) setState(() => _s = s);
    } catch (_) {}
  }

  void _settings() => showModalBottomSheet(
        context: context,
        backgroundColor: C.slate50,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
        builder: (_) => const SafeArea(child: Padding(padding: EdgeInsets.all(16), child: AccountCard())),
      );

  @override
  Widget build(BuildContext context) {
    final s = _s;
    final pr = s?['pendingRestaurants'] ?? 0, pd = s?['pendingDrivers'] ?? 0;
    return SafeArea(
      child: RefreshIndicator(
        color: C.brand600,
        onRefresh: _refresh,
        child: ListView(padding: const EdgeInsets.fromLTRB(16, 12, 16, 24), children: [
          HeroHeader(
            greeting: '${context.t(greetingKey())} 👋',
            title: context.t('Platform overview'),
            subtitle: _name,
            emoji: '🛡️',
            colors: const [C.slate800, Color(0xFF334155), C.brand600],
            trailing: Pressable(
              onTap: _settings,
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), shape: BoxShape.circle),
                child: const Icon(Icons.settings_outlined, color: Colors.white),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
            child: Row(children: [
              const LiveDot(size: 7),
              const SizedBox(width: 8),
              Expanded(child: Text(context.t('Live snapshot across all restaurants, drivers, and orders.'), style: const TextStyle(color: C.slate500, fontSize: 13))),
            ]),
          ),
          if (pr + pd > 0) ...[
            PulseBorder(
              child: Pressable(
                onTap: () => widget.onOpenTab(pr > 0 ? 1 : 2),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [Color(0xFFFFFBEB), Color(0xFFFEF3C7)]),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: C.amber400),
                  ),
                  child: Row(children: [
                    const Text('⏳', style: TextStyle(fontSize: 26)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(context.t('Waiting for your approval'), style: const TextStyle(fontWeight: FontWeight.w900, color: C.amber950)),
                        Text(
                          [
                            if (pr > 0) '$pr ${context.t('Restaurants').toLowerCase()}',
                            if (pd > 0) '$pd ${context.t('Drivers').toLowerCase()}',
                          ].join(' · '),
                          style: const TextStyle(color: C.amber800),
                        ),
                      ]),
                    ),
                    const Icon(Icons.arrow_forward_rounded, color: C.amber800),
                  ]),
                ),
              ),
            ),
            const SizedBox(height: 14),
          ],
          StatRow(
            StatCard(index: 0, emoji: '🧾', tint: C.blue700, label: context.t('Total orders'), value: s?['orders'], onTap: () => widget.onOpenTab(3)),
            StatCard(
              index: 1,
              emoji: '🔥',
              tint: C.rose600,
              highlight: (s?['active'] ?? 0) > 0,
              label: context.t('Active orders'),
              value: s?['active'],
              onTap: () => widget.onOpenTab(3),
            ),
          ),
          const SizedBox(height: 12),
          StatRow(
            StatCard(index: 2, emoji: '🏪', tint: C.amber500, highlight: pr > 0, label: context.t('Restaurants pending approval'), value: s?['pendingRestaurants'], onTap: () => widget.onOpenTab(1)),
            StatCard(index: 3, emoji: '🛵', tint: const Color(0xFF8B5CF6), highlight: pd > 0, label: context.t('Drivers pending approval'), value: s?['pendingDrivers'], onTap: () => widget.onOpenTab(2)),
          ),
          const SizedBox(height: 12),
          StatCard(index: 4, emoji: '💹', tint: C.green600, label: context.t('Platform fees (10%)'), value: s?['platformFee'], format: formatPrice),
          const SizedBox(height: 12),
          StatRow(
            StatCard(index: 5, emoji: '🏪', tint: C.brand600, label: context.t('From restaurants'), value: s?['restaurantFee'], format: formatPrice),
            StatCard(index: 6, emoji: '🛵', tint: const Color(0xFF8B5CF6), label: context.t('From drivers'), value: s?['driverFee'], format: formatPrice),
          ),
          const SizedBox(height: 12),
          StatCard(index: 7, emoji: '👥', tint: C.slate600, label: context.t('Users'), value: s?['users'], onTap: () => widget.onOpenTab(4)),
        ]),
      ),
    );
  }
}

// ---------------- Shared list scaffolding ----------------

/// Search box with clear button.
class _SearchBox extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final VoidCallback onChanged;
  const _SearchBox({required this.controller, required this.hint, required this.onChanged});
  @override
  Widget build(BuildContext context) => TextField(
        controller: controller,
        onChanged: (_) => onChanged(),
        decoration: InputDecoration(
          hintText: hint,
          prefixIcon: const Icon(Icons.search),
          isDense: true,
          suffixIcon: controller.text.isEmpty
              ? null
              : IconButton(
                  icon: const Icon(Icons.close, size: 18),
                  onPressed: () {
                    controller.clear();
                    onChanged();
                  },
                ),
        ),
      );
}

/// Approval actions: pending → Approve + Disapprove; approved → Suspend; disapproved → Approve.
class _ApprovalButton extends StatelessWidget {
  final bool? approved; // null=pending, true=approved, false=disapproved/suspended
  final bool busy;
  final VoidCallback? onApprove;
  final VoidCallback? onDisapprove;
  const _ApprovalButton({required this.approved, required this.busy, this.onApprove, this.onDisapprove});
  @override
  Widget build(BuildContext context) {
    if (approved == true) {
      return ActionChipButton(
        context.t('Suspend'),
        bg: const Color(0xFFFEF2F2),
        fg: const Color(0xFFB91C1C),
        icon: Icons.pause_circle_outline,
        busy: busy,
        onTap: onDisapprove,
      );
    } else if (approved == null) {
      return Row(mainAxisSize: MainAxisSize.min, children: [
        ActionChipButton(context.t('Approve'), bg: C.green600, icon: Icons.check_circle_outline, busy: busy, onTap: onApprove),
        const SizedBox(width: 8),
        ActionChipButton(context.t('Disapprove'), bg: const Color(0xFFFEF2F2), fg: const Color(0xFFB91C1C), icon: Icons.cancel_outlined, busy: busy, onTap: onDisapprove),
      ]);
    } else {
      // Explicitly disapproved/suspended — show Approve to re-enable
      return ActionChipButton(context.t('Approve'), bg: C.green600, icon: Icons.check_circle_outline, busy: busy, onTap: onApprove);
    }
  }
}

Widget _approvedPill(BuildContext context, bool? approved) => AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      transitionBuilder: (c, a) => ScaleTransition(scale: a, child: c),
      child: approved == true
          ? Pill(context.t('Approved'), key: const ValueKey('approved'), bg: C.green100, fg: C.green700)
          : approved == false
              ? Pill(context.t('Suspended'), key: const ValueKey('suspended'), bg: const Color(0xFFFEF2F2), fg: const Color(0xFFB91C1C))
              : Pill(context.t('Pending'), key: const ValueKey('pending'), bg: C.amber100, fg: const Color(0xFFB45309), leading: const LiveDot(color: C.amber500, size: 6)),
    );

// ---------------- Restaurants ----------------

class _Restaurants extends StatefulWidget {
  const _Restaurants();
  @override
  State<_Restaurants> createState() => _RestaurantsState();
}

class _RestaurantsState extends State<_Restaurants> {
  List<Map<String, dynamic>>? _rows;
  int _filter = 0; // Pending · Approved · All
  final _q = TextEditingController();
  final _busy = <String>{};
  StreamSubscription? _live;

  @override
  void initState() {
    super.initState();
    _refresh();
    _live = sb.from('restaurants').stream(primaryKey: ['id']).listen((_) => _refresh());
  }

  @override
  void dispose() {
    _live?.cancel();
    super.dispose();
  }

  Future<void> _refresh() async {
    try {
      final r = await AdminRepo.restaurants();
      if (mounted) setState(() => _rows = r);
    } catch (e) {
      if (mounted) showError(context, errorMessage(e));
    }
  }

  Future<void> _approve(Map<String, dynamic> r) async {
    HapticFeedback.mediumImpact();
    setState(() => _busy.add(r['id']));
    try {
      await AdminRepo.setRestaurantApproval(r['id'], true);
      if (mounted) {
        celebrate(context, emojis: const ['🏪', '🎉', '✨', '🧡']);
        showToast(context, context.i18n.t('Approved'));
      }
      await _refresh();
    } catch (e) {
      if (mounted) showError(context, errorMessage(e));
    } finally {
      if (mounted) setState(() => _busy.remove(r['id']));
    }
  }

  Future<void> _disapprove(Map<String, dynamic> r) async {
    final isSuspend = r['is_approved'] == true;
    final label = isSuspend ? 'Suspend' : 'Disapprove';
    if (!await confirm(context, context.i18n.t('$label this restaurant?'), confirmLabel: label)) return;
    HapticFeedback.mediumImpact();
    setState(() => _busy.add(r['id']));
    try {
      if (isSuspend) {
        await AdminRepo.setRestaurantApproval(r['id'], false);
        if (mounted) showToast(context, context.i18n.t('Suspended'));
      } else {
        await AdminRepo.disapproveRestaurant(r['id']);
        if (mounted) showToast(context, context.i18n.t('Removed'));
      }
      await _refresh();
    } catch (e) {
      if (mounted) showError(context, errorMessage(e));
    } finally {
      if (mounted) setState(() => _busy.remove(r['id']));
    }
  }

  @override
  Widget build(BuildContext context) {
    final all = _rows ?? [];
    final q = _q.text.trim().toLowerCase();
    bool match(Map r, int f) => f == 0 ? r['is_approved'] != true : f == 1 ? r['is_approved'] == true : true;
    final shown = all
        .where((r) => match(r, _filter))
        .where((r) => q.isEmpty || '${r['name']} ${r['address']} ${r['cuisine_type']}'.toLowerCase().contains(q))
        .toList();
    return SafeArea(
      child: RefreshIndicator(
        color: C.brand600,
        onRefresh: _refresh,
        child: ListView(padding: const EdgeInsets.fromLTRB(16, 12, 16, 24), children: [
          PageHeader(context.t('Restaurants'), subtitle: context.t('Approve new restaurant signups, or suspend existing ones.')),
          _SearchBox(controller: _q, hint: context.t('Search'), onChanged: () => setState(() {})),
          const SizedBox(height: 12),
          FilterTabs(
            tabs: [
              ('⏳ ${context.t('Pending')}', all.where((r) => match(r, 0)).length),
              ('✅ ${context.t('Approved')}', all.where((r) => match(r, 1)).length),
              (context.t('All'), all.length),
            ],
            selected: _filter,
            onSelect: (i) => setState(() => _filter = i),
          ),
          const SizedBox(height: 14),
          if (_rows == null)
            const Padding(padding: EdgeInsets.all(40), child: Center(child: CircularProgressIndicator(color: C.brand600)))
          else if (shown.isEmpty)
            EmptyState(emoji: _filter == 0 ? '🎉' : '🏪', title: context.t(_filter == 0 ? 'Nothing waiting for approval.' : 'No restaurants yet.'))
          else
            for (var i = 0; i < shown.length; i++)
              Padding(key: ValueKey(shown[i]['id']), padding: const EdgeInsets.only(bottom: 12), child: FadeInUp(index: i, child: _card(shown[i]))),
        ]),
      ),
    );
  }

  Widget _card(Map<String, dynamic> r) {
    final approvedVal = r['is_approved'] as bool?;
    final approved = approvedVal == true;
    return PulseBorder(
      active: !approved,
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: approved ? C.slate200 : C.amber400), boxShadow: Shadows.soft),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          SizedBox(
            height: 92,
            child: Stack(fit: StackFit.expand, children: [
              NetImage(r['cover_image_url'], fallback: '🏪'),
              const DecoratedBox(decoration: BoxDecoration(gradient: LinearGradient(colors: [Colors.transparent, Color(0x99000000)], begin: Alignment.topCenter, end: Alignment.bottomCenter))),
              Positioned(left: 12, top: 10, child: _approvedPill(context, approvedVal)),
              Positioned(
                right: 12,
                top: 10,
                child: Pill(r['is_open'] == true ? context.t('Open') : context.t('Closed'), bg: Colors.white.withValues(alpha: 0.9), fg: r['is_open'] == true ? C.green700 : C.slate600),
              ),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Row(children: [
                ClipOval(child: SizedBox(width: 40, height: 40, child: NetImage(r['logo_url'], fallback: '🍽️'))),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(r['name'] ?? '', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
                    if ((r['cuisine_type'] as String?)?.isNotEmpty == true) Text(r['cuisine_type'], style: const TextStyle(fontSize: 12, color: C.slate500)),
                  ]),
                ),
              ]),
              const SizedBox(height: 10),
              Row(children: [
                const Icon(Icons.location_on_outlined, size: 16, color: C.slate400),
                const SizedBox(width: 4),
                Expanded(child: Text(r['address'] ?? '—', style: const TextStyle(fontSize: 13, color: C.slate600))),
              ]),
              const SizedBox(height: 12),
              Row(children: [
                if ((r['phone'] as String?)?.isNotEmpty == true)
                  ActionChipButton(context.t('Call'), bg: C.slate100, fg: C.slate800, icon: Icons.call_outlined, onTap: () => _call(r['phone'])),
                const Spacer(),
                _ApprovalButton(approved: r['is_approved'] as bool?, busy: _busy.contains(r['id']), onApprove: () => _approve(r), onDisapprove: () => _disapprove(r)),
              ]),
            ]),
          ),
        ]),
      ),
    );
  }
}

// ---------------- Drivers ----------------

class _Drivers extends StatefulWidget {
  const _Drivers();
  @override
  State<_Drivers> createState() => _DriversState();
}

class _DriversState extends State<_Drivers> {
  List<Map<String, dynamic>>? _rows;
  int _filter = 0;
  final _q = TextEditingController();
  final _busy = <String>{};
  StreamSubscription? _live;

  @override
  void initState() {
    super.initState();
    _refresh();
    _live = sb.from('driver_profiles').stream(primaryKey: ['id']).listen((_) => _refresh());
  }

  @override
  void dispose() {
    _live?.cancel();
    super.dispose();
  }

  Future<void> _refresh() async {
    try {
      final r = await AdminRepo.drivers();
      if (mounted) setState(() => _rows = r);
    } catch (e) {
      if (mounted) showError(context, errorMessage(e));
    }
  }

  Future<void> _approve(Map<String, dynamic> d) async {
    HapticFeedback.mediumImpact();
    setState(() => _busy.add(d['id']));
    try {
      await AdminRepo.setDriverApproval(d['id'], true);
      if (mounted) {
        celebrate(context, emojis: const ['🛵', '🎉', '✨', '🧡']);
        showToast(context, context.i18n.t('Approved'));
      }
      await _refresh();
    } catch (e) {
      if (mounted) showError(context, errorMessage(e));
    } finally {
      if (mounted) setState(() => _busy.remove(d['id']));
    }
  }

  Future<void> _disapprove(Map<String, dynamic> d) async {
    final isSuspend = d['is_approved'] == true;
    final label = isSuspend ? 'Suspend' : 'Disapprove';
    if (!await confirm(context, context.i18n.t('$label this driver?'), confirmLabel: label)) return;
    HapticFeedback.mediumImpact();
    setState(() => _busy.add(d['id']));
    try {
      if (isSuspend) {
        await AdminRepo.setDriverApproval(d['id'], false);
        if (mounted) showToast(context, context.i18n.t('Suspended'));
      } else {
        await AdminRepo.disapproveDriver(d['id']);
        if (mounted) showToast(context, context.i18n.t('Removed'));
      }
      await _refresh();
    } catch (e) {
      if (mounted) showError(context, errorMessage(e));
    } finally {
      if (mounted) setState(() => _busy.remove(d['id']));
    }
  }

  @override
  Widget build(BuildContext context) {
    final all = _rows ?? [];
    final q = _q.text.trim().toLowerCase();
    bool match(Map d, int f) => f == 0 ? d['is_approved'] != true : f == 1 ? d['is_online'] == true : f == 2 ? d['is_approved'] == true : true;
    final shown = all
        .where((d) => match(d, _filter))
        .where((d) => q.isEmpty || '${d['profiles']?['full_name']} ${d['profiles']?['phone']} ${d['license_plate']}'.toLowerCase().contains(q))
        .toList();
    return SafeArea(
      child: RefreshIndicator(
        color: C.brand600,
        onRefresh: _refresh,
        child: ListView(padding: const EdgeInsets.fromLTRB(16, 12, 16, 24), children: [
          PageHeader(context.t('Drivers'), subtitle: context.t('Approve new driver signups before they can go online.')),
          _SearchBox(controller: _q, hint: context.t('Search'), onChanged: () => setState(() {})),
          const SizedBox(height: 12),
          FilterTabs(
            tabs: [
              ('⏳ ${context.t('Pending')}', all.where((d) => match(d, 0)).length),
              ('🟢 ${context.t('Online')}', all.where((d) => match(d, 1)).length),
              ('✅ ${context.t('Approved')}', all.where((d) => match(d, 2)).length),
              (context.t('All'), all.length),
            ],
            selected: _filter,
            onSelect: (i) => setState(() => _filter = i),
          ),
          const SizedBox(height: 14),
          if (_rows == null)
            const Padding(padding: EdgeInsets.all(40), child: Center(child: CircularProgressIndicator(color: C.brand600)))
          else if (shown.isEmpty)
            EmptyState(emoji: _filter == 0 ? '🎉' : '🛵', title: context.t(_filter == 0 ? 'Nothing waiting for approval.' : 'No drivers yet.'))
          else
            for (var i = 0; i < shown.length; i++)
              Padding(key: ValueKey(shown[i]['id']), padding: const EdgeInsets.only(bottom: 12), child: FadeInUp(index: i, child: _card(shown[i]))),
        ]),
      ),
    );
  }

  Widget _card(Map<String, dynamic> d) {
    final approvedVal = d['is_approved'] as bool?;
    final approved = approvedVal == true, online = d['is_online'] == true;
    final p = d['profiles'] as Map<String, dynamic>?;
    final vehicle = d['vehicle_type'] as String? ?? 'bike';
    return PulseBorder(
      active: !approved,
      child: CardBox(
        borderColor: approved ? null : C.amber400,
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            Stack(clipBehavior: Clip.none, children: [
              ClipOval(child: SizedBox(width: 50, height: 50, child: NetImage(p?['avatar_url'], fallback: _vehicleEmoji[vehicle] ?? '🛵'))),
              if (online) const Positioned(right: 0, bottom: 2, child: LiveDot(size: 11)),
            ]),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(p?['full_name'] ?? '—', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
                Text(
                  '${_vehicleEmoji[vehicle] ?? ''} ${context.t(_vehicleText[vehicle] ?? vehicle)}${(d['license_plate'] as String?)?.isNotEmpty == true ? ' · ${d['license_plate']}' : ''}',
                  style: const TextStyle(fontSize: 13, color: C.slate500),
                ),
              ]),
            ),
            _approvedPill(context, approvedVal),
          ]),
          const SizedBox(height: 12),
          Row(children: [
            if ((p?['phone'] as String?)?.isNotEmpty == true)
              ActionChipButton(p!['phone'], bg: C.slate100, fg: C.slate800, icon: Icons.call_outlined, onTap: () => _call(p['phone'])),
            const Spacer(),
            _ApprovalButton(approved: d['is_approved'] as bool?, busy: _busy.contains(d['id']), onApprove: () => _approve(d), onDisapprove: () => _disapprove(d)),
          ]),
        ]),
      ),
    );
  }
}

// ---------------- Orders ----------------

class _Orders extends StatefulWidget {
  const _Orders();
  @override
  State<_Orders> createState() => _OrdersState();
}

class _OrdersState extends State<_Orders> {
  List<Map<String, dynamic>>? _rows;
  List<Map<String, dynamic>> _restaurants = [];
  int _filter = 0; // 0 Active · 1 Delivered · 2 Rejected · 3 All
  String? _restaurantId; // null = all
  DateTime? _day; // null = all days
  StreamSubscription? _live;

  @override
  void initState() {
    super.initState();
    _refresh();
    AdminRepo.restaurantList().then((r) { if (mounted) setState(() => _restaurants = r); });
    _live = sb.from('orders').stream(primaryKey: ['id']).listen((_) => _refresh());
  }

  @override
  void dispose() {
    _live?.cancel();
    super.dispose();
  }

  Future<void> _refresh() async {
    try {
      final r = await AdminRepo.orders(restaurantId: _restaurantId, day: _day);
      if (mounted) setState(() => _rows = r);
    } catch (e) {
      if (mounted) showError(context, errorMessage(e));
    }
  }

  bool _match(String s, int f) => switch (f) {
        0 => AdminRepo._active.contains(s),
        1 => s == 'delivered',
        2 => s == 'rejected' || s == 'cancelled',
        _ => true,
      };

  String _dayLabel(BuildContext context) {
    if (_day == null) return context.t('All time');
    final now = DateTime.now();
    if (_day!.year == now.year && _day!.month == now.month && _day!.day == now.day) return context.t('Today');
    return '${_day!.day}/${_day!.month}/${_day!.year}';
  }

  Future<void> _pickDate(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _day ?? DateTime.now(),
      firstDate: DateTime(2024),
      lastDate: DateTime.now(),
    );
    if (picked != null && mounted) {
      setState(() => _day = picked);
      await _refresh();
    }
  }

  @override
  Widget build(BuildContext context) {
    final all = _rows ?? [];
    final shown = all.where((o) => _match(o['status'], _filter)).toList();
    final total = shown.fold<int>(0, (s, o) => s + ((o['total_cents'] as num?)?.toInt() ?? 0));
    final restaurantName = _restaurantId == null
        ? context.t('All restaurants')
        : (_restaurants.firstWhere((r) => r['id'] == _restaurantId, orElse: () => {'name': '—'})['name'] as String);
    return SafeArea(
      child: RefreshIndicator(
        color: C.brand600,
        onRefresh: _refresh,
        child: ListView(padding: const EdgeInsets.fromLTRB(16, 12, 16, 24), children: [
          PageHeader(
            context.t('All orders'),
            subtitle: context.t('Every order placed on the platform, most recent first.'),
            trailing: shown.isEmpty ? null : Pill(formatPrice(total), bg: C.green100, fg: C.green700, fontSize: 12),
          ),
          FilterTabs(
            tabs: [
              ('🔥 ${context.t('Active')}', all.where((o) => _match(o['status'], 0)).length),
              ('✅ ${context.t('Delivered')}', all.where((o) => _match(o['status'], 1)).length),
              ('✕ ${context.t('Rejected')}', all.where((o) => _match(o['status'], 2)).length),
              (context.t('All'), all.length),
            ],
            selected: _filter,
            onSelect: (i) => setState(() => _filter = i),
          ),
          const SizedBox(height: 10),
          // Date + restaurant filter row
          Row(children: [
            // Date chip
            GestureDetector(
              onTap: () => _pickDate(context),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                decoration: BoxDecoration(
                  color: _day != null ? C.brand50 : C.slate100,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: _day != null ? C.brand300 : C.slate200),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.calendar_today_outlined, size: 14, color: _day != null ? C.brand600 : C.slate500),
                  const SizedBox(width: 6),
                  Text(_dayLabel(context), style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: _day != null ? C.brand700 : C.slate600)),
                  if (_day != null) ...[
                    const SizedBox(width: 6),
                    GestureDetector(
                      onTap: () { setState(() => _day = null); _refresh(); },
                      child: const Icon(Icons.close, size: 14, color: C.brand400),
                    ),
                  ],
                ]),
              ),
            ),
            const SizedBox(width: 8),
            // Restaurant chip
            Expanded(
              child: GestureDetector(
                onTap: _restaurants.isEmpty ? null : () async {
                  final id = await showModalBottomSheet<String?>(
                    context: context,
                    builder: (_) => _RestaurantPicker(
                      restaurants: _restaurants,
                      selected: _restaurantId,
                    ),
                  );
                  if (!mounted) return;
                  if (id != _restaurantId) {
                    setState(() => _restaurantId = id);
                    await _refresh();
                  }
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                  decoration: BoxDecoration(
                    color: _restaurantId != null ? C.brand50 : C.slate100,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: _restaurantId != null ? C.brand300 : C.slate200),
                  ),
                  child: Row(children: [
                    Icon(Icons.storefront_outlined, size: 14, color: _restaurantId != null ? C.brand600 : C.slate500),
                    const SizedBox(width: 6),
                    Expanded(child: Text(restaurantName, maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: _restaurantId != null ? C.brand700 : C.slate600))),
                    if (_restaurantId != null) ...[
                      const SizedBox(width: 4),
                      GestureDetector(
                        onTap: () { setState(() => _restaurantId = null); _refresh(); },
                        child: const Icon(Icons.close, size: 14, color: C.brand400),
                      ),
                    ] else
                      const Icon(Icons.expand_more, size: 14, color: C.slate400),
                  ]),
                ),
              ),
            ),
          ]),
          const SizedBox(height: 14),
          if (_rows == null)
            const Padding(padding: EdgeInsets.all(40), child: Center(child: CircularProgressIndicator(color: C.brand600)))
          else if (shown.isEmpty)
            EmptyState(emoji: '🧾', title: context.t('No orders yet.'))
          else
            CardBox(
              padding: EdgeInsets.zero,
              child: Column(children: [
                for (var i = 0; i < shown.length; i++) FadeInUp(index: i, child: _row(shown[i], i == 0)),
              ]),
            ),
        ]),
      ),
    );
  }

  Widget _row(Map<String, dynamic> o, bool first) {
    final status = o['status'] as String;
    final (bg, fg) = statusColors(status);
    final active = AdminRepo._active.contains(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(border: first ? null : const Border(top: BorderSide(color: C.slate100))),
      child: Row(children: [
        Container(
          width: 40,
          height: 40,
          alignment: Alignment.center,
          decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)),
          child: Text(status == 'delivered' ? '✅' : status == 'picked_up' ? '🛵' : active ? '🍳' : '🧾', style: const TextStyle(fontSize: 18)),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(o['restaurants']?['name'] ?? '—', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800)),
            Text(
              '${o['profiles']?['full_name'] ?? '—'} · ${context.i18n.dateTime(o['created_at'])}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12, color: C.slate500),
            ),
            const SizedBox(height: 4),
            Pill(context.i18n.status(status), bg: bg, fg: fg, fontSize: 10, leading: active ? LiveDot(color: fg, size: 5) : null),
          ]),
        ),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text(formatPrice((o['total_cents'] as num).toInt()), style: const TextStyle(fontWeight: FontWeight.w900)),
          Text('#${(o['id'] as String).substring(0, 8)}', style: const TextStyle(fontSize: 11, color: C.slate400, fontFamily: 'monospace')),
        ]),
      ]),
    );
  }
}

// ─── Restaurant picker bottom sheet ───────────────────────────────────────────

class _RestaurantPicker extends StatelessWidget {
  final List<Map<String, dynamic>> restaurants;
  final String? selected;
  const _RestaurantPicker({required this.restaurants, required this.selected});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        const SizedBox(height: 8),
        Container(width: 36, height: 4, decoration: BoxDecoration(color: C.slate300, borderRadius: BorderRadius.circular(2))),
        const SizedBox(height: 12),
        ListTile(
          leading: const Icon(Icons.restaurant_menu, size: 18, color: C.slate400),
          title: Text(context.t('All restaurants'), style: const TextStyle(fontWeight: FontWeight.w600)),
          selected: selected == null,
          selectedColor: C.brand600,
          onTap: () => Navigator.pop(context, null),
        ),
        const Divider(height: 1),
        Flexible(
          child: ListView.separated(
            shrinkWrap: true,
            itemCount: restaurants.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (_, i) {
              final r = restaurants[i];
              return ListTile(
                leading: const Icon(Icons.storefront_outlined, size: 18, color: C.slate400),
                title: Text(r['name'] as String, style: const TextStyle(fontWeight: FontWeight.w500)),
                selected: selected == r['id'],
                selectedColor: C.brand600,
                onTap: () => Navigator.pop(context, r['id'] as String),
              );
            },
          ),
        ),
        const SizedBox(height: 8),
      ]),
    );
  }
}

// ---------------- Users ----------------

class _Users extends StatefulWidget {
  const _Users();
  @override
  State<_Users> createState() => _UsersState();
}

class _UsersState extends State<_Users> {
  List<Map<String, dynamic>>? _rows;
  int _filter = 0;
  final _q = TextEditingController();
  static const _roles = [null, 'client', 'restaurant_owner', 'driver', 'admin'];

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    try {
      final r = await AdminRepo.users();
      if (mounted) setState(() => _rows = r);
    } catch (e) {
      if (mounted) showError(context, errorMessage(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final all = _rows ?? [];
    final q = _q.text.trim().toLowerCase();
    final role = _roles[_filter];
    final shown = all
        .where((u) => role == null || u['role'] == role)
        .where((u) => q.isEmpty || '${u['full_name']} ${u['phone']}'.toLowerCase().contains(q))
        .toList();
    return SafeArea(
      child: RefreshIndicator(
        color: C.brand600,
        onRefresh: _refresh,
        child: ListView(padding: const EdgeInsets.fromLTRB(16, 12, 16, 24), children: [
          PageHeader(context.t('Users')),
          _SearchBox(controller: _q, hint: context.t('Search'), onChanged: () => setState(() {})),
          const SizedBox(height: 12),
          FilterTabs(
            tabs: [
              for (final r in _roles)
                (r == null ? context.t('All') : '${_roleEmoji[r]} ${context.t(_roleText[r]!)}', r == null ? all.length : all.where((u) => u['role'] == r).length),
            ],
            selected: _filter,
            onSelect: (i) => setState(() => _filter = i),
          ),
          const SizedBox(height: 14),
          if (_rows == null)
            const Padding(padding: EdgeInsets.all(40), child: Center(child: CircularProgressIndicator(color: C.brand600)))
          else if (shown.isEmpty)
            EmptyState(emoji: '👥', title: context.t('No users yet.'))
          else
            CardBox(
              padding: EdgeInsets.zero,
              child: Column(children: [
                for (var i = 0; i < shown.length; i++) FadeInUp(index: i, child: _row(shown[i], i == 0)),
              ]),
            ),
        ]),
      ),
    );
  }

  Widget _row(Map<String, dynamic> u, bool first) {
    final name = (u['full_name'] as String?) ?? '';
    final role = u['role'] as String? ?? 'client';
    final colors = switch (role) {
      'admin' => (C.slate900, Colors.white),
      'restaurant_owner' => (C.brand100, C.brand700),
      'driver' => (C.purple100, C.purple700),
      _ => (C.blue100, C.blue700),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(border: first ? null : const Border(top: BorderSide(color: C.slate100))),
      child: Row(children: [
        Container(
          width: 40,
          height: 40,
          alignment: Alignment.center,
          decoration: const BoxDecoration(shape: BoxShape.circle, gradient: LinearGradient(colors: [C.brand100, C.rose100])),
          child: Text(name.isEmpty ? '?' : name.characters.first.toUpperCase(), style: const TextStyle(fontWeight: FontWeight.w900, color: C.brand700)),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(name.isEmpty ? '—' : name, style: const TextStyle(fontWeight: FontWeight.w800)),
            Text(
              [if ((u['phone'] as String?)?.isNotEmpty == true) u['phone'], if (u['created_at'] != null) context.i18n.date(u['created_at'])].join(' · '),
              style: const TextStyle(fontSize: 12, color: C.slate500),
            ),
          ]),
        ),
        Pill('${_roleEmoji[role]} ${context.t(_roleText[role] ?? role)}', bg: colors.$1, fg: colors.$2, fontSize: 10),
        if ((u['phone'] as String?)?.isNotEmpty == true)
          IconButton(onPressed: () => _call(u['phone']), icon: const Icon(Icons.call_outlined, size: 18, color: C.slate500)),
      ]),
    );
  }
}
