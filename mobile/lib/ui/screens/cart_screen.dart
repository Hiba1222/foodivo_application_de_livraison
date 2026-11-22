import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../core/money.dart';
import '../../core/theme.dart';
import '../../data/models.dart';
import '../../state/cart.dart';
import '../shell.dart';
import '../widgets.dart';
import 'checkout_screen.dart';

class CartScreen extends StatelessWidget {
  const CartScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<Cart>();
    final i18n = context.i18n;
    if (cart.isEmpty) {
      return SafeArea(
        child: EmptyState(
          emoji: '🛒',
          title: context.t('Your cart is empty'),
          subtitle: context.t("Looks like you haven't added anything yet."),
          action: PrimaryButton(context.t('Browse restaurants'), expand: false, onPressed: () => goToTab(context, 0), trailing: const Icon(Icons.arrow_forward, color: Colors.white, size: 18)),
        ),
      );
    }
    return SafeArea(
      child: ListView(padding: const EdgeInsets.fromLTRB(16, 12, 16, 24), children: [
        Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(context.t('Your cart'), style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: C.slate900)),
              Text.rich(TextSpan(style: const TextStyle(color: C.slate500), children: [
                TextSpan(text: '${context.t(cart.itemCount > 1 ? '{n} items from' : '{n} item from', {'n': cart.itemCount})} '),
                TextSpan(text: cart.restaurantName, style: const TextStyle(fontWeight: FontWeight.w700, color: C.slate700)),
              ])),
            ]),
          ),
          TextButton(onPressed: cart.clear, child: Text(context.t('Clear cart'), style: const TextStyle(color: C.red600, fontWeight: FontWeight.w700))),
        ]),
        const SizedBox(height: 14),
        for (var i = 0; i < cart.lines.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: FadeInUp(
              index: i,
              child: Dismissible(
                key: ValueKey(cart.lines[i].lineId),
                direction: DismissDirection.endToStart,
                onDismissed: (_) => cart.setQuantity(cart.lines[i].lineId, 0),
                background: Container(
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.only(right: 24),
                  decoration: BoxDecoration(color: C.red600, borderRadius: BorderRadius.circular(18)),
                  child: const Icon(Icons.delete_outline, color: Colors.white),
                ),
                child: _CartLineCard(line: cart.lines[i]),
              ),
            ),
          ),
        const SizedBox(height: 4),
        CardBox(
          child: Column(children: [
            _row(context.t('Subtotal'), formatPrice(cart.subtotal)),
            const SizedBox(height: 6),
            _row('🛵 ${context.t('Delivery fee')}', formatPrice(deliveryFee)),
            const Padding(padding: EdgeInsets.symmetric(vertical: 10), child: Divider(color: C.slate200)),
            _row(context.t('Total'), formatPrice(cart.subtotal + deliveryFee), bold: true),
          ]),
        ),
        const SizedBox(height: 16),
        PrimaryButton(
          i18n.t('Proceed to checkout'),
          trailing: const Icon(Icons.arrow_forward, color: Colors.white, size: 18),
          onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const CheckoutScreen())),
        ),
      ]),
    );
  }

  Widget _row(String a, String b, {bool bold = false}) => Row(children: [
        Expanded(child: Text(a, style: TextStyle(color: bold ? C.slate900 : C.slate600, fontWeight: bold ? FontWeight.w900 : FontWeight.w500, fontSize: bold ? 18 : 14))),
        Text(b, style: TextStyle(color: bold ? C.slate900 : C.slate600, fontWeight: bold ? FontWeight.w900 : FontWeight.w500, fontSize: bold ? 18 : 14)),
      ]);
}

class _CartLineCard extends StatelessWidget {
  final CartLine line;
  const _CartLineCard({required this.line});
  @override
  Widget build(BuildContext context) {
    final cart = context.read<Cart>();
    final i18n = context.i18n;
    return CardBox(
      padding: const EdgeInsets.all(12),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (line.imageUrl != null) ...[
          ClipRRect(borderRadius: BorderRadius.circular(12), child: SizedBox(width: 64, height: 64, child: NetImage(line.imageUrl))),
          const SizedBox(width: 12),
        ],
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(line.name, style: const TextStyle(fontWeight: FontWeight.w800, color: C.slate900)),
            if (line.summary.isNotEmpty) ...[
              const SizedBox(height: 6),
              Wrap(spacing: 4, runSpacing: 4, children: [
                for (final s in line.summary) Pill(describeSelection(s.mode, s.optionName, i18n), fontSize: 10),
              ]),
            ],
            if (line.notes.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text('“${line.notes}”', style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic, color: C.slate400)),
            ],
            const SizedBox(height: 6),
            Text.rich(TextSpan(children: [
              TextSpan(text: formatPrice(line.unitPriceCents * line.quantity), style: const TextStyle(fontWeight: FontWeight.w900, color: C.slate900)),
              if (line.quantity > 1)
                TextSpan(text: '  ·  ${context.t('{price} each', {'price': formatPrice(line.unitPriceCents)})}', style: const TextStyle(color: C.slate400, fontSize: 12)),
            ])),
          ]),
        ),
        Container(
          decoration: BoxDecoration(color: C.slate100, borderRadius: BorderRadius.circular(999)),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            IconButton(
              visualDensity: VisualDensity.compact,
              onPressed: () => cart.setQuantity(line.lineId, line.quantity - 1),
              icon: Icon(line.quantity == 1 ? Icons.delete_outline : Icons.remove, size: 18),
              tooltip: line.quantity == 1 ? context.t('Remove') : context.t('Decrease quantity'),
            ),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              transitionBuilder: (c, a) => ScaleTransition(scale: a, child: c),
              child: Text('${line.quantity}', key: ValueKey(line.quantity), style: const TextStyle(fontWeight: FontWeight.w800)),
            ),
            IconButton(
              visualDensity: VisualDensity.compact,
              onPressed: () => cart.setQuantity(line.lineId, line.quantity + 1),
              icon: const Icon(Icons.add, size: 18),
              tooltip: context.t('Increase quantity'),
            ),
          ]),
        ),
      ]),
    );
  }
}
