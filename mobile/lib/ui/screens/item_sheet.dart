import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../core/i18n.dart';
import '../../core/money.dart';
import '../../core/theme.dart';
import '../../data/models.dart';
import '../../state/cart.dart';
import '../widgets.dart';

/// Opens the customization sheet; adds to cart (asks first if the cart holds another restaurant).
Future<void> showItemSheet(BuildContext context, {required Restaurant restaurant, required MenuItem item}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    barrierColor: C.slate900.withValues(alpha: 0.6),
    builder: (_) => _ItemSheet(restaurant: restaurant, item: item),
  );
}

enum _Level { remove, regular, extra }

class _ItemSheet extends StatefulWidget {
  final Restaurant restaurant;
  final MenuItem item;
  const _ItemSheet({required this.restaurant, required this.item});
  @override
  State<_ItemSheet> createState() => _ItemSheetState();
}

class _ItemSheetState extends State<_ItemSheet> {
  late final Map<String, List<String>> _chosen = {
    for (final g in widget.item.groups)
      if (g.kind == GroupKind.choice)
        g.id: () {
          final d = g.options.where((o) => o.isDefault).map((o) => o.id).toList();
          return g.maxSelect == null ? d : d.take(g.maxSelect!).toList();
        }(),
  };
  final Map<String, _Level> _levels = {};
  final _notes = TextEditingController();
  final Map<String, GlobalKey> _groupKeys = {};
  int _qty = 1;
  bool _showErrors = false;
  int _shake = 0;

  List<Selection> get _selections => [
        for (final ids in _chosen.values) for (final id in ids) Selection(id, SelectionMode.add),
        for (final e in _levels.entries)
          if (e.value != _Level.regular) Selection(e.key, e.value == _Level.remove ? SelectionMode.remove : SelectionMode.extra),
      ];

  void _toggle(OptionGroup g, String id) {
    setState(() {
      final cur = [...?_chosen[g.id]];
      final on = cur.contains(id);
      if (g.maxSelect == 1) {
        _chosen[g.id] = on ? (g.minSelect == 0 ? [] : cur) : [id];
      } else if (on) {
        _chosen[g.id] = cur..remove(id);
      } else if (g.maxSelect == null || cur.length < g.maxSelect!) {
        _chosen[g.id] = cur..add(id);
      }
    });
  }

  void _add(Evaluation ev) async {
    final i18n = context.read<I18n>();
    if (ev.groupErrors.isNotEmpty) {
      setState(() {
        _showErrors = true;
        _shake++;
      });
      final first = widget.item.groups.firstWhere((g) => ev.groupErrors.containsKey(g.id));
      final ctx = _groupKeys[first.id]?.currentContext;
      if (ctx != null) Scrollable.ensureVisible(ctx, duration: const Duration(milliseconds: 400), alignment: 0.3);
      return;
    }
    final cart = context.read<Cart>();
    if (cart.isOtherRestaurant(widget.restaurant.id)) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (d) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
          title: Text(i18n.t('New order?')),
          content: Text(i18n.t('Your cart has items from another restaurant. Clear it and start a new order?')),
          actions: [
            TextButton(onPressed: () => Navigator.pop(d, false), child: Text(i18n.t('Cancel'))),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: C.brand600),
              onPressed: () => Navigator.pop(d, true),
              child: Text(i18n.t('Clear and continue')),
            ),
          ],
        ),
      );
      if (ok != true) return;
    }
    cart.add(
      restaurantId: widget.restaurant.id,
      restaurantName: widget.restaurant.name,
      item: widget.item,
      unitPriceCents: ev.unitPriceCents,
      selections: _selections,
      summary: ev.priced,
      notes: _notes.text,
      quantity: _qty,
    );
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    Navigator.pop(context);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        duration: const Duration(milliseconds: 2000),
        content: Row(children: [
          const Icon(Icons.check_circle, color: C.green500, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(i18n.t('Added {item} to your cart', {'item': _qty > 1 ? '$_qty × ${widget.item.name}' : widget.item.name})),
          ),
        ]),
      ));
  }

  @override
  Widget build(BuildContext context) {
    final i18n = context.watch<I18n>();
    final item = widget.item;
    final ev = evaluateSelections(item.basePrice, item.groups, _selections, i18n);
    final hasErrors = ev.groupErrors.isNotEmpty;
    final o = item.offer;
    final discounted = o != null && o.percentOff > 0;

    return DraggableScrollableSheet(
      initialChildSize: 0.92,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (_, sheetScroll) => Container(
        decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
        clipBehavior: Clip.antiAlias,
        child: Column(children: [
          Expanded(
            child: ListView(
              controller: sheetScroll,
              padding: EdgeInsets.zero,
              children: [
                Stack(children: [
                  if (item.imageUrl != null)
                    SizedBox(height: 230, width: double.infinity, child: NetImage(item.imageUrl))
                  else
                    const SizedBox(height: 60),
                  Positioned(
                    top: 10,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: Container(width: 42, height: 5, decoration: BoxDecoration(color: Colors.white70, borderRadius: BorderRadius.circular(9))),
                    ),
                  ),
                  Positioned(
                    left: 12,
                    top: 16,
                    child: Pressable(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.92), shape: BoxShape.circle, boxShadow: Shadows.soft),
                        child: const Icon(Icons.close, color: C.slate700),
                      ),
                    ),
                  ),
                ]),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(item.name, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: C.slate900)),
                    const SizedBox(height: 6),
                    Wrap(crossAxisAlignment: WrapCrossAlignment.center, spacing: 8, runSpacing: 6, children: [
                      Text(formatPrice(item.basePrice),
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: discounted ? C.rose600 : C.slate700)),
                      if (discounted) ...[
                        Text(formatPrice(item.priceCents), style: const TextStyle(color: C.slate400, decoration: TextDecoration.lineThrough)),
                        Pill('-${o.percentOff}%', bg: C.rose600, fg: Colors.white, fontSize: 12),
                      ],
                      if (o?.label != null) Pill(o!.label!, bg: C.amber100, fg: C.amber800, fontSize: 12),
                      if (o?.endsAt != null) OfferCountdown(o!.endsAt!),
                    ]),
                    if (item.description != null) ...[
                      const SizedBox(height: 8),
                      Text(item.description!, style: const TextStyle(color: C.slate500)),
                    ],
                  ]),
                ),
                for (final g in item.groups) _groupSection(g, ev, i18n),
                Container(
                  decoration: const BoxDecoration(border: Border(top: BorderSide(color: C.slate100, width: 8))),
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(i18n.t('Special instructions'), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _notes,
                      maxLines: 2,
                      maxLength: 200,
                      decoration: InputDecoration(hintText: i18n.t('e.g. Sauce on the side, well toasted…')),
                    ),
                  ]),
                ),
              ],
            ),
          ),
          _footer(ev, hasErrors, i18n),
        ]),
      ),
    );
  }

  Widget _groupSection(OptionGroup g, Evaluation ev, I18n i18n) {
    final key = _groupKeys.putIfAbsent(g.id, () => GlobalKey());
    final error = ev.groupErrors[g.id];
    final showErr = _showErrors && error != null;
    final header = Container(
      color: showErr ? const Color(0xFFFEF2F2) : Colors.transparent,
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 10),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(g.name, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: C.slate900)),
            Text(showErr ? error : g.ruleText(i18n), style: TextStyle(fontSize: 12, color: showErr ? C.red600 : C.slate500)),
          ]),
        ),
        if (g.kind == GroupKind.choice)
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            transitionBuilder: (c, a) => ScaleTransition(scale: a, child: c),
            child: g.isRequired
                ? (error != null
                    ? Pill(i18n.t('Required'), key: const ValueKey('req'), bg: showErr ? C.red600 : C.slate900, fg: Colors.white)
                    : Pill('✓ ${i18n.t('Done')}', key: const ValueKey('done'), bg: C.green100, fg: C.green700))
                : Pill(i18n.t('Optional'), key: const ValueKey('opt')),
          ),
      ]),
    );
    return Container(
      key: key,
      decoration: const BoxDecoration(border: Border(top: BorderSide(color: C.slate100, width: 8))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        showErr ? _Shake(key: ValueKey('shake-${g.id}-$_shake'), child: header) : header,
        if (g.kind == GroupKind.choice)
          for (final o in g.options) _choiceRow(g, o)
        else
          for (final o in g.options) _ingredientRow(o, i18n),
        const SizedBox(height: 6),
      ]),
    );
  }

  Widget _choiceRow(OptionGroup g, MenuOption o) {
    final selected = _chosen[g.id] ?? const [];
    final on = selected.contains(o.id);
    final single = g.maxSelect == 1;
    final disabled = !on && !single && g.maxSelect != null && selected.length >= g.maxSelect!;
    return Opacity(
      opacity: disabled ? 0.4 : 1,
      child: InkWell(
        onTap: disabled ? null : () => _toggle(g, o.id),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Row(children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                color: on ? C.brand600 : Colors.white,
                shape: single ? BoxShape.circle : BoxShape.rectangle,
                borderRadius: single ? null : BorderRadius.circular(6),
                border: Border.all(color: on ? C.brand600 : C.slate300, width: 2),
              ),
              child: AnimatedScale(
                scale: on ? 1 : 0,
                duration: const Duration(milliseconds: 300),
                curve: Curves.elasticOut,
                child: single
                    ? Center(child: Container(width: 8, height: 8, decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle)))
                    : const Icon(Icons.check, size: 15, color: Colors.white),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(o.name, style: TextStyle(fontSize: 15, color: C.slate900, fontWeight: on ? FontWeight.w700 : FontWeight.w400)),
            ),
            if (o.priceCents > 0) Text('+${formatPrice(o.priceCents)}', style: const TextStyle(color: C.slate500)),
          ]),
        ),
      ),
    );
  }

  Widget _ingredientRow(MenuOption o, I18n i18n) {
    final level = _levels[o.id] ?? _Level.regular;
    final choices = <(_Level, String)>[
      (_Level.remove, i18n.t('No')),
      (_Level.regular, i18n.t('Regular')),
      if (o.allowExtra) (_Level.extra, o.priceCents > 0 ? i18n.t('Extra +{price}', {'price': formatPrice(o.priceCents)}) : i18n.t('Extra')),
    ];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Wrap(alignment: WrapAlignment.spaceBetween, crossAxisAlignment: WrapCrossAlignment.center, runSpacing: 6, children: [
        AnimatedDefaultTextStyle(
          duration: const Duration(milliseconds: 250),
          style: TextStyle(
            fontSize: 15,
            color: level == _Level.remove ? C.slate400 : (level == _Level.extra ? C.brand700 : C.slate900),
            fontWeight: level == _Level.extra ? FontWeight.w700 : FontWeight.w400,
            decoration: level == _Level.remove ? TextDecoration.lineThrough : null,
          ),
          child: Text(o.name),
        ),
        Container(
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(color: C.slate100, borderRadius: BorderRadius.circular(999)),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            for (final (value, label) in choices)
              GestureDetector(
                onTap: () => setState(() => _levels[o.id] = value),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: level == value
                        ? (value == _Level.remove ? C.red600 : value == _Level.extra ? C.brand600 : Colors.white)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(999),
                    boxShadow: level == value ? Shadows.soft : null,
                  ),
                  child: Text(label,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: level == value ? (value == _Level.regular ? C.slate900 : Colors.white) : C.slate500,
                      )),
                ),
              ),
          ]),
        ),
      ]),
    );
  }

  Widget _footer(Evaluation ev, bool hasErrors, I18n i18n) {
    final summary = ev.priced.map((p) => describeSelection(p.mode, p.optionName, i18n)).join(' · ');
    return Container(
      padding: EdgeInsets.fromLTRB(16, 12, 16, 12 + MediaQuery.of(context).viewPadding.bottom),
      decoration: const BoxDecoration(color: Colors.white, border: Border(top: BorderSide(color: C.slate200))),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (summary.isNotEmpty) ...[
          Text(summary, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, color: C.slate500)),
          const SizedBox(height: 8),
        ],
        Row(children: [
          Container(
            decoration: BoxDecoration(color: C.slate100, borderRadius: BorderRadius.circular(999)),
            child: Row(children: [
              IconButton(
                onPressed: _qty > 1 ? () => setState(() => _qty--) : null,
                icon: const Icon(Icons.remove),
                tooltip: i18n.t('Decrease quantity'),
              ),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                transitionBuilder: (c, a) => ScaleTransition(scale: a, child: c),
                child: Text('$_qty', key: ValueKey(_qty), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
              ),
              IconButton(
                onPressed: () => setState(() => _qty = math.min(99, _qty + 1)),
                icon: const Icon(Icons.add),
                tooltip: i18n.t('Increase quantity'),
              ),
            ]),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Pressable(
              onTap: () => _add(ev),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
                decoration: BoxDecoration(
                  color: hasErrors ? C.slate400 : null,
                  gradient: hasErrors ? null : C.buttonGradient,
                  borderRadius: BorderRadius.circular(999),
                  boxShadow: hasErrors ? null : Shadows.glow,
                ),
                child: Row(children: [
                  Expanded(
                    child: Text(i18n.t('Add {n} to order', {'n': _qty}),
                        maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
                  ),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    child: Text(formatPrice(ev.unitPriceCents * _qty),
                        key: ValueKey(ev.unitPriceCents * _qty), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
                  ),
                ]),
              ),
            ),
          ),
        ]),
      ]),
    );
  }
}

/// Horizontal shake for a group the user forgot (the web's animate-shake).
class _Shake extends StatelessWidget {
  final Widget child;
  const _Shake({super.key, required this.child});
  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: const Duration(milliseconds: 450),
        builder: (_, v, c) => Transform.translate(offset: Offset(math.sin(v * math.pi * 4) * 6 * (1 - v), 0), child: c),
        child: child,
      );
}
