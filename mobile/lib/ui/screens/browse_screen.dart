import 'package:material_ui/material_ui.dart';

import '../../core/money.dart';
import '../../core/theme.dart';
import '../../data/models.dart';
import '../../data/repo.dart';
import '../widgets.dart';
import 'restaurant_screen.dart';

class BrowseScreen extends StatefulWidget {
  const BrowseScreen({super.key});
  @override
  State<BrowseScreen> createState() => _BrowseScreenState();
}

class _Deal {
  final int count, bestPercent;
  const _Deal(this.count, this.bestPercent);
}

class _BrowseScreenState extends State<BrowseScreen> {
  List<Restaurant>? _restaurants;
  List<MenuItem> _deals = [];
  String? _error;
  String _query = '';
  String? _cuisine;
  bool _openOnly = false, _dealsOnly = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final results = await Future.wait([Repo.restaurants(), Repo.dealItems()]);
      final rs = results[0] as List<Restaurant>;
      final ids = rs.map((r) => r.id).toSet();
      setState(() {
        _restaurants = rs;
        _deals = (results[1] as List<MenuItem>).where((d) => ids.contains(d.restaurantId)).toList();
        _error = null;
      });
    } catch (e) {
      setState(() => _error = errorMessage(e));
    }
  }

  Map<String, _Deal> get _dealsByRestaurant {
    final m = <String, _Deal>{};
    for (final d in _deals) {
      final cur = m[d.restaurantId] ?? const _Deal(0, 0);
      m[d.restaurantId] = _Deal(cur.count + 1, cur.bestPercent > d.offer!.percentOff ? cur.bestPercent : d.offer!.percentOff);
    }
    return m;
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null && _restaurants == null) {
      return EmptyState(
        emoji: '📡',
        title: context.t(_error!),
        action: PrimaryButton(context.t('Retry'), expand: false, onPressed: () {
          setState(() => _error = null);
          _load();
        }),
      );
    }
    final rs = _restaurants;
    final deals = _dealsByRestaurant;
    final cuisines = {for (final r in rs ?? <Restaurant>[]) if (r.cuisineType?.isNotEmpty == true) r.cuisineType!}.toList();
    final q = _query.trim().toLowerCase();
    final filtered = (rs ?? []).where((r) {
      if (q.isNotEmpty && !'${r.name} ${r.cuisineType ?? ''} ${r.description ?? ''}'.toLowerCase().contains(q)) return false;
      if (_cuisine != null && r.cuisineType != _cuisine) return false;
      if (_openOnly && !r.isOpen) return false;
      if (_dealsOnly && !deals.containsKey(r.id)) return false;
      return true;
    }).toList();

    return RefreshIndicator(
      color: C.brand600,
      onRefresh: _load,
      child: CustomScrollView(slivers: [
        SliverToBoxAdapter(
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Row(children: [const Logo(height: 44), const Spacer(), const LanguageSwitcher()]),
            ),
          ),
        ),
        const SliverToBoxAdapter(child: Padding(padding: EdgeInsets.fromLTRB(16, 12, 16, 0), child: _Hero())),
        if (_deals.isNotEmpty) ...[
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 22, 16, 10),
              child: Row(children: [
                Text('🔥 ${context.t('Hot deals')}', style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w900, color: C.slate900)),
                const Spacer(),
                Text(context.t('Swipe for more →'), style: const TextStyle(fontSize: 12, color: C.slate400, fontWeight: FontWeight.w600)),
              ]),
            ),
          ),
          SliverToBoxAdapter(
            child: SizedBox(
              height: 236,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                itemCount: _deals.length.clamp(0, 12),
                separatorBuilder: (_, _) => const SizedBox(width: 14),
                itemBuilder: (_, i) {
                  final d = _deals[i];
                  final r = rs!.firstWhere((x) => x.id == d.restaurantId);
                  return FadeInUp(index: i, child: _DealCard(item: d, restaurant: r));
                },
              ),
            ),
          ),
        ],
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
            child: Container(
              decoration: BoxDecoration(borderRadius: BorderRadius.circular(16), boxShadow: Shadows.soft),
              child: TextField(
                onChanged: (v) => setState(() => _query = v),
                decoration: InputDecoration(
                  hintText: context.t('Search restaurants, cuisines…'),
                  prefixIcon: const Icon(Icons.search, color: C.slate400),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: C.slate200)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: C.slate200)),
                ),
              ),
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: SizedBox(
            height: 54,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              children: [
                _Chip(label: context.t('All'), active: _cuisine == null, onTap: () => setState(() => _cuisine = null)),
                for (final c in cuisines)
                  _Chip(label: c, active: _cuisine == c, onTap: () => setState(() => _cuisine = _cuisine == c ? null : c)),
                _Chip(
                  label: context.t('Open now'),
                  leading: const LiveDot(size: 7),
                  active: _openOnly,
                  onTap: () => setState(() => _openOnly = !_openOnly),
                ),
                if (deals.isNotEmpty)
                  _Chip(label: '🔥 ${context.t('Deals')}', active: _dealsOnly, hot: true, onTap: () => setState(() => _dealsOnly = !_dealsOnly)),
              ],
            ),
          ),
        ),
        if (rs == null)
          const SliverFillRemaining(child: Center(child: CircularProgressIndicator(color: C.brand600)))
        else if (filtered.isEmpty)
          SliverFillRemaining(
            hasScrollBody: false,
            child: EmptyState(
              emoji: '🔍',
              title: rs.isEmpty ? context.t('No restaurants available yet.') : context.t('No restaurants match your search.'),
            ),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
            sliver: SliverList.separated(
              itemCount: filtered.length,
              separatorBuilder: (_, _) => const SizedBox(height: 16),
              itemBuilder: (_, i) => FadeInUp(
                key: ValueKey('${filtered[i].id}|$q|$_cuisine|$_openOnly|$_dealsOnly'),
                index: i,
                child: _RestaurantCard(restaurant: filtered[i], deal: deals[filtered[i].id]),
              ),
            ),
          ),
      ]),
    );
  }
}

class _Hero extends StatefulWidget {
  const _Hero();
  @override
  State<_Hero> createState() => _HeroState();
}

class _HeroState extends State<_Hero> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: const Duration(seconds: 6))..repeat(reverse: true);
  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(gradient: C.brandGradient, borderRadius: BorderRadius.circular(26), boxShadow: Shadows.glow),
      child: AnimatedBuilder(
        animation: _c,
        builder: (_, child) {
          final v = Curves.easeInOut.transform(_c.value);
          return Stack(children: [
            Positioned(
              right: -30 + 12 * v,
              top: -40 - 10 * v,
              child: Container(width: 150, height: 150, decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withValues(alpha: 0.15))),
            ),
            Positioned(right: 18, top: 26 - 8 * v, child: const Text('🍕', style: TextStyle(fontSize: 46))),
            Positioned(right: 64, bottom: 14 + 8 * v, child: const Text('🌮', style: TextStyle(fontSize: 38))),
            child!,
          ]);
        },
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 24, 110, 24),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('${context.t('Hungry?')} 👋', style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            Text(context.t('What are you craving today?'),
                style: const TextStyle(color: Colors.white, fontSize: 22, height: 1.15, fontWeight: FontWeight.w900)),
            const SizedBox(height: 8),
            Text(context.t('Order from the best restaurants near you. Delivered hot, fast.'),
                style: TextStyle(color: Colors.white.withValues(alpha: 0.88), fontSize: 13)),
          ]),
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final bool active, hot;
  final Widget? leading;
  final VoidCallback onTap;
  const _Chip({required this.label, required this.active, required this.onTap, this.hot = false, this.leading});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Pressable(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          decoration: BoxDecoration(
            color: active && !hot ? C.slate900 : Colors.white,
            gradient: active && hot ? const LinearGradient(colors: [C.rose600, C.amber500]) : null,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: active ? Colors.transparent : C.slate200),
            boxShadow: active ? Shadows.soft : null,
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            if (leading != null) ...[leading!, const SizedBox(width: 6)],
            Text(label, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: active ? Colors.white : C.slate600)),
          ]),
        ),
      ),
    );
  }
}

class _DealCard extends StatelessWidget {
  final MenuItem item;
  final Restaurant restaurant;
  const _DealCard({required this.item, required this.restaurant});
  @override
  Widget build(BuildContext context) {
    final o = item.offer!;
    return Pressable(
      onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => RestaurantScreen(restaurantId: restaurant.id))),
      child: OfferGlow(
        child: Container(
          width: 200,
          color: Colors.white,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            SizedBox(
              height: 118,
              width: double.infinity,
              child: Stack(fit: StackFit.expand, children: [
                NetImage(item.imageUrl),
                const DecoratedBox(
                  decoration: BoxDecoration(gradient: LinearGradient(colors: [Colors.transparent, Color(0x99000000)], begin: Alignment.center, end: Alignment.bottomCenter)),
                ),
                Positioned(
                  right: 8,
                  top: 8,
                  child: o.percentOff > 0
                      ? DiscountBadge(o.percentOff, size: 46)
                      : Pill('⭐ ${context.t('Special offer')}', bg: C.amber400, fg: C.amber950),
                ),
                Positioned(
                  left: 10,
                  right: 10,
                  bottom: 8,
                  child: Text(restaurant.name,
                      maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 12)),
                ),
              ]),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(item.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w900, color: C.slate900)),
                if (o.label != null)
                  Text(o.label!.toUpperCase(),
                      maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 10, color: C.amber500, fontWeight: FontWeight.w900, letterSpacing: 0.6)),
                const SizedBox(height: 4),
                Row(children: [
                  Text(formatPrice(o.priceCents),
                      style: TextStyle(fontWeight: FontWeight.w900, color: o.percentOff > 0 ? C.rose600 : C.slate900)),
                  if (o.percentOff > 0) ...[
                    const SizedBox(width: 6),
                    Text(formatPrice(o.originalCents),
                        style: const TextStyle(fontSize: 11, color: C.slate400, decoration: TextDecoration.lineThrough)),
                  ],
                ]),
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}

class _RestaurantCard extends StatelessWidget {
  final Restaurant restaurant;
  final _Deal? deal;
  const _RestaurantCard({required this.restaurant, this.deal});
  @override
  Widget build(BuildContext context) {
    final r = restaurant;
    return Pressable(
      onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => RestaurantScreen(restaurantId: r.id))),
      child: Opacity(
        opacity: r.isOpen ? 1 : 0.7,
        child: Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: C.slate200.withValues(alpha: 0.7)),
            boxShadow: Shadows.soft,
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            AspectRatio(
              aspectRatio: 16 / 9,
              child: Stack(fit: StackFit.expand, children: [
                Hero(tag: 'cover-${r.id}', child: NetImage(r.coverUrl)),
                Positioned(
                  left: 12,
                  top: 12,
                  child: Pill(
                    r.isOpen ? context.t('Open') : context.t('Closed'),
                    bg: r.isOpen ? Colors.white.withValues(alpha: 0.92) : C.slate900.withValues(alpha: 0.7),
                    fg: r.isOpen ? C.green700 : Colors.white,
                    leading: r.isOpen ? const LiveDot(size: 7) : null,
                    fontSize: 12,
                  ),
                ),
                if (deal != null)
                  Positioned(
                    right: 12,
                    top: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(gradient: const LinearGradient(colors: [C.rose600, C.amber500]), borderRadius: BorderRadius.circular(999), boxShadow: Shadows.lift),
                      child: Text(
                        '🔥 ${deal!.bestPercent > 0 ? context.t('Up to -{p}%', {'p': deal!.bestPercent}) : context.t(deal!.count > 1 ? '{n} offers' : '{n} offer', {'n': deal!.count})}',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 12),
                      ),
                    ),
                  ),
                if (r.prepMinutes != null)
                  Positioned(
                    right: 12,
                    bottom: 12,
                    child: Pill('⏱ ${r.prepMinutes} min', bg: Colors.white.withValues(alpha: 0.92), fg: C.slate800, fontSize: 12),
                  ),
              ]),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  if (r.logoUrl != null) ...[
                    Container(
                      width: 44,
                      height: 44,
                      clipBehavior: Clip.antiAlias,
                      decoration: BoxDecoration(borderRadius: BorderRadius.circular(14), border: Border.all(color: Colors.white, width: 3), boxShadow: Shadows.soft),
                      child: NetImage(r.logoUrl),
                    ),
                    const SizedBox(width: 12),
                  ],
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(r.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: C.slate900)),
                      if (r.cuisineType != null)
                        Text(r.cuisineType!, style: const TextStyle(fontSize: 12, color: C.brand600, fontWeight: FontWeight.w600)),
                    ]),
                  ),
                  Container(
                    width: 34,
                    height: 34,
                    alignment: Alignment.center,
                    decoration: const BoxDecoration(color: C.slate100, shape: BoxShape.circle),
                    child: const Icon(Icons.arrow_forward, size: 18, color: C.slate500),
                  ),
                ]),
                if (r.description?.isNotEmpty == true) ...[
                  const SizedBox(height: 10),
                  Text(r.description!, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: C.slate600, fontSize: 13)),
                ],
                if (r.address?.isNotEmpty == true) ...[
                  const SizedBox(height: 8),
                  Text('📍 ${r.address}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: C.slate400, fontSize: 12)),
                ],
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}
