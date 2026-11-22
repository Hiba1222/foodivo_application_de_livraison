import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../core/i18n.dart';
import '../core/theme.dart';

extension I18nX on BuildContext {
  /// Translate (rebuilds when the language changes).
  String t(String key, [Map<String, Object?>? vars]) => watch<I18n>().t(key, vars);
  I18n get i18n => read<I18n>();
}

/// Foodivo wordmark from assets.
class Logo extends StatelessWidget {
  final double height;
  const Logo({super.key, this.height = 40});
  @override
  Widget build(BuildContext context) =>
      Image.asset('assets/images/foodivo-logo.png', height: height, fit: BoxFit.contain, filterQuality: FilterQuality.medium);
}

/// Shrinks slightly while pressed — the web's `active:scale(0.97)`.
class Pressable extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final double scale;
  const Pressable({super.key, required this.child, this.onTap, this.scale = 0.97});
  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  bool _down = false;
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: widget.onTap == null ? null : (_) => setState(() => _down = true),
      onTapCancel: () => setState(() => _down = false),
      onTapUp: (_) => setState(() => _down = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _down ? widget.scale : 1,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}

/// Fade + slide up on first build; [index] staggers lists (the web's `.stagger`).
class FadeInUp extends StatelessWidget {
  final Widget child;
  final int index;
  const FadeInUp({super.key, required this.child, this.index = 0});
  @override
  Widget build(BuildContext context) {
    final delay = (index.clamp(0, 12)) * 60;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 500 + delay),
      curve: Interval(delay / (500 + delay), 1, curve: const Cubic(0.22, 1, 0.36, 1)),
      builder: (_, v, c) => Opacity(opacity: v, child: Transform.translate(offset: Offset(0, 12 * (1 - v)), child: c)),
      child: child,
    );
  }
}

/// Network image with soft gradient placeholder and emoji fallback.
class NetImage extends StatelessWidget {
  final String? url;
  final BoxFit fit;
  final String fallback;
  const NetImage(this.url, {super.key, this.fit = BoxFit.cover, this.fallback = '🍽️'});
  @override
  Widget build(BuildContext context) {
    final placeholder = Container(
      decoration: const BoxDecoration(gradient: LinearGradient(colors: [C.brand100, C.rose100])),
      alignment: Alignment.center,
      child: Text(fallback, style: const TextStyle(fontSize: 40)),
    );
    if (url == null || url!.isEmpty) return placeholder;
    return CachedNetworkImage(
      imageUrl: url!,
      fit: fit,
      fadeInDuration: const Duration(milliseconds: 250),
      placeholder: (_, _) => Container(color: C.slate100),
      errorWidget: (_, _, _) => placeholder,
    );
  }
}

/// Pulsing dot (open restaurant, active order) — the web's `.live-dot`.
class LiveDot extends StatefulWidget {
  final Color color;
  final double size;
  const LiveDot({super.key, this.color = C.green500, this.size = 8});
  @override
  State<LiveDot> createState() => _LiveDotState();
}

class _LiveDotState extends State<LiveDot> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1600))..repeat();
  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.size;
    return SizedBox(
      width: s,
      height: s,
      child: AnimatedBuilder(
        animation: _c,
        builder: (_, _) {
          final v = Curves.easeOut.transform((_c.value / 0.75).clamp(0, 1));
          return Stack(clipBehavior: Clip.none, alignment: Alignment.center, children: [
            Transform.scale(
              scale: 1 + 1.4 * v,
              child: Container(
                width: s,
                height: s,
                decoration: BoxDecoration(shape: BoxShape.circle, color: widget.color.withValues(alpha: 0.6 * (1 - v))),
              ),
            ),
            Container(width: s, height: s, decoration: BoxDecoration(shape: BoxShape.circle, color: widget.color)),
          ]);
        },
      ),
    );
  }
}

/// Soft pulsing rose/amber glow for special-offer cards (the web's `.offer-glow`).
class OfferGlow extends StatefulWidget {
  final Widget child;
  final double radius;
  const OfferGlow({super.key, required this.child, this.radius = 24});
  @override
  State<OfferGlow> createState() => _OfferGlowState();
}

class _OfferGlowState extends State<OfferGlow> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1300))..repeat(reverse: true);
  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (_, child) {
        final v = Curves.easeInOut.transform(_c.value);
        final ring = Color.lerp(C.rose300, C.amber400, v)!;
        final shadow = Color.lerp(C.rose600, C.amber500, v)!;
        return DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.radius),
            border: Border.all(color: ring, width: 2 + v),
            boxShadow: [BoxShadow(color: shadow.withValues(alpha: 0.35 + 0.15 * v), blurRadius: 24 + 8 * v, spreadRadius: -8, offset: const Offset(0, 12))],
          ),
          child: child,
        );
      },
      child: ClipRRect(borderRadius: BorderRadius.circular(widget.radius - 2), child: widget.child),
    );
  }
}

/// Round tilted "-20%" badge.
class DiscountBadge extends StatelessWidget {
  final int percent;
  final double size;
  const DiscountBadge(this.percent, {super.key, this.size = 52});
  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: 0.2,
      child: Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: const LinearGradient(colors: [C.rose500, C.red600], begin: Alignment.topLeft, end: Alignment.bottomRight),
          border: Border.all(color: Colors.white.withValues(alpha: 0.7), width: 3),
          boxShadow: Shadows.lift,
        ),
        child: Text('-$percent%', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: size * 0.28)),
      ),
    );
  }
}

/// Small rounded label.
class Pill extends StatelessWidget {
  final String text;
  final Color bg, fg;
  final Widget? leading;
  final double fontSize;
  const Pill(this.text, {super.key, this.bg = C.slate100, this.fg = C.slate600, this.leading, this.fontSize = 11});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        if (leading != null) ...[leading!, const SizedBox(width: 5)],
        Flexible(
          child: Text(text,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: fg, fontWeight: FontWeight.w700, fontSize: fontSize)),
        ),
      ]),
    );
  }
}

/// "⏳ Ends in 2d 4h" — ticks every 30s, red & pulsing in the last 24h.
class OfferCountdown extends StatefulWidget {
  final DateTime endsAt;
  const OfferCountdown(this.endsAt, {super.key});
  @override
  State<OfferCountdown> createState() => _OfferCountdownState();
}

class _OfferCountdownState extends State<OfferCountdown> {
  Timer? _timer;
  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 30), (_) => setState(() {}));
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final left = widget.endsAt.difference(DateTime.now());
    if (left.isNegative) return const SizedBox.shrink();
    final mins = left.inMinutes, days = mins ~/ 1440, hours = (mins % 1440) ~/ 60, rest = mins % 60;
    final d = context.t('d'), h = context.t('h');
    final txt = days > 0 ? '$days$d $hours$h' : hours > 0 ? '$hours$h ${rest}m' : '${rest}m';
    final urgent = left.inHours < 24;
    return Pill('⏳ ${context.t('Ends in {time}', {'time': txt})}',
        bg: urgent ? const Color(0xFFFEE2E2) : C.slate900.withValues(alpha: 0.8), fg: urgent ? const Color(0xFFB91C1C) : Colors.white);
  }
}

/// Orange gradient button with glow (the web's `.btn-primary`).
class PrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool loading, expand;
  final Widget? trailing;
  const PrimaryButton(this.label, {super.key, this.onPressed, this.loading = false, this.expand = true, this.trailing});
  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null && !loading;
    return Pressable(
      onTap: enabled ? onPressed : null,
      child: AnimatedOpacity(
        opacity: enabled ? 1 : 0.55,
        duration: const Duration(milliseconds: 200),
        child: Container(
          width: expand ? double.infinity : null,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
          decoration: BoxDecoration(
            gradient: C.buttonGradient,
            borderRadius: BorderRadius.circular(14),
            boxShadow: enabled ? Shadows.glow : null,
          ),
          child: Row(mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min, mainAxisAlignment: MainAxisAlignment.center, children: [
            if (loading)
              const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white))
            else
              Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15)),
            if (trailing != null && !loading) ...[const SizedBox(width: 8), trailing!],
          ]),
        ),
      ),
    );
  }
}

/// White rounded card with soft shadow.
class CardBox extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? borderColor;
  const CardBox({super.key, required this.child, this.padding = const EdgeInsets.all(16), this.borderColor});
  @override
  Widget build(BuildContext context) => Container(
        padding: padding,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: borderColor ?? C.slate200.withValues(alpha: 0.7)),
          boxShadow: Shadows.soft,
        ),
        child: child,
      );
}

/// EN / FR pill with sliding white thumb.
class LanguageSwitcher extends StatelessWidget {
  final bool glass;
  const LanguageSwitcher({super.key, this.glass = false});
  @override
  Widget build(BuildContext context) {
    final i = context.watch<I18n>();
    Widget opt(String code, String flag) {
      final active = i.locale == code;
      return Expanded(
        child: GestureDetector(
          onTap: () => i.setLocale(code),
          behavior: HitTestBehavior.opaque,
          child: Center(
            child: Text('$flag ${code.toUpperCase()}',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: active ? C.slate900 : C.slate400)),
          ),
        ),
      );
    }

    return Container(
      width: 124,
      height: 36,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: glass ? Colors.white.withValues(alpha: 0.7) : C.slate100,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: glass ? Colors.white : C.slate200),
      ),
      child: Stack(children: [
        AnimatedAlign(
          alignment: i.isFr ? Alignment.centerRight : Alignment.centerLeft,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic,
          child: FractionallySizedBox(
            widthFactor: 0.5,
            child: Container(
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(999), boxShadow: Shadows.soft),
            ),
          ),
        ),
        Row(children: [opt('en', '🇬🇧'), opt('fr', '🇫🇷')]),
      ]),
    );
  }
}

/// Status chip colours — same as the website.
(Color, Color) statusColors(String s) => switch (s) {
      'pending' => (C.amber100, const Color(0xFFB45309)),
      'accepted' => (C.blue100, C.blue700),
      'rejected' => (const Color(0xFFFEE2E2), const Color(0xFFB91C1C)),
      'ready_for_pickup' || 'driver_assigned' => (C.indigo100, C.indigo700),
      'picked_up' => (C.purple100, C.purple700),
      'delivered' => (C.green100, C.green700),
      _ => (C.slate200, C.slate600),
    };

void showToast(BuildContext context, String message, {IconData icon = Icons.check_circle, Color iconColor = C.green500}) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      duration: const Duration(milliseconds: 2200),
      content: Row(children: [Icon(icon, color: iconColor, size: 20), const SizedBox(width: 10), Expanded(child: Text(message))]),
    ));
}

void showError(BuildContext context, String message) =>
    showToast(context, message, icon: Icons.error_outline, iconColor: C.rose500);

/// Centered empty-state with floating emoji.
class EmptyState extends StatelessWidget {
  final String emoji, title;
  final String? subtitle;
  final Widget? action;
  const EmptyState({super.key, required this.emoji, required this.title, this.subtitle, this.action});
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.6, end: 1),
            duration: const Duration(milliseconds: 600),
            curve: Curves.elasticOut,
            builder: (_, v, c) => Transform.scale(scale: v, child: c),
            child: Container(
              width: 96,
              height: 96,
              alignment: Alignment.center,
              decoration: const BoxDecoration(shape: BoxShape.circle, gradient: LinearGradient(colors: [C.brand100, C.rose100])),
              child: Text(emoji, style: const TextStyle(fontSize: 46)),
            ),
          ),
          const SizedBox(height: 18),
          Text(title, textAlign: TextAlign.center, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: C.slate900)),
          if (subtitle != null) ...[
            const SizedBox(height: 6),
            Text(subtitle!, textAlign: TextAlign.center, style: const TextStyle(color: C.slate500)),
          ],
          if (action != null) ...[const SizedBox(height: 20), action!],
        ]),
      ),
    );
  }
}
