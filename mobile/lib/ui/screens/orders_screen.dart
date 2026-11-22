import 'dart:async';

import 'package:material_ui/material_ui.dart';

import '../../core/money.dart';
import '../../core/theme.dart';
import '../../data/models.dart';
import '../../data/repo.dart';
import '../shell.dart';
import '../widgets.dart';
import 'order_detail_screen.dart';

class OrdersScreen extends StatefulWidget {
  const OrdersScreen({super.key});
  @override
  State<OrdersScreen> createState() => OrdersScreenState();
}

class OrdersScreenState extends State<OrdersScreen> {
  List<OrderSummary>? _orders;
  String? _error;
  StreamSubscription? _live;

  @override
  void initState() {
    super.initState();
    refresh();
    // Live updates: any change to my orders reloads the list (same as the website's RealtimeRefresher).
    _live = sb.from('orders').stream(primaryKey: ['id']).eq('client_id', sb.auth.currentUser!.id).listen((_) => refresh());
  }

  @override
  void dispose() {
    _live?.cancel();
    super.dispose();
  }

  Future<void> refresh() async {
    try {
      final o = await Repo.myOrders();
      if (mounted) setState(() => (_orders = o, _error = null));
    } catch (e) {
      if (mounted) setState(() => _error = errorMessage(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final orders = _orders;
    return SafeArea(
      child: RefreshIndicator(
        color: C.brand600,
        onRefresh: refresh,
        child: ListView(padding: const EdgeInsets.fromLTRB(16, 12, 16, 24), children: [
          Text(context.t('My orders'), style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: C.slate900)),
          Text(context.t('Updates live as your order moves along.'), style: const TextStyle(color: C.slate500)),
          const SizedBox(height: 16),
          if (orders == null && _error == null)
            const Padding(padding: EdgeInsets.all(40), child: Center(child: CircularProgressIndicator(color: C.brand600)))
          else if (_error != null && orders == null)
            EmptyState(emoji: '📡', title: context.t(_error!), action: PrimaryButton(context.t('Retry'), expand: false, onPressed: refresh))
          else if (orders!.isEmpty)
            EmptyState(
              emoji: '🧾',
              title: context.t('No orders yet'),
              action: PrimaryButton(context.t('Find something tasty'), expand: false, onPressed: () => goToTab(context, 0)),
            )
          else
            for (var i = 0; i < orders.length; i++)
              Padding(padding: const EdgeInsets.only(bottom: 12), child: FadeInUp(index: i, child: _OrderTile(order: orders[i]))),
        ]),
      ),
    );
  }
}

class _OrderTile extends StatelessWidget {
  final OrderSummary order;
  const _OrderTile({required this.order});
  @override
  Widget build(BuildContext context) {
    final (bg, fg) = statusColors(order.status);
    final emoji = order.status == 'delivered'
        ? '✅'
        : order.status == 'picked_up'
            ? '🛵'
            : order.isActive
                ? '🍳'
                : '🧾';
    return Pressable(
      onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => OrderDetailScreen(orderId: order.id))),
      child: CardBox(
        padding: const EdgeInsets.all(14),
        child: Row(children: [
          Container(
            width: 46,
            height: 46,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: order.isActive ? C.brand50 : C.slate100, borderRadius: BorderRadius.circular(14)),
            child: Text(emoji, style: const TextStyle(fontSize: 22)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(order.restaurantName ?? '—', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800, color: C.slate900)),
              Text(context.i18n.dateTime(order.createdAt), style: const TextStyle(fontSize: 12, color: C.slate500)),
              const SizedBox(height: 6),
              Pill(context.i18n.status(order.status), bg: bg, fg: fg, leading: order.isActive ? LiveDot(color: fg, size: 6) : null),
            ]),
          ),
          Text(formatPrice(order.totalCents), style: const TextStyle(fontWeight: FontWeight.w800, color: C.slate900)),
          const SizedBox(width: 4),
          const Icon(Icons.chevron_right, color: C.slate300),
        ]),
      ),
    );
  }
}
