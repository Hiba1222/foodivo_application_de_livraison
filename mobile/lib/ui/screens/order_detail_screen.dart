import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/money.dart';
import '../../core/theme.dart';
import '../../data/models.dart';
import '../../data/repo.dart';
import '../widgets.dart';

const _flow = ['pending', 'accepted', 'ready_for_pickup', 'driver_assigned', 'picked_up', 'delivered'];
const _stepLabel = {
  'pending': 'Order placed',
  'accepted': 'Restaurant accepted',
  'rejected': 'Restaurant rejected',
  'ready_for_pickup': 'Ready for pickup',
  'driver_assigned': 'Driver assigned',
  'picked_up': 'Picked up — on the way',
  'delivered': 'Delivered',
  'cancelled': 'Cancelled',
};
const _stepEmoji = {
  'pending': '🧾',
  'accepted': '👨‍🍳',
  'ready_for_pickup': '📦',
  'driver_assigned': '🛵',
  'picked_up': '🚀',
  'delivered': '✅',
};

class OrderDetailScreen extends StatefulWidget {
  final String orderId;
  const OrderDetailScreen({super.key, required this.orderId});
  @override
  State<OrderDetailScreen> createState() => _OrderDetailScreenState();
}

class _OrderDetailScreenState extends State<OrderDetailScreen> {
  Map<String, dynamic>? _order;
  List<Map<String, dynamic>> _history = [];
  DriverInfo? _driver;
  bool _loaded = false;
  StreamSubscription? _live;

  @override
  void initState() {
    super.initState();
    _load();
    // Live: re-load whenever this order row changes (status, driver…).
    _live = sb.from('orders').stream(primaryKey: ['id']).eq('id', widget.orderId).listen((_) => _load());
  }

  @override
  void dispose() {
    _live?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final o = await Repo.orderDetail(widget.orderId);
      final h = await Repo.statusHistory(widget.orderId);
      DriverInfo? d;
      if (o != null && o['driver_id'] != null && (o['status'] == 'driver_assigned' || o['status'] == 'picked_up')) {
        d = await Repo.orderDriver(widget.orderId);
      }
      if (mounted) {
        setState(() {
          _order = o;
          _history = h;
          _driver = d;
          _loaded = true;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loaded = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final o = _order;
    final i18n = context.i18n;
    return Scaffold(
      appBar: AppBar(title: Text(o == null ? '' : context.t('Order from {name}', {'name': (o['restaurants'] as Map?)?['name'] ?? ''}))),
      body: !_loaded
          ? const Center(child: CircularProgressIndicator(color: C.brand600))
          : o == null
              ? EmptyState(emoji: '🤷', title: context.t('Order not found.'))
              : RefreshIndicator(
                  color: C.brand600,
                  onRefresh: _load,
                  child: ListView(padding: const EdgeInsets.all(16), children: [
                    Text(context.t('Placed {date}', {'date': i18n.dateTime(o['created_at'])}), style: const TextStyle(color: C.slate500)),
                    const SizedBox(height: 14),
                    FadeInUp(child: _Timeline(status: o['status'], history: _history)),
                    if (_driver != null) ...[const SizedBox(height: 14), FadeInUp(index: 1, child: _DriverCard(driver: _driver!, pickedUp: o['status'] == 'picked_up'))],
                    const SizedBox(height: 14),
                    FadeInUp(index: 2, child: _Items(order: o)),
                    const SizedBox(height: 24),
                  ]),
                ),
    );
  }
}

class _Timeline extends StatelessWidget {
  final String status;
  final List<Map<String, dynamic>> history;
  const _Timeline({required this.status, required this.history});
  @override
  Widget build(BuildContext context) {
    final i18n = context.i18n;
    if (status == 'rejected' || status == 'cancelled') {
      return CardBox(child: Text(context.t(_stepLabel[status]!), style: const TextStyle(color: C.red600, fontWeight: FontWeight.w800)));
    }
    final current = _flow.indexOf(status);
    return CardBox(
      child: Column(children: [
        for (var i = 0; i < _flow.length; i++)
          Builder(builder: (_) {
            final step = _flow[i];
            final reached = i <= current;
            final isCurrent = i == current && status != 'delivered';
            final h = history.where((e) => e['status'] == step).firstOrNull;
            return IntrinsicHeight(
              child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                SizedBox(
                  width: 34,
                  child: Column(children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 400),
                      width: 30,
                      height: 30,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: reached ? C.brand600 : C.slate100,
                        boxShadow: isCurrent ? Shadows.glow : null,
                      ),
                      child: isCurrent
                          ? const LiveDot(color: Colors.white, size: 8)
                          : Text(reached ? (_stepEmoji[step] ?? '•') : '', style: const TextStyle(fontSize: 13)),
                    ),
                    if (i < _flow.length - 1)
                      Expanded(
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 400),
                          width: 3,
                          margin: const EdgeInsets.symmetric(vertical: 2),
                          color: i < current ? C.brand500 : C.slate200,
                        ),
                      ),
                  ]),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 5, bottom: 16),
                    child: Row(children: [
                      Expanded(
                        child: Text(context.t(_stepLabel[step]!),
                            style: TextStyle(fontWeight: reached ? FontWeight.w700 : FontWeight.w400, color: reached ? C.slate900 : C.slate400)),
                      ),
                      if (h != null) Text(i18n.time(h['changed_at']), style: const TextStyle(fontSize: 12, color: C.slate400)),
                    ]),
                  ),
                ),
              ]),
            );
          }),
      ]),
    );
  }
}

class _DriverCard extends StatelessWidget {
  final DriverInfo driver;
  final bool pickedUp;
  const _DriverCard({required this.driver, required this.pickedUp});

  @override
  Widget build(BuildContext context) {
    final d = driver;
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18), boxShadow: Shadows.soft, border: Border.all(color: C.slate200)),
      child: Column(children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
          decoration: const BoxDecoration(gradient: LinearGradient(colors: [C.brand500, C.rose500])),
          child: Row(children: [
            const LiveDot(color: Colors.white, size: 8),
            const SizedBox(width: 8),
            Expanded(
              child: Text(pickedUp ? '${context.t('Your order is on the way')} 🛵' : context.t('A driver is heading to the restaurant'),
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 13)),
            ),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(children: [
            Container(
              width: 56,
              height: 56,
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: C.brand50, width: 4), gradient: const LinearGradient(colors: [C.brand100, C.rose100])),
              alignment: Alignment.center,
              child: d.avatarUrl != null
                  ? NetImage(d.avatarUrl)
                  : Text(d.name.isNotEmpty ? d.name[0].toUpperCase() : '🛵', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: C.brand700)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(context.t('Your driver').toUpperCase(), style: const TextStyle(fontSize: 10, color: C.slate400, fontWeight: FontWeight.w700, letterSpacing: 0.8)),
                Text(d.name.isEmpty ? context.t('Your driver') : d.name, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: C.slate900)),
                if (d.phone != null) Text('📞 ${d.phone}', style: const TextStyle(color: C.slate600)),
                if (d.vehicle?.isNotEmpty == true) Text(d.vehicle!, style: const TextStyle(fontSize: 12, color: C.slate400)),
              ]),
            ),
            if (d.phone != null)
              Pressable(
                onTap: () => launchUrl(Uri(scheme: 'tel', path: d.phone!.replaceAll(RegExp(r'[^+\d]'), ''))),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
                  decoration: BoxDecoration(color: C.green600, borderRadius: BorderRadius.circular(999), boxShadow: Shadows.soft),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.call, color: Colors.white, size: 18),
                    const SizedBox(width: 6),
                    Text(context.t('Call'), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
                  ]),
                ),
              ),
          ]),
        ),
        if (d.lat != null && d.lng != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(44), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              onPressed: () => launchUrl(Uri.parse('https://www.google.com/maps/search/?api=1&query=${d.lat},${d.lng}'), mode: LaunchMode.externalApplication),
              icon: const Icon(Icons.map_outlined, color: C.brand600),
              label: Text(context.t('Driver location'), style: const TextStyle(color: C.brand700, fontWeight: FontWeight.w700)),
            ),
          ),
      ]),
    );
  }
}

class _Items extends StatelessWidget {
  final Map<String, dynamic> order;
  const _Items({required this.order});
  @override
  Widget build(BuildContext context) {
    final i18n = context.i18n;
    final items = (order['order_items'] as List?) ?? [];
    Widget row(String a, int v, {bool bold = false}) => Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Row(children: [
            Expanded(child: Text(a, style: TextStyle(color: bold ? C.slate900 : C.slate600, fontWeight: bold ? FontWeight.w900 : FontWeight.w500))),
            Text(formatPrice(v), style: TextStyle(color: bold ? C.slate900 : C.slate600, fontWeight: bold ? FontWeight.w900 : FontWeight.w500)),
          ]),
        );
    return CardBox(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(context.t('Items'), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
        const SizedBox(height: 8),
        for (final oi in items) ...[
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(child: Text('${oi['quantity']}× ${(oi['menu_items'] as Map?)?['name'] ?? ''}', style: const TextStyle(fontWeight: FontWeight.w600))),
            Text(formatPrice((oi['quantity'] as num).toInt() * (oi['unit_price_cents'] as num).toInt())),
          ]),
          for (final opt in ((oi['order_item_options'] as List?) ?? []))
            Padding(
              padding: const EdgeInsets.only(left: 18, top: 2),
              child: Text(
                describeSelection(SelectionMode.values.byName(opt['mode']), opt['option_name'], i18n) +
                    ((opt['price_cents'] as num) > 0 ? '  (+${formatPrice((opt['price_cents'] as num).toInt())})' : ''),
                style: TextStyle(
                  fontSize: 12,
                  color: opt['mode'] == 'remove' ? C.red600 : opt['mode'] == 'extra' ? C.brand700 : C.slate500,
                  fontWeight: opt['mode'] == 'add' ? FontWeight.w400 : FontWeight.w700,
                ),
              ),
            ),
          if (oi['notes'] != null)
            Padding(
              padding: const EdgeInsets.only(left: 18, top: 2),
              child: Text('“${oi['notes']}”', style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic, color: C.slate500)),
            ),
          const SizedBox(height: 8),
        ],
        const Divider(color: C.slate200),
        row(context.t('Subtotal'), (order['subtotal_cents'] as num).toInt()),
        row(context.t('Delivery fee'), (order['delivery_fee_cents'] as num).toInt()),
        row(context.t('Total'), (order['total_cents'] as num).toInt(), bold: true),
      ]),
    );
  }
}
