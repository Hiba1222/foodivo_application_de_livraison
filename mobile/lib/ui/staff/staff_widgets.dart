import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/money.dart';
import '../../core/theme.dart';
import '../../data/repo.dart';
import '../../data/staff_repo.dart';
import '../widgets.dart';

/// Bottom-tab shell used by the restaurant and driver areas (same look as the customer shell).
class RoleShell extends StatefulWidget {
  final List<(IconData, String, Widget)> tabs;
  final int? badgeTab;
  final int badgeCount;

  /// Optional: lets pages switch tabs (e.g. tapping a stat card opens Orders).
  final ValueNotifier<int>? controller;
  const RoleShell({super.key, required this.tabs, this.badgeTab, this.badgeCount = 0, this.controller});
  @override
  State<RoleShell> createState() => _RoleShellState();
}

class _RoleShellState extends State<RoleShell> {
  late final ValueNotifier<int> _tab = widget.controller ?? ValueNotifier(0);
  int get _index => _tab.value;

  @override
  void initState() {
    super.initState();
    _tab.addListener(_onTab);
  }

  @override
  void dispose() {
    _tab.removeListener(_onTab);
    super.dispose();
  }

  void _onTab() => setState(() {});

  void _go(int i) {
    if (i != _index) HapticFeedback.selectionClick();
    _tab.value = i;
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _index == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _go(0);
      },
      child: Scaffold(
        body: IndexedStack(index: _index, children: [for (final t in widget.tabs) t.$3]),
        bottomNavigationBar: Container(
          decoration: const BoxDecoration(color: Colors.white, border: Border(top: BorderSide(color: C.slate200))),
          child: SafeArea(
            top: false,
            child: SizedBox(
              height: 64,
              child: Row(children: [
                for (var i = 0; i < widget.tabs.length; i++)
                  Expanded(
                    child: Pressable(
                      scale: 0.92,
                      onTap: () => _go(i),
                      child: _Tab(
                        icon: widget.tabs[i].$1,
                        label: context.t(widget.tabs[i].$2),
                        active: i == _index,
                        badge: i == widget.badgeTab ? widget.badgeCount : 0,
                      ),
                    ),
                  ),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

class _Tab extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final int badge;
  const _Tab({required this.icon, required this.label, required this.active, required this.badge});
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
          if (badge > 0)
            Positioned(
              right: -12,
              top: -8,
              child: Container(
                constraints: const BoxConstraints(minWidth: 20),
                height: 20,
                padding: const EdgeInsets.symmetric(horizontal: 5),
                alignment: Alignment.center,
                decoration: BoxDecoration(color: C.rose600, borderRadius: BorderRadius.circular(999), boxShadow: Shadows.glow),
                child: Text('$badge', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800)),
              ),
            ),
        ]),
      ),
      const SizedBox(height: 3),
      Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color)),
    ]);
  }
}

/// Page title + optional subtitle, used at the top of every staff tab.
class PageHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget? trailing;
  const PageHeader(this.title, {super.key, this.subtitle, this.trailing});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: C.slate900)),
              if (subtitle != null) ...[
                const SizedBox(height: 2),
                Text(subtitle!, style: const TextStyle(color: C.slate500)),
              ],
            ]),
          ),
          ?trailing,
        ]),
      );
}

/// Amber "awaiting admin approval" notice.
class ApprovalBanner extends StatelessWidget {
  final String text;
  const ApprovalBanner(this.text, {super.key});
  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: const Color(0xFFFFFBEB), borderRadius: BorderRadius.circular(14), border: Border.all(color: const Color(0xFFFDE68A))),
        child: Row(children: [
          const Text('⏳', style: TextStyle(fontSize: 20)),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: const TextStyle(color: C.amber800, fontWeight: FontWeight.w600))),
        ]),
      );
}

/// Number that counts up from its previous value (animated stats).
class CountUp extends StatelessWidget {
  final int value;
  final String Function(int)? format;
  final TextStyle style;
  const CountUp(this.value, {super.key, this.format, required this.style});
  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
        tween: Tween(end: value.toDouble()),
        duration: const Duration(milliseconds: 900),
        curve: Curves.easeOutCubic,
        builder: (_, v, _) => Text(format?.call(v.round()) ?? '${v.round()}', style: style),
      );
}

/// Big number card (overview pages): tinted icon tile, counting number, optional tap.
class StatCard extends StatelessWidget {
  final String label, emoji;
  final int? value;
  final String Function(int)? format;
  final Color tint;
  final int index;
  final VoidCallback? onTap;
  final bool highlight;
  const StatCard({
    super.key,
    required this.label,
    required this.value,
    required this.emoji,
    this.format,
    this.tint = C.brand500,
    this.index = 0,
    this.onTap,
    this.highlight = false,
  });
  @override
  Widget build(BuildContext context) => FadeInUp(
        index: index,
        child: Pressable(
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 400),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: highlight ? tint : C.slate200.withValues(alpha: 0.7), width: highlight ? 2 : 1),
              boxShadow: highlight ? [BoxShadow(color: tint.withValues(alpha: 0.35), blurRadius: 22, spreadRadius: -6, offset: const Offset(0, 10))] : Shadows.soft,
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Container(
                  width: 40,
                  height: 40,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(color: tint.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(12)),
                  child: Text(emoji, style: const TextStyle(fontSize: 20)),
                ),
                const Spacer(),
                if (onTap != null) Icon(Icons.arrow_forward_rounded, size: 18, color: tint),
              ]),
              const SizedBox(height: 12),
              value == null
                  ? Container(width: 60, height: 26, decoration: BoxDecoration(color: C.slate100, borderRadius: BorderRadius.circular(8)))
                  : CountUp(value!, format: format, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: C.slate900)),
              const SizedBox(height: 2),
              Text(label, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: C.slate500, fontSize: 12, fontWeight: FontWeight.w600)),
            ]),
          ),
        ),
      );
}

/// Two stat cards side by side.
class StatRow extends StatelessWidget {
  final Widget a, b;
  const StatRow(this.a, this.b, {super.key});
  @override
  Widget build(BuildContext context) => IntrinsicHeight(
        child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [Expanded(child: a), const SizedBox(width: 12), Expanded(child: b)]),
      );
}

/// Big round power button with radar rings while ON ("Open", "Online").
class StatusToggle extends StatefulWidget {
  final bool on, busy;
  final String onText, offText;
  final VoidCallback? onTap;
  const StatusToggle({super.key, required this.on, required this.onText, required this.offText, this.onTap, this.busy = false});
  @override
  State<StatusToggle> createState() => _StatusToggleState();
}

class _StatusToggleState extends State<StatusToggle> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 2200))..repeat();
  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final on = widget.on;
    final enabled = widget.onTap != null && !widget.busy;
    final color = on ? C.green500 : C.slate400;
    return Pressable(
      onTap: enabled
          ? () {
              HapticFeedback.mediumImpact();
              widget.onTap!();
            }
          : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 450),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.fromLTRB(16, 16, 20, 16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          gradient: LinearGradient(
            colors: on ? const [Color(0xFF22C55E), Color(0xFF16A34A), Color(0xFF0D9488)] : const [C.slate200, C.slate100],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: on ? [BoxShadow(color: C.green600.withValues(alpha: 0.4), blurRadius: 26, spreadRadius: -6, offset: const Offset(0, 12))] : Shadows.soft,
        ),
        child: Opacity(
          opacity: widget.onTap == null ? 0.55 : 1,
          child: Row(children: [
            SizedBox(
              width: 64,
              height: 64,
              child: AnimatedBuilder(
                animation: _c,
                builder: (_, _) => Stack(alignment: Alignment.center, children: [
                  if (on)
                    for (final offset in [0.0, 0.5])
                      Builder(builder: (_) {
                        final v = (_c.value + offset) % 1;
                        return Container(
                          width: 40 + 26 * v,
                          height: 40 + 26 * v,
                          decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Colors.white.withValues(alpha: 0.7 * (1 - v)), width: 2)),
                        );
                      }),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 400),
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white, boxShadow: Shadows.lift),
                    child: widget.busy
                        ? Padding(padding: const EdgeInsets.all(13), child: CircularProgressIndicator(strokeWidth: 2.4, color: color))
                        : Icon(Icons.power_settings_new_rounded, color: color, size: 26),
                  ),
                ]),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                transitionBuilder: (c, a) => FadeTransition(opacity: a, child: SlideTransition(position: Tween(begin: const Offset(0, 0.3), end: Offset.zero).animate(a), child: c)),
                child: Text(
                  on ? widget.onText : widget.offText,
                  key: ValueKey(on),
                  style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: on ? Colors.white : C.slate700),
                ),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

/// "2× Burger — 15.000 TND" + chosen options/notes (web OrderItemOptions).
class OrderLines extends StatelessWidget {
  final List items;
  const OrderLines(this.items, {super.key});
  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      for (final oi in items)
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text.rich(TextSpan(children: [
              TextSpan(text: '${oi['quantity']}× ${oi['menu_items']?['name'] ?? ''}', style: const TextStyle(fontWeight: FontWeight.w700, color: C.slate800)),
              TextSpan(
                text: '  ${formatPrice(((oi['quantity'] as num) * (oi['unit_price_cents'] as num)).toInt())}',
                style: const TextStyle(color: C.slate500),
              ),
            ])),
            ..._options(context, (oi['order_item_options'] as List?) ?? const []),
            if ((oi['notes'] as String?)?.isNotEmpty == true)
              Text('📝 ${oi['notes']}', style: const TextStyle(fontSize: 12, color: C.amber800, fontStyle: FontStyle.italic)),
          ]),
        ),
    ]);
  }

  List<Widget> _options(BuildContext context, List opts) {
    if (opts.isEmpty) return const [];
    final adds = opts.where((o) => o['mode'] == 'add').toList();
    final extras = opts.where((o) => o['mode'] == 'extra').toList();
    final removes = opts.where((o) => o['mode'] == 'remove').toList();
    String names(List l) => l.map((o) => o['option_name']).join(', ');
    return [
      if (adds.isNotEmpty) Text('+ ${names(adds)}', style: const TextStyle(fontSize: 12, color: C.slate600)),
      if (extras.isNotEmpty) Text('${context.t('Extra')}: ${names(extras)}', style: const TextStyle(fontSize: 12, color: C.green700, fontWeight: FontWeight.w600)),
      if (removes.isNotEmpty) Text('${context.t('No')}: ${names(removes)}', style: const TextStyle(fontSize: 12, color: C.red600, fontWeight: FontWeight.w600)),
    ];
  }
}

/// Small coloured action button used on order cards.
class ActionChipButton extends StatelessWidget {
  final String label;
  final Color bg, fg;
  final VoidCallback? onTap;
  final bool busy;
  final IconData? icon;
  const ActionChipButton(this.label, {super.key, required this.bg, this.fg = Colors.white, this.onTap, this.busy = false, this.icon});
  @override
  Widget build(BuildContext context) => Pressable(
        onTap: busy ? null : onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            if (busy)
              SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: fg))
            else if (icon != null)
              Icon(icon, size: 16, color: fg),
            if (busy || icon != null) const SizedBox(width: 6),
            Text(label, style: TextStyle(color: fg, fontWeight: FontWeight.w800, fontSize: 13)),
          ]),
        ),
      );
}

/// Pick a photo from the gallery/camera, upload to Supabase Storage and save the URL on the row.
class PhotoPicker extends StatefulWidget {
  final String? currentUrl;
  final String storagePath, table, column, rowId;
  final String addLabel, changeLabel;
  final bool circle, wide;
  final ValueChanged<String>? onUploaded;
  const PhotoPicker({
    super.key,
    required this.currentUrl,
    required this.storagePath,
    required this.table,
    required this.column,
    required this.rowId,
    this.addLabel = 'Add photo',
    this.changeLabel = 'Change photo',
    this.circle = false,
    this.wide = false,
    this.onUploaded,
  });
  @override
  State<PhotoPicker> createState() => _PhotoPickerState();
}

class _PhotoPickerState extends State<PhotoPicker> {
  late String? _url = widget.currentUrl;
  bool _busy = false;

  Future<void> _pick() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (c) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(leading: const Icon(Icons.photo_library_outlined), title: Text(c.t('Choose from gallery')), onTap: () => Navigator.pop(c, ImageSource.gallery)),
          ListTile(leading: const Icon(Icons.photo_camera_outlined), title: Text(c.t('Take a photo')), onTap: () => Navigator.pop(c, ImageSource.camera)),
        ]),
      ),
    );
    if (source == null) return;
    final file = await ImagePicker().pickImage(source: source, maxWidth: 1600, imageQuality: 82);
    if (file == null) return;
    setState(() => _busy = true);
    try {
      final url = await RestaurantRepo.uploadImage(
        bytes: await file.readAsBytes(),
        storagePath: widget.storagePath,
        table: widget.table,
        column: widget.column,
        rowId: widget.rowId,
      );
      if (!mounted) return;
      setState(() => _url = url);
      widget.onUploaded?.call(url);
      showToast(context, context.i18n.t('Saved'));
    } catch (e) {
      if (mounted) showError(context, errorMessage(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final w = widget.wide ? 132.0 : 72.0;
    final radius = widget.circle ? BorderRadius.circular(999) : BorderRadius.circular(14);
    return Row(children: [
      ClipRRect(borderRadius: radius, child: SizedBox(width: w, height: widget.wide ? 56 : 72, child: NetImage(_url, fallback: '📷'))),
      const SizedBox(width: 12),
      ActionChipButton(
        context.t(_url == null ? widget.addLabel : widget.changeLabel),
        bg: C.slate800,
        icon: Icons.upload_rounded,
        busy: _busy,
        onTap: _pick,
      ),
    ]);
  }
}

/// Simple confirm dialog. Returns true if confirmed.
Future<bool> confirm(BuildContext context, String message, {String confirmLabel = 'Delete'}) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (c) => AlertDialog(
      content: Text(message),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c, false), child: Text(c.t('Cancel'))),
        TextButton(onPressed: () => Navigator.pop(c, true), child: Text(c.t(confirmLabel), style: const TextStyle(color: C.red600, fontWeight: FontWeight.w800))),
      ],
    ),
  );
  return ok == true;
}

/// Price text field with "TND" suffix.
class PriceField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  const PriceField(this.controller, {super.key, required this.label});
  @override
  Widget build(BuildContext context) => TextField(
        controller: controller,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: InputDecoration(labelText: label, suffixText: 'TND', hintText: '0.000'),
      );
}

/// Language + sign-out card shared by staff settings pages.
class AccountCard extends StatelessWidget {
  const AccountCard({super.key});
  @override
  Widget build(BuildContext context) => Column(children: [
        CardBox(
          child: Row(children: [
            Expanded(child: Text(context.t('Language'), style: const TextStyle(fontWeight: FontWeight.w800))),
            const LanguageSwitcher(),
          ]),
        ),
        const SizedBox(height: 20),
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
            minimumSize: const Size.fromHeight(50),
            side: const BorderSide(color: Color(0xFFFECACA)),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
          onPressed: () => sb.auth.signOut(),
          icon: const Icon(Icons.logout, color: C.red600),
          label: Text(context.t('Sign out'), style: const TextStyle(color: C.red600, fontWeight: FontWeight.w800)),
        ),
        const SizedBox(height: 16),
        const Center(child: Logo(height: 36)),
      ]);
}

String? priceText(int? millimes) => millimes == null ? null : priceInput(millimes);
