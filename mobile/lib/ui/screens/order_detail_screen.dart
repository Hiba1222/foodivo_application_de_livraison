import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/money.dart';
import '../../core/order_codes.dart';
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
  Map<String, dynamic>? _review;
  bool _loaded = false;
  bool _cancelling = false;
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
      Map<String, dynamic>? rv;
      if (o != null && o['status'] == 'delivered') {
        rv = await Repo.getReview(widget.orderId);
      }
      if (mounted) {
        setState(() {
          _order = o;
          _history = h;
          _driver = d;
          _review = rv;
          _loaded = true;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loaded = true);
    }
  }

  Future<void> _cancelOrder() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(context.t('Cancel order')),
        content: Text(context.t('Cancel this order? This cannot be undone.')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(context.t('No'))),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(context.t('Yes, cancel'), style: const TextStyle(color: C.red600)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() => _cancelling = true);
    try {
      await Repo.cancelOrder(widget.orderId);
      await _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(errorMessage(e))));
      }
    } finally {
      if (mounted) setState(() => _cancelling = false);
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
                    if (_driver != null) ...[
                      const SizedBox(height: 14),
                      FadeInUp(index: 1, child: _DriverCard(driver: _driver!, pickedUp: o['status'] == 'picked_up')),
                      const SizedBox(height: 10),
                      FadeInUp(
                        index: 2,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          decoration: BoxDecoration(color: const Color(0xFFF0FDF4), borderRadius: BorderRadius.circular(14), border: Border.all(color: const Color(0xFFBBF7D0))),
                          child: Row(children: [
                            const Icon(Icons.lock_outlined, size: 20, color: Color(0xFF16A34A)),
                            const SizedBox(width: 10),
                            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text(context.t('Delivery code'), style: const TextStyle(fontSize: 11, color: Color(0xFF15803D), fontWeight: FontWeight.w600)),
                              Text(deliveryCode(o['id']), style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: Color(0xFF166534), letterSpacing: 4)),
                            ]),
                            const Spacer(),
                            Flexible(child: Text(context.t('Share this code with your driver to confirm your identity.'), style: const TextStyle(fontSize: 11, color: Color(0xFF16A34A)), textAlign: TextAlign.end)),
                          ]),
                        ),
                      ),
                    ],
                    // Cancel button — only while pending
                    if (o['status'] == 'pending') ...[
                      const SizedBox(height: 14),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton(
                          onPressed: _cancelling ? null : _cancelOrder,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: C.red600,
                            side: const BorderSide(color: C.red600),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: _cancelling
                              ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2, color: C.red600))
                              : Text(context.t('Cancel order'), style: const TextStyle(fontWeight: FontWeight.w600)),
                        ),
                      ),
                    ],
                    // Review section — only after delivery
                    if (o['status'] == 'delivered') ...[
                      const SizedBox(height: 14),
                      _review == null
                          ? _ReviewForm(orderId: widget.orderId, hasDriver: o['driver_id'] != null, onSubmitted: _load)
                          : _ReviewDisplay(review: _review!),
                    ],
                    const SizedBox(height: 14),
                    FadeInUp(index: 3, child: _Items(order: o)),
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

class _ReviewDisplay extends StatelessWidget {
  final Map<String, dynamic> review;
  const _ReviewDisplay({required this.review});
  @override
  Widget build(BuildContext context) {
    final restaurantRating = (review['restaurant_rating'] as num?)?.toInt() ?? 0;
    final driverRating = (review['driver_rating'] as num?)?.toInt();
    final comment = review['comment'] as String?;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBEB),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFFDE68A)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(context.t('Your review'), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFFB45309))),
        const SizedBox(height: 6),
        Row(children: [
          Text('🍽️ ${'⭐' * restaurantRating}', style: const TextStyle(fontSize: 14)),
          if (driverRating != null) ...[
            const SizedBox(width: 12),
            Text('🛵 ${'⭐' * driverRating}', style: const TextStyle(fontSize: 14)),
          ],
        ]),
        if (comment != null && comment.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(comment, style: const TextStyle(fontSize: 13, color: C.slate600)),
        ],
      ]),
    );
  }
}

class _ReviewForm extends StatefulWidget {
  final String orderId;
  final bool hasDriver;
  final VoidCallback onSubmitted;
  const _ReviewForm({required this.orderId, required this.hasDriver, required this.onSubmitted});
  @override
  State<_ReviewForm> createState() => _ReviewFormState();
}

class _ReviewFormState extends State<_ReviewForm> {
  int _restaurantRating = 0;
  int _driverRating = 0;
  final _commentCtrl = TextEditingController();
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _commentCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_restaurantRating == 0) {
      setState(() => _error = context.t('Please rate the restaurant.'));
      return;
    }
    setState(() { _submitting = true; _error = null; });
    try {
      await Repo.submitReview(
        orderId: widget.orderId,
        restaurantRating: _restaurantRating,
        driverRating: widget.hasDriver && _driverRating > 0 ? _driverRating : null,
        comment: _commentCtrl.text.trim().isEmpty ? null : _commentCtrl.text.trim(),
      );
      widget.onSubmitted();
    } catch (e) {
      if (mounted) setState(() => _error = errorMessage(e));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Widget _stars(int value, void Function(int) onTap) {
    return Row(
      children: List.generate(5, (i) => GestureDetector(
        onTap: () => onTap(i + 1),
        child: Padding(
          padding: const EdgeInsets.only(right: 2),
          child: Text(i < value ? '⭐' : '☆', style: const TextStyle(fontSize: 24)),
        ),
      )),
    );
  }

  @override
  Widget build(BuildContext context) {
    return CardBox(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(context.t('Rate your order'), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
        const SizedBox(height: 12),
        Text(context.t('Restaurant'), style: const TextStyle(fontSize: 12, color: C.slate500)),
        const SizedBox(height: 4),
        _stars(_restaurantRating, (v) => setState(() => _restaurantRating = v)),
        if (widget.hasDriver) ...[
          const SizedBox(height: 10),
          Text(context.t('Driver'), style: const TextStyle(fontSize: 12, color: C.slate500)),
          const SizedBox(height: 4),
          _stars(_driverRating, (v) => setState(() => _driverRating = v)),
        ],
        const SizedBox(height: 10),
        TextField(
          controller: _commentCtrl,
          maxLines: 2,
          maxLength: 500,
          decoration: InputDecoration(
            hintText: context.t('Leave a comment (optional)'),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: C.slate300)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            counterText: '',
          ),
        ),
        if (_error != null) ...[
          const SizedBox(height: 6),
          Text(_error!, style: const TextStyle(color: C.red600, fontSize: 13)),
        ],
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _submitting ? null : _submit,
            style: ElevatedButton.styleFrom(
              backgroundColor: C.brand600,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: _submitting
                ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : Text(context.t('Submit review'), style: const TextStyle(fontWeight: FontWeight.w700)),
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
