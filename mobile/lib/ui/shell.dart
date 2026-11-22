import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../core/theme.dart';
import '../state/cart.dart';
import 'screens/browse_screen.dart';
import 'screens/cart_screen.dart';
import 'screens/orders_screen.dart';
import 'screens/settings_screen.dart';
import 'widgets.dart';

/// Current bottom tab (0 Browse · 1 Cart · 2 My orders · 3 Settings).
/// Pushed pages (restaurant, checkout…) switch tabs with `goToTab(context, 1)`.
final shellTab = ValueNotifier<int>(0);

/// Pops back to the shell and selects [index].
void goToTab(BuildContext context, int index) {
  Navigator.of(context).popUntil((r) => r.isFirst);
  shellTab.value = index;
}

/// Bottom-tab shell: Browse · Cart · My orders · Settings (same as the website's client nav).
class AppShell extends StatefulWidget {
  const AppShell({super.key});
  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _index = 0;
  final _ordersKey = GlobalKey<OrdersScreenState>();

  @override
  void initState() {
    super.initState();
    shellTab.value = 0;
    shellTab.addListener(_onTab);
  }

  @override
  void dispose() {
    shellTab.removeListener(_onTab);
    super.dispose();
  }

  void _onTab() {
    setState(() => _index = shellTab.value);
    if (_index == 2) _ordersKey.currentState?.refresh();
  }

  void goTo(int index) {
    if (shellTab.value == index) {
      _onTab();
    } else {
      shellTab.value = index;
    }
  }

  @override
  Widget build(BuildContext context) {
    final tabs = [
      const BrowseScreen(),
      const CartScreen(),
      OrdersScreen(key: _ordersKey),
      const SettingsScreen(),
    ];
    return PopScope(
      // Android back button: go back to Browse before leaving the app.
      canPop: _index == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) goTo(0);
      },
      child: Scaffold(
        body: IndexedStack(index: _index, children: tabs),
        bottomNavigationBar: _BottomNav(index: _index, onTap: goTo),
      ),
    );
  }
}

class _BottomNav extends StatelessWidget {
  final int index;
  final ValueChanged<int> onTap;
  const _BottomNav({required this.index, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final items = [
      (Icons.search_rounded, 'Browse'),
      (Icons.shopping_cart_outlined, 'Cart'),
      (Icons.delivery_dining_outlined, 'My orders'),
      (Icons.settings_outlined, 'Settings'),
    ];
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: C.slate200)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 64,
          child: Row(
            children: [
              for (var i = 0; i < items.length; i++)
                Expanded(
                  child: Pressable(
                    onTap: () => onTap(i),
                    scale: 0.92,
                    child: _NavItem(icon: items[i].$1, label: context.t(items[i].$2), active: i == index, showCartBadge: i == 1),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active, showCartBadge;
  const _NavItem({required this.icon, required this.label, required this.active, required this.showCartBadge});

  @override
  Widget build(BuildContext context) {
    final color = active ? C.brand600 : C.slate400;
    return Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
        width: active ? 32 : 0,
        height: 3,
        margin: const EdgeInsets.only(bottom: 6),
        decoration: BoxDecoration(color: C.brand600, borderRadius: BorderRadius.circular(9)),
      ),
      AnimatedScale(
        scale: active ? 1.12 : 1,
        duration: const Duration(milliseconds: 250),
        child: Stack(clipBehavior: Clip.none, children: [
          Icon(icon, color: color, size: 24),
          if (showCartBadge) const Positioned(right: -12, top: -8, child: _CartBadge()),
        ]),
      ),
      const SizedBox(height: 3),
      Text(label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color)),
    ]);
  }
}

/// Cart count that pops every time something is added.
class _CartBadge extends StatelessWidget {
  const _CartBadge();
  @override
  Widget build(BuildContext context) {
    final cart = context.watch<Cart>();
    if (cart.itemCount == 0) return const SizedBox.shrink();
    return TweenAnimationBuilder<double>(
      key: ValueKey(cart.addTick),
      tween: Tween(begin: 1.4, end: 1),
      duration: const Duration(milliseconds: 450),
      curve: Curves.elasticOut,
      builder: (_, v, c) => Transform.scale(scale: v, child: c),
      child: Container(
        constraints: const BoxConstraints(minWidth: 20),
        height: 20,
        padding: const EdgeInsets.symmetric(horizontal: 5),
        alignment: Alignment.center,
        decoration: BoxDecoration(color: C.brand600, borderRadius: BorderRadius.circular(999), boxShadow: Shadows.glow),
        child: Text('${cart.itemCount}', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800)),
      ),
    );
  }
}
