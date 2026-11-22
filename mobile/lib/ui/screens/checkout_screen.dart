import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../core/money.dart';
import '../../core/theme.dart';
import '../../data/models.dart';
import '../../data/repo.dart';
import '../../state/cart.dart';
import '../widgets.dart';
import 'order_detail_screen.dart';
import 'settings_screen.dart';

class CheckoutScreen extends StatefulWidget {
  const CheckoutScreen({super.key});
  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  List<Address>? _addresses;
  String? _selected;
  final _notes = TextEditingController();
  bool _placing = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadAddresses();
  }

  Future<void> _loadAddresses() async {
    try {
      final a = await Repo.addresses();
      setState(() {
        _addresses = a;
        _selected ??= a.isEmpty ? null : a.first.id;
      });
    } catch (e) {
      setState(() => _error = errorMessage(e));
    }
  }

  Future<void> _place() async {
    final cart = context.read<Cart>();
    if (cart.restaurantId == null || _selected == null) return;
    setState(() {
      _placing = true;
      _error = null;
    });
    try {
      final id = await Repo.placeOrder(
        restaurantId: cart.restaurantId!,
        addressId: _selected!,
        items: cart.lines.map((l) => l.toOrderJson()).toList(),
        notes: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
      );
      cart.clear();
      if (!mounted) return;
      showToast(context, context.i18n.t('Order placed!'));
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => OrderDetailScreen(orderId: id)),
        (r) => r.isFirst,
      );
    } catch (e) {
      setState(() {
        _error = errorMessage(e);
        _placing = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<Cart>();
    return Scaffold(
      appBar: AppBar(title: Text(context.t('Checkout'))),
      body: cart.isEmpty
          ? EmptyState(emoji: '🛒', title: context.t('Your cart is empty.'))
          : ListView(padding: const EdgeInsets.all(16), children: [
              Text(context.t('Order from {name}', {'name': cart.restaurantName ?? ''}), style: const TextStyle(color: C.slate500)),
              const SizedBox(height: 16),
              Text(context.t('Delivery address'), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
              const SizedBox(height: 8),
              if (_addresses == null)
                const Padding(padding: EdgeInsets.all(16), child: Center(child: CircularProgressIndicator(color: C.brand600)))
              else
                for (final a in _addresses!)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Pressable(
                      onTap: () => setState(() => _selected = a.id),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: _selected == a.id ? C.brand50 : Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: _selected == a.id ? C.brand500 : C.slate200, width: _selected == a.id ? 2 : 1),
                        ),
                        child: Row(children: [
                          Icon(_selected == a.id ? Icons.radio_button_checked : Icons.radio_button_off, color: _selected == a.id ? C.brand600 : C.slate400),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text(a.label ?? context.t('Address'), style: const TextStyle(fontWeight: FontWeight.w700)),
                              Text(a.line, style: const TextStyle(color: C.slate500, fontSize: 13)),
                            ]),
                          ),
                        ]),
                      ),
                    ),
                  ),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () async {
                    final added = await showAddAddressSheet(context);
                    if (added) {
                      _selected = null;
                      await _loadAddresses();
                    }
                  },
                  icon: const Icon(Icons.add, color: C.brand600),
                  label: Text(context.t('Add a new address'), style: const TextStyle(color: C.brand600, fontWeight: FontWeight.w700)),
                ),
              ),
              const SizedBox(height: 12),
              Text(context.t('Notes for the restaurant (optional)'), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
              const SizedBox(height: 8),
              TextField(controller: _notes, maxLines: 2, decoration: InputDecoration(hintText: context.t('Allergies, delivery instructions…'))),
              const SizedBox(height: 16),
              CardBox(
                child: Column(children: [
                  _row(context.t('Subtotal'), formatPrice(cart.subtotal)),
                  const SizedBox(height: 6),
                  _row(context.t('Delivery fee'), formatPrice(deliveryFee)),
                  const Padding(padding: EdgeInsets.symmetric(vertical: 10), child: Divider(color: C.slate200)),
                  _row(context.t('Total'), formatPrice(cart.subtotal + deliveryFee), bold: true),
                ]),
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(context.t(_error!), style: const TextStyle(color: C.red600, fontWeight: FontWeight.w600)),
              ],
              const SizedBox(height: 16),
              PrimaryButton(
                _placing ? context.t('Placing order…') : context.t('Place order'),
                loading: _placing,
                onPressed: _selected == null ? null : _place,
              ),
              const SizedBox(height: 24),
            ]),
    );
  }

  Widget _row(String a, String b, {bool bold = false}) => Row(children: [
        Expanded(child: Text(a, style: TextStyle(color: bold ? C.slate900 : C.slate600, fontWeight: bold ? FontWeight.w900 : FontWeight.w500, fontSize: bold ? 17 : 14))),
        Text(b, style: TextStyle(color: bold ? C.slate900 : C.slate600, fontWeight: bold ? FontWeight.w900 : FontWeight.w500, fontSize: bold ? 17 : 14)),
      ]);
}
