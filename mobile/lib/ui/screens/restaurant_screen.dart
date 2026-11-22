import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../core/money.dart';
import '../../core/theme.dart';
import '../../data/models.dart';
import '../../data/repo.dart';
import '../../state/cart.dart';
import '../shell.dart';
import '../widgets.dart';
import 'item_sheet.dart';

class RestaurantScreen extends StatefulWidget {
  final String restaurantId;
  const RestaurantScreen({super.key, required this.restaurantId});
  @override
  State<RestaurantScreen> createState() => _RestaurantScreenState();
}

class _Section {
  final String id, name;
  final List<MenuItem> items;
  final GlobalKey key = GlobalKey();
  _Section(this.id, this.name, this.items);
}

class _RestaurantScreenState extends State<RestaurantScreen> {
  Restaurant? _r;
  List<_Section> _sections = [];
  List<MenuItem> _specials = [];
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final (r, cats, items) = await Repo.menu(widget.restaurantId);
      final i = context.i18n;
      final sections = [
        for (final c in cats) _Section(c.id, c.name, items.where((x) => x.categoryId == c.id).toList()),
        _Section('other', cats.isEmpty ? i.t('Menu') : i.t('Other'), items.where((x) => x.categoryId == null).toList()),
      ].where((s) => s.items.isNotEmpty).toList();
      final specials = items.where((x) => x.offer != null).toList()..sort((a, b) => b.offer!.percentOff - a.offer!.percentOff);
      setState(() {
        _r = r;
        _sections = sections;
        _specials = specials;
        _error = null;
      });
    } catch (e) {
      setState(() => _error = errorMessage(e));
    }
  }

  void _openItem(MenuItem item) => showItemSheet(context, restaurant: _r!, item: item);

  @override
  Widget build(BuildContext context) {
    final r = _r;
    if (r == null) {
      return Scaffold(
        appBar: AppBar(),
        body: _error != null
            ? EmptyState(emoji: '🤷', title: context.t('Restaurant not found.'), subtitle: context.t(_error!))
            : const Center(child: CircularProgressIndicator(color: C.brand600)),
      );
    }
    final best = _specials.isEmpty ? 0 : _specials.first.offer!.percentOff;
    return Scaffold(
      body: Stack(children: [
        RefreshIndicator(
          color: C.brand600,
          onRefresh: _load,
          child: CustomScrollView(slivers: [
            SliverAppBar(
              expandedHeight: 250,
              pinned: true,
              stretch: true,
              backgroundColor: Colors.white,
              leading: Padding(
                padding: const EdgeInsets.all(8),
                child: CircleAvatar(
                  backgroundColor: Colors.white.withValues(alpha: 0.92),
                  child: IconButton(icon: const Icon(Icons.arrow_back, color: C.slate800), onPressed: () => Navigator.pop(context)),
                ),
              ),
              flexibleSpace: FlexibleSpaceBar(
                stretchModes: const [StretchMode.zoomBackground],
                background: Stack(fit: StackFit.expand, children: [
                  Hero(tag: 'cover-${r.id}', child: NetImage(r.coverUrl)),
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(colors: [Color(0x0D000000), Color(0x4D000000), Color(0xBF000000)], begin: Alignment.topCenter, end: Alignment.bottomCenter),
                    ),
                  ),
                  Positioned(left: 16, right: 16, bottom: 16, child: _CoverInfo(r)),
                ]),
              ),
            ),
            if (_specials.isNotEmpty) ...[
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 18, 16, 0),
                  child: FadeInUp(child: _SpecialsBanner(bestPercent: best)),
                ),
              ),
              SliverToBoxAdapter(
                child: SizedBox(
                  height: 300,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
                    itemCount: _specials.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 14),
                    itemBuilder: (_, i) => FadeInUp(index: i, child: SpotlightCard(item: _specials[i], onTap: () => _openItem(_specials[i]))),
                  ),
                ),
              ),
            ],
            if (_sections.length > 1)
              SliverPersistentHeader(pinned: true, delegate: _TabsHeader(_sections)),
            for (final s in _sections) ...[
              SliverToBoxAdapter(
                key: s.key,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 20, 16, 10),
                  child: Row(children: [
                    Text(s.name, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w900, color: C.slate900)),
                    const SizedBox(width: 12),
                    const Expanded(child: Divider(color: C.slate200, thickness: 1)),
                  ]),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                sliver: SliverList.separated(
                  itemCount: s.items.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 12),
                  itemBuilder: (_, i) => FadeInUp(index: i, child: MenuItemRow(item: s.items[i], onTap: () => _openItem(s.items[i]))),
                ),
              ),
            ],
            if (_sections.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: EmptyState(emoji: '🍳', title: context.t('No menu items available right now.')),
              ),
            const SliverToBoxAdapter(child: SizedBox(height: 110)),
          ]),
        ),
        const Positioned(left: 16, right: 16, bottom: 16, child: SafeArea(top: false, child: _FloatingCartBar())),
      ]),
    );
  }
}

class _CoverInfo extends StatelessWidget {
  final Restaurant r;
  const _CoverInfo(this.r);
  @override
  Widget build(BuildContext context) {
    return Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
      if (r.logoUrl != null) ...[
        Container(
          width: 64,
          height: 64,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(18), border: Border.all(color: Colors.white, width: 3), boxShadow: Shadows.lift),
          child: NetImage(r.logoUrl),
        ),
        const SizedBox(width: 12),
      ],
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
          Row(children: [
            Flexible(
              child: Text(r.name,
                  maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900)),
            ),
            const SizedBox(width: 8),
            Pill(
              r.isOpen ? context.t('Open now') : context.t('Closed'),
              bg: r.isOpen ? C.green500.withValues(alpha: 0.9) : C.slate900.withValues(alpha: 0.7),
              fg: Colors.white,
              leading: r.isOpen ? const LiveDot(color: Colors.white, size: 6) : null,
            ),
          ]),
          if (r.description?.isNotEmpty == true)
            Text(r.description!, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(color: Colors.white.withValues(alpha: 0.88), fontSize: 13)),
          const SizedBox(height: 6),
          Wrap(spacing: 6, runSpacing: 6, children: [
            if (r.cuisineType != null) Pill(r.cuisineType!, bg: Colors.white24, fg: Colors.white),
            if (r.prepMinutes != null) Pill('⏱ ~${r.prepMinutes} min', bg: Colors.white24, fg: Colors.white),
          ]),
        ]),
      ),
    ]);
  }
}

/// Red→amber "Special offers" banner with a moving shine.
class _SpecialsBanner extends StatefulWidget {
  final int bestPercent;
  const _SpecialsBanner({required this.bestPercent});
  @override
  State<_SpecialsBanner> createState() => _SpecialsBannerState();
}

class _SpecialsBannerState extends State<_SpecialsBanner> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 3200))..repeat();
  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(gradient: C.dealGradient, borderRadius: BorderRadius.circular(18), boxShadow: Shadows.lift),
      child: Stack(children: [
        AnimatedBuilder(
          animation: _c,
          builder: (_, _) {
            final p = (_c.value - 0.55) / 0.45; // shine sweeps during the last 45%
            return Positioned.fill(
              child: FractionalTranslation(
                translation: Offset(p.clamp(-1, 1) * 1.0, 0),
                child: const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: [Colors.transparent, Color(0x55FFFFFF), Colors.transparent], stops: [0.3, 0.5, 0.7]),
                  ),
                ),
              ),
            );
          },
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          child: Row(children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('🔥 ${context.t('Special offers')}', style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900)),
                Text(context.t('Limited-time deals from this restaurant'),
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.88), fontSize: 12, fontWeight: FontWeight.w500)),
              ]),
            ),
            if (widget.bestPercent > 0)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
                child: Text(context.t('Up to -{p}%', {'p': widget.bestPercent}),
                    style: const TextStyle(color: C.rose600, fontWeight: FontWeight.w900)),
              ),
          ]),
        ),
      ]),
    );
  }
}

/// Large glowing card in the Special offers carousel.
class SpotlightCard extends StatelessWidget {
  final MenuItem item;
  final VoidCallback onTap;
  const SpotlightCard({super.key, required this.item, required this.onTap});
  @override
  Widget build(BuildContext context) {
    final o = item.offer!;
    final tag = o.label ?? (o.featured ? '⭐ ${context.t('Special offer')}' : null);
    return Pressable(
      onTap: onTap,
      child: OfferGlow(
        child: Container(
          width: 230,
          color: Colors.white,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            SizedBox(
              height: 140,
              width: double.infinity,
              child: Stack(fit: StackFit.expand, children: [
                NetImage(item.imageUrl),
                const DecoratedBox(
                  decoration: BoxDecoration(gradient: LinearGradient(colors: [Colors.transparent, Color(0x80000000)], begin: Alignment.center, end: Alignment.bottomCenter)),
                ),
                if (o.percentOff > 0) Positioned(right: 10, top: 10, child: DiscountBadge(o.percentOff)),
                Positioned(
                  left: 10,
                  right: 10,
                  bottom: 10,
                  child: Wrap(spacing: 6, runSpacing: 6, children: [
                    if (tag != null) Pill(tag.toUpperCase(), bg: C.amber400, fg: C.amber950, fontSize: 10),
                    if (o.endsAt != null) OfferCountdown(o.endsAt!),
                  ]),
                ),
              ]),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(item.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w900, color: C.slate900)),
                  if (item.description != null)
                    Text(item.description!, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, color: C.slate500)),
                  const Spacer(),
                  Row(children: [
                    _Price(item: item, big: true),
                    const Spacer(),
                    _AddDot(hot: o.percentOff > 0),
                  ]),
                ]),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

/// Normal dish row; on-offer dishes get a rose border, corner ribbon and struck price.
class MenuItemRow extends StatelessWidget {
  final MenuItem item;
  final VoidCallback onTap;
  const MenuItemRow({super.key, required this.item, required this.onTap});
  @override
  Widget build(BuildContext context) {
    final o = item.offer;
    final discounted = o != null && o.percentOff > 0;
    final tag = o?.label != null ? '🔥 ${o!.label}' : (o?.featured == true ? '⭐ ${context.t('Special offer')}' : null);
    return Pressable(
      onTap: onTap,
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: Colors.white,
          gradient: discounted ? const LinearGradient(colors: [Color(0xCCFFF1F2), Colors.white]) : null,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: discounted ? C.rose300 : C.slate200.withValues(alpha: 0.7), width: discounted ? 2 : 1),
          boxShadow: Shadows.soft,
        ),
        child: Stack(children: [
          Padding(
            padding: EdgeInsets.fromLTRB(discounted ? 22 : 14, 14, 14, 14),
            child: Row(children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(item.name, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: C.slate900)),
                  if (tag != null || o?.endsAt != null) ...[
                    const SizedBox(height: 5),
                    Wrap(spacing: 6, runSpacing: 4, children: [
                      if (tag != null) Pill(tag, bg: C.amber100, fg: C.amber800),
                      if (o?.endsAt != null) OfferCountdown(o!.endsAt!),
                    ]),
                  ],
                  if (item.description != null) ...[
                    const SizedBox(height: 4),
                    Text(item.description!, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13, color: C.slate500)),
                  ],
                  const SizedBox(height: 8),
                  Wrap(crossAxisAlignment: WrapCrossAlignment.center, spacing: 8, runSpacing: 4, children: [
                    _Price(item: item),
                    if (item.groups.isNotEmpty) Pill('✨ ${context.t('Customizable')}', bg: C.brand50, fg: C.brand700),
                  ]),
                ]),
              ),
              const SizedBox(width: 12),
              Stack(clipBehavior: Clip.none, children: [
                if (item.imageUrl != null)
                  ClipRRect(borderRadius: BorderRadius.circular(14), child: SizedBox(width: 96, height: 96, child: NetImage(item.imageUrl)))
                else
                  const SizedBox(width: 44, height: 44),
                Positioned(right: -6, bottom: -6, child: _AddDot(hot: discounted)),
              ]),
            ]),
          ),
          if (discounted)
            Positioned(
              left: -30,
              top: 14,
              child: Transform.rotate(
                angle: -0.785,
                child: Container(
                  width: 110,
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(gradient: LinearGradient(colors: [C.rose500, C.red600])),
                  child: Text('-${o.percentOff}%', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 10)),
                ),
              ),
            ),
        ]),
      ),
    );
  }
}

class _Price extends StatelessWidget {
  final MenuItem item;
  final bool big;
  const _Price({required this.item, this.big = false});
  @override
  Widget build(BuildContext context) {
    final o = item.offer;
    final discounted = o != null && o.percentOff > 0;
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Text(formatPrice(item.basePrice),
          style: TextStyle(fontWeight: FontWeight.w900, fontSize: big ? 16 : 14, color: discounted ? C.rose600 : C.slate900)),
      if (discounted) ...[
        const SizedBox(width: 6),
        Text(formatPrice(item.priceCents), style: const TextStyle(fontSize: 11, color: C.slate400, decoration: TextDecoration.lineThrough)),
      ],
    ]);
  }
}

class _AddDot extends StatelessWidget {
  final bool hot;
  const _AddDot({this.hot = false});
  @override
  Widget build(BuildContext context) => Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: hot ? C.rose600 : C.slate900,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 2),
          boxShadow: Shadows.soft,
        ),
        child: const Icon(Icons.add, color: Colors.white, size: 20),
      );
}

class _TabsHeader extends SliverPersistentHeaderDelegate {
  final List<_Section> sections;
  _TabsHeader(this.sections);
  @override
  double get minExtent => 56;
  @override
  double get maxExtent => 56;
  @override
  bool shouldRebuild(covariant _TabsHeader old) => old.sections != sections;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: C.slate50.withValues(alpha: 0.96),
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        children: [
          for (final s in sections)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Pressable(
                onTap: () {
                  final ctx = s.key.currentContext;
                  if (ctx != null) {
                    Scrollable.ensureVisible(ctx, duration: const Duration(milliseconds: 450), curve: Curves.easeOutCubic, alignmentPolicy: ScrollPositionAlignmentPolicy.explicit, alignment: 0.08);
                  }
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(999), border: Border.all(color: C.slate200)),
                  child: Text('${s.name}  ${s.items.length}', style: const TextStyle(fontWeight: FontWeight.w700, color: C.slate600, fontSize: 13)),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Slides up when the cart has items; bounces on every add.
class _FloatingCartBar extends StatelessWidget {
  const _FloatingCartBar();
  @override
  Widget build(BuildContext context) {
    final cart = context.watch<Cart>();
    return AnimatedSlide(
      offset: cart.isEmpty ? const Offset(0, 2) : Offset.zero,
      duration: const Duration(milliseconds: 400),
      curve: const Cubic(0.22, 1, 0.36, 1),
      child: TweenAnimationBuilder<double>(
        key: ValueKey(cart.addTick),
        tween: Tween(begin: 1.06, end: 1),
        duration: const Duration(milliseconds: 450),
        curve: Curves.elasticOut,
        builder: (_, v, c) => Transform.scale(scale: v, child: c),
        child: Pressable(
          onTap: () => goToTab(context, 1),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(color: C.slate900, borderRadius: BorderRadius.circular(18), boxShadow: Shadows.lift),
            child: Row(children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                decoration: BoxDecoration(color: C.brand600, borderRadius: BorderRadius.circular(9)),
                child: Text('${cart.itemCount}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
              ),
              const SizedBox(width: 12),
              Expanded(child: Text(context.t('View cart'), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700))),
              Text(formatPrice(cart.subtotal), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
              const SizedBox(width: 8),
              const Icon(Icons.arrow_forward, color: Colors.white, size: 18),
            ]),
          ),
        ),
      ),
    );
  }
}
