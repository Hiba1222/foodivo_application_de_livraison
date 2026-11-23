import 'dart:async';

import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:material_ui/material_ui.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/money.dart';
import '../../core/order_codes.dart';
import '../../core/theme.dart';
import '../../data/repo.dart';
import '../../data/staff_repo.dart';
import '../auth_gate.dart';
import '../widgets.dart';
import 'staff_fx.dart';
import 'staff_widgets.dart';

const _vehicles = [('bike', 'Bike', '🚲'), ('scooter', 'Scooter', '🛵'), ('car', 'Car', '🚗')];

void _call(String? phone) {
  if (phone == null || phone.isEmpty) return;
  launchUrl(Uri(scheme: 'tel', path: phone.replaceAll(RegExp(r'[^+\d]'), '')));
}

void _maps(String? address, {num? lat, num? lng}) {
  final q = (address != null && address.isNotEmpty) ? Uri.encodeComponent(address) : (lat != null && lng != null ? '$lat,$lng' : null);
  if (q == null) return;
  launchUrl(Uri.parse('https://www.google.com/maps/search/?api=1&query=$q'), mode: LaunchMode.externalApplication);
}

/// Driver app: onboarding if no driver profile yet, otherwise Overview · Available · My deliveries · History · Settings.
class DriverArea extends StatefulWidget {
  const DriverArea({super.key});
  @override
  State<DriverArea> createState() => _DriverAreaState();
}

class _DriverAreaState extends State<DriverArea> {
  Map<String, dynamic>? _d;
  bool _loading = true;
  String? _error;
  int _available = 0;
  StreamSubscription? _availableLive;
  StreamSubscription<Position>? _gps;
  final _tab = ValueNotifier<int>(0);
  bool _firstSnapshot = true;

  @override
  void initState() {
    super.initState();
    _load();
    // Badge on the "Available" tab with orders waiting for a driver (+ buzz when a new one appears).
    _availableLive = sb.from('orders').stream(primaryKey: ['id']).eq('status', 'ready_for_pickup').listen((rows) {
      final n = rows.where((o) => o['driver_id'] == null).length;
      final ready = _d?['is_online'] == true && _d?['is_approved'] == true;
      if (!_firstSnapshot && ready && n > _available && mounted) {
        HapticFeedback.heavyImpact();
        showToast(context, '🛵 ${context.i18n.t('New delivery available!')}', icon: Icons.notifications_active, iconColor: C.amber400);
      }
      _firstSnapshot = false;
      if (mounted) setState(() => _available = n);
    });
  }

  @override
  void dispose() {
    _availableLive?.cancel();
    _gps?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final d = await DriverRepo.mine();
      if (!mounted) return;
      setState(() => (_d = d, _loading = false, _error = null));
      _syncTracking();
    } catch (e) {
      if (mounted) setState(() => (_error = errorMessage(e), _loading = false));
    }
  }

  /// While online, share the phone's location (web LocationTracker). Silently skipped if refused.
  Future<void> _syncTracking() async {
    final online = _d?['is_online'] == true;
    if (!online) {
      await _gps?.cancel();
      _gps = null;
      return;
    }
    if (_gps != null) return;
    try {
      if (!await Geolocator.isLocationServiceEnabled()) return;
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) perm = await Geolocator.requestPermission();
      if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) return;
      DateTime? last;
      _gps = Geolocator.getPositionStream(locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, distanceFilter: 25)).listen((p) {
        // At most one update every 15 seconds.
        final now = DateTime.now();
        if (last != null && now.difference(last!).inSeconds < 15) return;
        last = now;
        DriverRepo.updateLocation(p.latitude, p.longitude).catchError((_) {});
      }, onError: (_) {});
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Scaffold(body: Center(child: CircularProgressIndicator(color: C.brand600)));
    if (_error != null) {
      return Scaffold(body: EmptyState(emoji: '📡', title: context.t(_error!), action: PrimaryButton(context.t('Retry'), expand: false, onPressed: _load)));
    }
    final d = _d;
    if (d == null) return _CreateDriver(onDone: _load);
    final approved = d['is_approved'] == true, online = d['is_online'] == true;
    return RoleShell(
      controller: _tab,
      badgeTab: approved && online ? 1 : null,
      badgeCount: _available,
      tabs: [
        (Icons.dashboard_outlined, 'Overview', _Overview(driver: d, onChanged: _load, onOpenTab: (i) => _tab.value = i)),
        (Icons.notifications_active_outlined, 'Available', _Available(approved: approved, online: online, onAccepted: () => _tab.value = 2)),
        (Icons.delivery_dining_outlined, 'My deliveries', const _MyDeliveries()),
        (Icons.history, 'History', const _History()),
        (Icons.settings_outlined, 'Settings', _Settings(driver: d, onSaved: _load)),
      ],
    );
  }
}

// ---------------- Onboarding ----------------

class _VehiclePicker extends StatelessWidget {
  final String value;
  final ValueChanged<String> onChanged;
  const _VehiclePicker({required this.value, required this.onChanged});
  @override
  Widget build(BuildContext context) => Row(children: [
        for (final v in _vehicles)
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Pressable(
                onTap: () => onChanged(v.$1),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: value == v.$1 ? C.brand50 : Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: value == v.$1 ? C.brand600 : C.slate200, width: value == v.$1 ? 2 : 1),
                  ),
                  child: Column(children: [
                    Text(v.$3, style: const TextStyle(fontSize: 26)),
                    const SizedBox(height: 4),
                    Text(context.t(v.$2), style: TextStyle(fontWeight: FontWeight.w800, color: value == v.$1 ? C.brand700 : C.slate600)),
                  ]),
                ),
              ),
            ),
          ),
      ]);
}

class _CreateDriver extends StatefulWidget {
  final VoidCallback onDone;
  const _CreateDriver({required this.onDone});
  @override
  State<_CreateDriver> createState() => _CreateDriverState();
}

class _CreateDriverState extends State<_CreateDriver> {
  final _plate = TextEditingController(), _phone = TextEditingController();
  String _vehicle = 'bike';
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    Repo.myProfile().then((p) {
      if (mounted && (p?['phone'] as String?)?.isNotEmpty == true) _phone.text = p!['phone'];
    });
  }

  Future<void> _submit() async {
    final i = context.i18n;
    if (_phone.text.trim().isEmpty) return setState(() => _error = i.t('Phone number is required'));
    setState(() => (_busy = true, _error = null));
    try {
      await DriverRepo.create(vehicle: _vehicle, plate: _plate.text.trim().isEmpty ? null : _plate.text.trim(), phone: _phone.text.trim());
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
                Text(context.t('Set up your driver profile'), style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
                const SizedBox(height: 4),
                Text(context.t('One more step before you can start accepting deliveries.'), style: const TextStyle(color: C.slate500)),
                const SizedBox(height: 18),
                Text(context.t('Vehicle type'), style: const TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                _VehiclePicker(value: _vehicle, onChanged: (v) => setState(() => _vehicle = v)),
                const SizedBox(height: 14),
                TextField(controller: _plate, decoration: InputDecoration(labelText: context.t('License plate (if applicable)'))),
                const SizedBox(height: 12),
                TextField(
                  controller: _phone,
                  keyboardType: TextInputType.phone,
                  decoration: InputDecoration(labelText: context.t('Phone number'), hintText: context.t('So clients and the restaurant can reach you'), prefixIcon: const Icon(Icons.phone_outlined)),
                ),
                if (_error != null) ...[const SizedBox(height: 10), Text(_error!, style: const TextStyle(color: C.red600, fontWeight: FontWeight.w600))],
                const SizedBox(height: 18),
                PrimaryButton(context.t('Submit for approval'), loading: _busy, onPressed: _submit),
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
  final Map<String, dynamic> driver;
  final VoidCallback onChanged;
  final ValueChanged<int> onOpenTab;
  const _Overview({required this.driver, required this.onChanged, required this.onOpenTab});
  @override
  State<_Overview> createState() => _OverviewState();
}

class _OverviewState extends State<_Overview> {
  (int, int, int)? _stats;
  (int, int)? _monthly;
  DateTime _month = DateTime.now();
  bool _toggling = false;
  StreamSubscription? _live;
  String? _name, _avatar;

  @override
  void initState() {
    super.initState();
    Repo.myProfile().then((p) {
      if (mounted) setState(() => (_name = p?['full_name'], _avatar = p?['avatar_url']));
    });
    _refresh();
    _live = sb.from('orders').stream(primaryKey: ['id']).eq('driver_id', sb.auth.currentUser!.id).listen((_) => _refresh());
  }

  @override
  void dispose() {
    _live?.cancel();
    super.dispose();
  }

  Future<void> _refresh() async {
    try {
      final results = await Future.wait([
        DriverRepo.stats(),
        DriverRepo.monthlyStats(month: _month),
      ]);
      if (mounted) setState(() {
        _stats = results[0] as (int, int, int);
        _monthly = results[1] as (int, int);
      });
    } catch (_) {}
  }

  void _prevMonth() {
    setState(() => _month = DateTime(_month.year, _month.month - 1));
    _refresh();
  }

  void _nextMonth() {
    final now = DateTime.now();
    if (_month.year == now.year && _month.month == now.month) return;
    setState(() => _month = DateTime(_month.year, _month.month + 1));
    _refresh();
  }

  Future<void> _toggle() async {
    setState(() => _toggling = true);
    try {
      await DriverRepo.setOnline(!(widget.driver['is_online'] == true));
      widget.onChanged();
    } catch (e) {
      if (mounted) showError(context, errorMessage(e));
    } finally {
      if (mounted) setState(() => _toggling = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.driver;
    final approved = d['is_approved'] == true;
    final s = _stats;
    final v = _vehicles.firstWhere((x) => x.$1 == d['vehicle_type'], orElse: () => _vehicles.first);
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
            title: _name ?? context.t('Driver dashboard'),
            subtitle: '${v.$3} ${context.t(v.$2)}${(d['license_plate'] as String?)?.isNotEmpty == true ? ' · ${d['license_plate']}' : ''}',
            imageUrl: _avatar,
            emoji: v.$3,
            colors: const [Color(0xFF6366F1), Color(0xFF8B5CF6), C.rose500],
          ),
          const SizedBox(height: 16),
          if (!approved) ApprovalBanner(context.t("Your driver account is awaiting admin approval. You can't go online or accept deliveries until then.")),
          StatusToggle(
            on: d['is_online'] == true,
            busy: _toggling,
            onText: context.t('Online — tap to go offline'),
            offText: context.t('Offline — tap to go online'),
            onTap: approved ? _toggle : null,
          ),
          if (d['is_online'] == true)
            Padding(
              padding: const EdgeInsets.only(top: 8, left: 4),
              child: Text('📍 ${context.t('Your location is shared with customers while you are online.')}', style: const TextStyle(fontSize: 12, color: C.slate500)),
            ),
          const SizedBox(height: 16),
          StatRow(
            StatCard(
              index: 0,
              emoji: '🛵',
              tint: const Color(0xFF8B5CF6),
              highlight: (s?.$1 ?? 0) > 0,
              label: context.t('Active delivery'),
              value: s?.$1,
              onTap: () => widget.onOpenTab(2),
            ),
            StatCard(index: 1, emoji: '✅', tint: C.green600, label: context.t('Delivered today'), value: s?.$2, onTap: () => widget.onOpenTab(3)),
          ),
          const SizedBox(height: 12),
          StatCard(index: 2, emoji: '💰', tint: C.amber500, label: context.t('Earnings today'), value: s?.$3, format: formatPrice),
          const SizedBox(height: 20),
          Row(children: [
            GestureDetector(
              onTap: _prevMonth,
              child: const Icon(Icons.chevron_left, color: C.slate500),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                '${['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'][_month.month - 1]} ${_month.year}',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: C.slate500, letterSpacing: 0.5),
              ),
            ),
            if (!(_month.year == DateTime.now().year && _month.month == DateTime.now().month))
              GestureDetector(
                onTap: _nextMonth,
                child: const Icon(Icons.chevron_right, color: C.slate500),
              ),
          ]),
          const SizedBox(height: 8),
          StatRow(
            StatCard(index: 3, emoji: '📦', tint: C.indigo700, label: context.t('Deliveries this month'), value: _monthly?.$1),
            StatCard(index: 4, emoji: '💵', tint: C.green600, label: context.t('Earnings this month'), value: _monthly?.$2, format: formatPrice),
          ),
          if (approved && d['is_online'] != true) ...[
            const SizedBox(height: 16),
            FadeInUp(
              index: 3,
              child: Text('💡 ${context.t('Go online to start receiving delivery requests.')}', textAlign: TextAlign.center, style: const TextStyle(color: C.slate500)),
            ),
          ],
        ]),
      ),
    );
  }
}

// ---------------- Available deliveries ----------------

class _Available extends StatefulWidget {
  final bool approved, online;
  final VoidCallback onAccepted;
  const _Available({required this.approved, required this.online, required this.onAccepted});
  @override
  State<_Available> createState() => _AvailableState();
}

class _AvailableState extends State<_Available> {
  List<Map<String, dynamic>>? _orders;
  String? _error;
  String? _accepting;
  StreamSubscription? _live;

  @override
  void initState() {
    super.initState();
    _refresh();
    _live = sb.from('orders').stream(primaryKey: ['id']).eq('status', 'ready_for_pickup').listen((_) => _refresh());
  }

  @override
  void dispose() {
    _live?.cancel();
    super.dispose();
  }

  Future<void> _refresh() async {
    try {
      final o = await DriverRepo.available();
      if (mounted) setState(() => (_orders = o, _error = null));
    } catch (e) {
      if (mounted) setState(() => _error = errorMessage(e));
    }
  }

  Future<void> _accept(String id) async {
    HapticFeedback.mediumImpact();
    setState(() => _accepting = id);
    try {
      final ok = await DriverRepo.accept(id);
      if (!mounted) return;
      if (ok) {
        celebrate(context, emojis: const ['🛵', '💨', '✨', '🧡']);
        showToast(context, context.i18n.t('Delivery accepted! Find it in My deliveries.'));
        widget.onAccepted();
      } else {
        showError(context, context.i18n.t('This delivery was just taken by another driver.'));
      }
      await _refresh();
    } catch (e) {
      if (mounted) showError(context, errorMessage(e));
    } finally {
      if (mounted) setState(() => _accepting = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final orders = _orders;
    Widget content;
    if (!widget.approved) {
      content = EmptyState(emoji: '⏳', title: context.t('You can browse available deliveries once an admin approves your driver account.'));
    } else if (!widget.online) {
      content = EmptyState(emoji: '😴', title: context.t('Go online from the Overview page to see available deliveries.'));
    } else if (orders == null && _error == null) {
      content = const Padding(padding: EdgeInsets.all(40), child: Center(child: CircularProgressIndicator(color: C.brand600)));
    } else if (orders == null) {
      content = EmptyState(emoji: '📡', title: context.t(_error!), action: PrimaryButton(context.t('Retry'), expand: false, onPressed: _refresh));
    } else if (orders.isEmpty) {
      content = Column(children: [
        const SizedBox(height: 30),
        const _Radar(),
        const SizedBox(height: 18),
        Text(context.t('No deliveries waiting right now.'), textAlign: TextAlign.center, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: C.slate800)),
        const SizedBox(height: 4),
        Text(context.t("We'll buzz you as soon as an order is ready."), textAlign: TextAlign.center, style: const TextStyle(color: C.slate500)),
      ]);
    } else {
      content = Column(children: [
        for (var i = 0; i < orders.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: FadeInUp(index: i, child: _card(orders[i])),
          ),
      ]);
    }
    return SafeArea(
      child: RefreshIndicator(
        color: C.brand600,
        onRefresh: _refresh,
        child: ListView(padding: const EdgeInsets.fromLTRB(16, 12, 16, 24), children: [
          PageHeader(context.t('Available deliveries'), subtitle: context.t('First to accept gets it — this list updates as other drivers pick up orders.')),
          content,
        ]),
      ),
    );
  }

  Widget _card(Map<String, dynamic> o) {
    final fee = (o['delivery_fee_cents'] as num).toInt();
    return PulseBorder(
      color: C.green500,
      child: CardBox(
        borderColor: const Color(0xFF86EFAC),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            Container(
              width: 44,
              height: 44,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: C.brand50, borderRadius: BorderRadius.circular(14)),
              child: const Text('🛍️', style: TextStyle(fontSize: 22)),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(o['restaurants']?['name'] ?? '', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
                Text(context.t('Ready for pickup'), style: const TextStyle(fontSize: 12, color: C.indigo700, fontWeight: FontWeight.w700)),
              ]),
            ),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text('+${formatPrice(fee)}', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: C.green700)),
              Text(context.t('Earned'), style: const TextStyle(fontSize: 11, color: C.slate500)),
            ]),
          ]),
          const SizedBox(height: 14),
          _Route(pickup: o['restaurants']?['address'], dropoff: o['client_addresses']?['address_line']),
          const SizedBox(height: 14),
          PrimaryButton(
            context.t('Accept'),
            loading: _accepting == o['id'],
            onPressed: _accepting == null ? () => _accept(o['id']) : null,
            trailing: const Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 18),
          ),
        ]),
      ),
    );
  }
}

/// Pickup ● ┆ ● Dropoff vertical route.
class _Route extends StatelessWidget {
  final String? pickup, dropoff;
  final VoidCallback? onPickupMap, onDropoffMap;
  final bool pickupDone;
  const _Route({this.pickup, this.dropoff, this.onPickupMap, this.onDropoffMap, this.pickupDone = false});
  @override
  Widget build(BuildContext context) {
    Widget dot(Color c, bool filled) => Container(
          width: 14,
          height: 14,
          decoration: BoxDecoration(shape: BoxShape.circle, color: filled ? c : Colors.white, border: Border.all(color: c, width: 3)),
        );
    Widget row(String label, String? text, Color c, VoidCallback? onMap, bool faded) => Opacity(
          opacity: faded ? 0.45 : 1,
          child: Row(children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: c, letterSpacing: 0.4)),
                Text(text ?? '—', style: const TextStyle(fontWeight: FontWeight.w600, color: C.slate800)),
              ]),
            ),
            if (onMap != null)
              Pressable(
                onTap: onMap,
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: C.blue100, borderRadius: BorderRadius.circular(10)),
                  child: const Icon(Icons.navigation_outlined, size: 18, color: C.blue700),
                ),
              ),
          ]),
        );
    return IntrinsicHeight(
      child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        SizedBox(
          width: 20,
          child: Column(children: [
            const SizedBox(height: 4),
            dot(C.brand600, pickupDone),
            Expanded(child: Container(width: 2, margin: const EdgeInsets.symmetric(vertical: 3), color: C.slate200)),
            dot(C.rose600, false),
            const SizedBox(height: 4),
          ]),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            row(context.t('Pickup').toUpperCase(), pickup, C.brand600, onPickupMap, pickupDone),
            const SizedBox(height: 14),
            row(context.t('Dropoff').toUpperCase(), dropoff, C.rose600, onDropoffMap, false),
          ]),
        ),
      ]),
    );
  }
}

/// Animated radar shown while waiting for deliveries.
class _Radar extends StatefulWidget {
  const _Radar();
  @override
  State<_Radar> createState() => _RadarState();
}

class _RadarState extends State<_Radar> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 2400))..repeat();
  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SizedBox(
        width: 170,
        height: 170,
        child: AnimatedBuilder(
          animation: _c,
          builder: (_, _) => Stack(alignment: Alignment.center, children: [
            for (final o in [0.0, 0.33, 0.66])
              Builder(builder: (_) {
                final v = (_c.value + o) % 1;
                return Container(
                  width: 60 + 110 * v,
                  height: 60 + 110 * v,
                  decoration: BoxDecoration(shape: BoxShape.circle, color: C.brand500.withValues(alpha: 0.18 * (1 - v)), border: Border.all(color: C.brand400.withValues(alpha: 0.5 * (1 - v)))),
                );
              }),
            Container(
              width: 70,
              height: 70,
              alignment: Alignment.center,
              decoration: BoxDecoration(shape: BoxShape.circle, gradient: C.buttonGradient, boxShadow: Shadows.glow),
              child: const Text('🛵', style: TextStyle(fontSize: 34)),
            ),
          ]),
        ),
      );
}

// ---------------- My deliveries ----------------

class _MyDeliveries extends StatefulWidget {
  const _MyDeliveries();
  @override
  State<_MyDeliveries> createState() => _MyDeliveriesState();
}

class _MyDeliveriesState extends State<_MyDeliveries> {
  List<Map<String, dynamic>>? _orders;
  String? _error;
  StreamSubscription? _live;

  @override
  void initState() {
    super.initState();
    _refresh();
    _live = sb.from('orders').stream(primaryKey: ['id']).eq('driver_id', sb.auth.currentUser!.id).listen((_) => _refresh());
  }

  @override
  void dispose() {
    _live?.cancel();
    super.dispose();
  }

  Future<void> _refresh() async {
    try {
      final o = await DriverRepo.active();
      if (mounted) setState(() => (_orders = o, _error = null));
    } catch (e) {
      if (mounted) setState(() => _error = errorMessage(e));
    }
  }

  Future<void> _do(String id, Future<void> Function(String) action, String toast) async {
    try {
      await action(id);
      if (mounted) {
        if (toast == 'Delivered') celebrate(context);
        showToast(context, context.i18n.t(toast));
      }
      await _refresh();
    } catch (e) {
      if (mounted) showError(context, errorMessage(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final orders = _orders;
    return SafeArea(
      child: RefreshIndicator(
        color: C.brand600,
        onRefresh: _refresh,
        child: ListView(padding: const EdgeInsets.fromLTRB(16, 12, 16, 24), children: [
          PageHeader(context.t('My deliveries')),
          if (orders == null && _error == null)
            const Padding(padding: EdgeInsets.all(40), child: Center(child: CircularProgressIndicator(color: C.brand600)))
          else if (orders == null)
            EmptyState(emoji: '📡', title: context.t(_error!), action: PrimaryButton(context.t('Retry'), expand: false, onPressed: _refresh))
          else if (orders.isEmpty)
            EmptyState(emoji: '🛵', title: context.t('No active deliveries. Check Available deliveries to accept one.'))
          else
            for (var i = 0; i < orders.length; i++)
              Padding(key: ValueKey(orders[i]['id']), padding: const EdgeInsets.only(bottom: 12), child: FadeInUp(index: i, child: _card(orders[i]))),
        ]),
      ),
    );
  }

  Widget _card(Map<String, dynamic> o) {
    final status = o['status'] as String;
    final (bg, fg) = statusColors(status);
    final client = o['profiles'] as Map<String, dynamic>?;
    final restaurant = o['restaurants'] as Map<String, dynamic>?;
    final dropoff = o['client_addresses'] as Map<String, dynamic>?;
    final pickedUp = status == 'picked_up';
    final hasClientPhone = (client?['phone'] as String?)?.isNotEmpty == true;
    final hasRestaurantPhone = (restaurant?['phone'] as String?)?.isNotEmpty == true;
    return CardBox(
      borderColor: C.indigo100,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Expanded(child: Text(restaurant?['name'] ?? '', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 17))),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            transitionBuilder: (c, a) => ScaleTransition(scale: a, child: c),
            child: Pill(context.i18n.status(status), key: ValueKey(status), bg: bg, fg: fg, leading: LiveDot(color: fg, size: 6)),
          ),
        ]),
        const SizedBox(height: 14),
        StepTracker(
          color: const Color(0xFF8B5CF6),
          current: pickedUp ? 1 : 0,
          steps: [
            ('🏪', context.t('Pickup')),
            ('🛵', context.t('On the way')),
            ('🏠', context.t('Dropoff')),
          ],
        ),
        const SizedBox(height: 16),
        _Route(
          pickup: restaurant?['address'],
          dropoff: dropoff?['address_line'],
          pickupDone: pickedUp,
          onPickupMap: pickedUp ? null : () => _maps(restaurant?['address']),
          onDropoffMap: () => _maps(dropoff?['address_line'], lat: dropoff?['latitude'], lng: dropoff?['longitude']),
        ),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: C.slate50, borderRadius: BorderRadius.circular(14)),
          child: Row(children: [
            Container(
              width: 40,
              height: 40,
              alignment: Alignment.center,
              decoration: const BoxDecoration(shape: BoxShape.circle, gradient: LinearGradient(colors: [C.brand100, C.rose100])),
              child: Text(((client?['full_name'] as String?) ?? '?').characters.first.toUpperCase(), style: const TextStyle(fontWeight: FontWeight.w900, color: C.brand700)),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(client?['full_name'] ?? '—', style: const TextStyle(fontWeight: FontWeight.w800)),
                Text(client?['phone'] ?? context.t('no phone on file'), style: const TextStyle(fontSize: 12, color: C.slate500)),
              ]),
            ),
            if (hasClientPhone) _RoundAction(icon: Icons.call, color: C.green600, onTap: () => _call(client!['phone'])),
            if (!pickedUp && hasRestaurantPhone) ...[
              const SizedBox(width: 8),
              _RoundAction(icon: Icons.storefront_outlined, color: C.brand600, onTap: () => _call(restaurant!['phone'])),
            ],
          ]),
        ),
        // Order items (compact chips)
        Builder(builder: (_) {
          final items = (o['order_items'] as List?) ?? const [];
          if (items.isEmpty) return const SizedBox.shrink();
          return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Divider(height: 24),
            Wrap(spacing: 8, runSpacing: 8, children: [
              for (final oi in items)
                Container(
                  padding: const EdgeInsets.only(right: 10),
                  decoration: BoxDecoration(color: C.slate50, borderRadius: BorderRadius.circular(10), border: Border.all(color: C.slate200)),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    ClipRRect(
                      borderRadius: const BorderRadius.horizontal(left: Radius.circular(9)),
                      child: SizedBox(width: 32, height: 32, child: NetImage(oi['menu_items']?['image_url'] as String?)),
                    ),
                    const SizedBox(width: 8),
                    Text('${oi['quantity']}× ${oi['menu_items']?['name'] ?? ''}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: C.slate700)),
                  ]),
                ),
            ]),
            const SizedBox(height: 4),
          ]);
        }),
        const SizedBox(height: 14),
        // Verification codes
        Row(children: [
          if (!pickedUp)
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(right: 6),
                decoration: BoxDecoration(color: const Color(0xFFEEF2FF), borderRadius: BorderRadius.circular(14)),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(context.t('Pickup code'), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: C.indigo700)),
                  Text(pickupCode(o['id']), style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, letterSpacing: 4, color: C.indigo700)),
                  Text(context.t('Show to restaurant'), style: const TextStyle(fontSize: 10, color: C.indigo700)),
                ]),
              ),
            ),
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(12),
              margin: EdgeInsets.only(left: pickedUp ? 0 : 6),
              decoration: BoxDecoration(color: const Color(0xFFF0FDF4), borderRadius: BorderRadius.circular(14)),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(context.t('Delivery code'), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: C.green700)),
                Text(deliveryCode(o['id']), style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, letterSpacing: 4, color: C.green700)),
                Text(context.t('Ask client for this code'), style: const TextStyle(fontSize: 10, color: C.green600)),
              ]),
            ),
          ),
        ]),
        const SizedBox(height: 14),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 350),
          transitionBuilder: (c, a) => FadeTransition(opacity: a, child: SizeTransition(sizeFactor: a, child: c)),
          child: status == 'driver_assigned'
              ? SlideToConfirm(
                  key: const ValueKey('pickup'),
                  label: context.t('Slide when picked up'),
                  color: const Color(0xFF9333EA),
                  icon: Icons.shopping_bag_outlined,
                  onConfirm: () => _do(o['id'], DriverRepo.markPickedUp, 'Picked up'),
                )
              : SlideToConfirm(
                  key: const ValueKey('deliver'),
                  label: context.t('Slide when delivered'),
                  color: C.green600,
                  icon: Icons.check_rounded,
                  onConfirm: () => _do(o['id'], DriverRepo.markDelivered, 'Delivered'),
                ),
        ),
      ]),
    );
  }
}

class _RoundAction extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  const _RoundAction({required this.icon, required this.color, required this.onTap});
  @override
  Widget build(BuildContext context) => Pressable(
        onTap: onTap,
        scale: 0.9,
        child: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(shape: BoxShape.circle, color: color, boxShadow: [BoxShadow(color: color.withValues(alpha: 0.4), blurRadius: 12, spreadRadius: -3, offset: const Offset(0, 5))]),
          child: Icon(icon, color: Colors.white, size: 20),
        ),
      );
}

// ---------------- History ----------------

class _History extends StatefulWidget {
  const _History();
  @override
  State<_History> createState() => _HistoryState();
}

class _HistoryState extends State<_History> {
  List<Map<String, dynamic>>? _orders;
  StreamSubscription? _live;

  @override
  void initState() {
    super.initState();
    _refresh();
    _live = sb.from('orders').stream(primaryKey: ['id']).eq('driver_id', sb.auth.currentUser!.id).listen((_) => _refresh());
  }

  @override
  void dispose() {
    _live?.cancel();
    super.dispose();
  }

  Future<void> _refresh() async {
    try {
      final o = await DriverRepo.history();
      if (mounted) setState(() => _orders = o);
    } catch (e) {
      if (mounted) showError(context, errorMessage(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final orders = _orders;
    final total = (orders ?? []).fold<int>(0, (s, o) => s + ((o['delivery_fee_cents'] as num?)?.toInt() ?? 0));
    return SafeArea(
      child: RefreshIndicator(
        color: C.brand600,
        onRefresh: _refresh,
        child: ListView(padding: const EdgeInsets.fromLTRB(16, 12, 16, 24), children: [
          PageHeader(context.t('Delivery history'), trailing: orders == null || orders.isEmpty ? null : Pill(formatPrice(total), bg: C.green100, fg: C.green700, fontSize: 13)),
          if (orders == null)
            const Padding(padding: EdgeInsets.all(40), child: Center(child: CircularProgressIndicator(color: C.brand600)))
          else if (orders.isEmpty)
            EmptyState(emoji: '📭', title: context.t('No deliveries completed yet.'))
          else
            CardBox(
              padding: EdgeInsets.zero,
              child: Column(children: [
                for (var i = 0; i < orders.length; i++)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(border: i == 0 ? null : const Border(top: BorderSide(color: C.slate100))),
                    child: Row(children: [
                      const Text('✅', style: TextStyle(fontSize: 18)),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(orders[i]['restaurants']?['name'] ?? '', style: const TextStyle(fontWeight: FontWeight.w700)),
                          Text(
                            orders[i]['delivered_at'] == null ? '—' : context.i18n.dateTime(orders[i]['delivered_at']),
                            style: const TextStyle(fontSize: 12, color: C.slate500),
                          ),
                        ]),
                      ),
                      Text(formatPrice((orders[i]['delivery_fee_cents'] as num).toInt()), style: const TextStyle(fontWeight: FontWeight.w800)),
                    ]),
                  ),
              ]),
            ),
        ]),
      ),
    );
  }
}

// ---------------- Settings ----------------

class _Settings extends StatefulWidget {
  final Map<String, dynamic> driver;
  final VoidCallback onSaved;
  const _Settings({required this.driver, required this.onSaved});
  @override
  State<_Settings> createState() => _SettingsState();
}

class _SettingsState extends State<_Settings> {
  late String _vehicle = widget.driver['vehicle_type'] ?? 'bike';
  late final _plate = TextEditingController(text: widget.driver['license_plate'] ?? '');
  final _phone = TextEditingController();
  final _name = TextEditingController();
  Map<String, dynamic>? _profile;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    Repo.myProfile().then((p) {
      if (!mounted) return;
      setState(() => _profile = p);
      _phone.text = p?['phone'] ?? '';
      _name.text = p?['full_name'] ?? '';
    });
  }

  Future<void> _save() async {
    final i = context.i18n;
    if (_phone.text.trim().isEmpty) return showError(context, i.t('Phone number is required'));
    setState(() => _saving = true);
    try {
      await DriverRepo.update(vehicle: _vehicle, plate: _plate.text.trim().isEmpty ? null : _plate.text.trim(), phone: _phone.text.trim(), fullName: _name.text.trim().isEmpty ? null : _name.text.trim());
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
    final uid = sb.auth.currentUser!.id;
    return SafeArea(
      child: ListView(padding: const EdgeInsets.fromLTRB(16, 12, 16, 24), children: [
        PageHeader(context.t('Settings'), subtitle: context.t("Your photo and phone number are shown to clients while you're delivering their order.")),
        CardBox(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(_profile?['full_name'] ?? '', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
            Text(sb.auth.currentUser?.email ?? '', style: const TextStyle(color: C.slate500, fontSize: 13)),
            const SizedBox(height: 14),
            Text(context.t('Profile photo'), style: const TextStyle(fontWeight: FontWeight.w800)),
            const SizedBox(height: 10),
            if (_profile != null)
              PhotoPicker(
                currentUrl: _profile!['avatar_url'],
                circle: true,
                storagePath: 'avatars/$uid/photo.jpg',
                table: 'profiles',
                column: 'avatar_url',
                rowId: uid,
              ),
          ]),
        ),
        const SizedBox(height: 12),
        CardBox(
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            TextField(controller: _name, decoration: InputDecoration(labelText: context.t('Full name'), prefixIcon: const Icon(Icons.person_outlined))),
            const SizedBox(height: 14),
            TextField(controller: _phone, keyboardType: TextInputType.phone, decoration: InputDecoration(labelText: context.t('Phone number'), prefixIcon: const Icon(Icons.phone_outlined))),
            const SizedBox(height: 14),
            Text(context.t('Vehicle type'), style: const TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            _VehiclePicker(value: _vehicle, onChanged: (v) => setState(() => _vehicle = v)),
            const SizedBox(height: 14),
            TextField(controller: _plate, decoration: InputDecoration(labelText: context.t('License plate'))),
            const SizedBox(height: 16),
            PrimaryButton(context.t('Save changes'), loading: _saving, onPressed: _save),
          ]),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: const Color(0xFFFFFBEB), borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFFFDE68A))),
          child: Row(children: [
            const Text('💡', style: TextStyle(fontSize: 18)),
            const SizedBox(width: 10),
            Expanded(child: Text(context.t("Foodivo takes a 10% platform fee from your delivery earnings on each completed order."), style: const TextStyle(fontSize: 12, color: Color(0xFF92400E)))),
          ]),
        ),
        const SizedBox(height: 12),
        const AccountCard(),
      ]),
    );
  }
}
