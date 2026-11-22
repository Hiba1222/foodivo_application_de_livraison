// Interactive / animated pieces for the restaurant, driver and admin apps.
import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/theme.dart';
import '../widgets.dart';

/// Gradient header with greeting, title, floating emoji and optional avatar/trailing.
class HeroHeader extends StatefulWidget {
  final String greeting, title;
  final String? subtitle, imageUrl;
  final String emoji;
  final List<Color> colors;
  final Widget? trailing;
  const HeroHeader({
    super.key,
    required this.greeting,
    required this.title,
    this.subtitle,
    this.imageUrl,
    this.emoji = '🍔',
    this.colors = const [C.brand500, C.brand600, C.rose500],
    this.trailing,
  });
  @override
  State<HeroHeader> createState() => _HeroHeaderState();
}

class _HeroHeaderState extends State<HeroHeader> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: const Duration(seconds: 4))..repeat(reverse: true);
  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeInUp(
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(26),
          gradient: LinearGradient(colors: widget.colors, begin: Alignment.topLeft, end: Alignment.bottomRight),
          boxShadow: [BoxShadow(color: widget.colors.last.withValues(alpha: 0.35), blurRadius: 30, spreadRadius: -10, offset: const Offset(0, 16))],
        ),
        child: AnimatedBuilder(
          animation: _c,
          builder: (_, child) {
            final v = Curves.easeInOut.transform(_c.value);
            return Stack(children: [
              Positioned(right: -30 + 10 * v, top: -40, child: _bubble(140, 0.12)),
              Positioned(left: -20, bottom: -50 + 10 * v, child: _bubble(120, 0.10)),
              Positioned(
                right: 18,
                bottom: 10 + 8 * v,
                child: Transform.rotate(angle: -0.15 + 0.3 * v, child: Opacity(opacity: 0.9, child: Text(widget.emoji, style: const TextStyle(fontSize: 46)))),
              ),
              child!,
            ]);
          },
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 20),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              if (widget.imageUrl != null || widget.trailing == null) ...[
                Container(
                  padding: const EdgeInsets.all(2.5),
                  decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.white),
                  child: ClipOval(child: SizedBox(width: 50, height: 50, child: NetImage(widget.imageUrl, fallback: widget.emoji))),
                ),
                const SizedBox(width: 12),
              ],
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(right: 54),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(widget.greeting, style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontWeight: FontWeight.w600)),
                    const SizedBox(height: 2),
                    Text(widget.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900, height: 1.15)),
                    if (widget.subtitle != null) ...[
                      const SizedBox(height: 4),
                      Text(widget.subtitle!, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 13)),
                    ],
                  ]),
                ),
              ),
              ?widget.trailing,
            ]),
          ),
        ),
      ),
    );
  }

  Widget _bubble(double size, double alpha) =>
      Container(width: size, height: size, decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withValues(alpha: alpha)));
}

/// "Good morning" / "Good afternoon" / "Good evening" key for the current hour.
String greetingKey() {
  final h = DateTime.now().hour;
  return h < 12 ? 'Good morning' : h < 18 ? 'Good afternoon' : 'Good evening';
}

/// Swipe the knob to the end to confirm (prevents accidental taps on important actions).
class SlideToConfirm extends StatefulWidget {
  final String label;
  final Color color;
  final IconData icon;
  final Future<void> Function() onConfirm;
  const SlideToConfirm({super.key, required this.label, required this.onConfirm, this.color = C.green600, this.icon = Icons.chevron_right_rounded});
  @override
  State<SlideToConfirm> createState() => _SlideToConfirmState();
}

class _SlideToConfirmState extends State<SlideToConfirm> with SingleTickerProviderStateMixin {
  double _drag = 0;
  bool _busy = false;
  late final _hint = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400))..repeat();

  @override
  void dispose() {
    _hint.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const h = 58.0, knob = 50.0;
    return LayoutBuilder(builder: (context, box) {
      final max = box.maxWidth - knob - 8;
      final p = max <= 0 ? 0.0 : (_drag / max).clamp(0.0, 1.0);
      return Container(
        height: h,
        decoration: BoxDecoration(
          color: Color.lerp(widget.color.withValues(alpha: 0.12), widget.color, p),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: widget.color.withValues(alpha: 0.35)),
        ),
        child: Stack(alignment: Alignment.centerLeft, children: [
          // Shimmering label
          Center(
            child: AnimatedBuilder(
              animation: _hint,
              builder: (_, _) => ShaderMask(
                shaderCallback: (r) => LinearGradient(
                  colors: [widget.color, Colors.white, widget.color],
                  stops: [(_hint.value - 0.2).clamp(0, 1), _hint.value, (_hint.value + 0.2).clamp(0, 1)],
                ).createShader(r),
                child: Opacity(
                  opacity: 1 - p,
                  child: Padding(
                    padding: const EdgeInsets.only(left: knob),
                    child: Text(widget.label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 15)),
                  ),
                ),
              ),
            ),
          ),
          AnimatedPositioned(
            duration: Duration(milliseconds: _drag == 0 ? 300 : 0),
            curve: Curves.easeOutBack,
            left: 4 + (_drag.clamp(0, math.max(0, max))),
            child: GestureDetector(
              onHorizontalDragUpdate: _busy ? null : (d) => setState(() => _drag = (_drag + d.delta.dx).clamp(0, math.max(0, max))),
              onHorizontalDragEnd: _busy
                  ? null
                  : (_) async {
                      if (p > 0.85) {
                        HapticFeedback.heavyImpact();
                        setState(() => (_drag = max, _busy = true));
                        try {
                          await widget.onConfirm();
                        } finally {
                          if (mounted) setState(() => (_drag = 0, _busy = false));
                        }
                      } else {
                        setState(() => _drag = 0);
                      }
                    },
              child: Container(
                width: knob,
                height: knob,
                decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white, boxShadow: Shadows.lift),
                child: _busy
                    ? Padding(padding: const EdgeInsets.all(14), child: CircularProgressIndicator(strokeWidth: 2.5, color: widget.color))
                    : Icon(widget.icon, color: widget.color, size: 28),
              ),
            ),
          ),
        ]),
      );
    });
  }
}

/// Horizontal step tracker: 🏪 → 🛍️ → 🏠 (driver) or 🔔 → 🍳 → 📦 → 🛵 (restaurant).
class StepTracker extends StatelessWidget {
  final List<(String, String)> steps; // emoji, label
  final int current;
  final Color color;
  const StepTracker({super.key, required this.steps, required this.current, this.color = C.brand600});
  @override
  Widget build(BuildContext context) {
    return Row(children: [
      for (var i = 0; i < steps.length; i++) ...[
        Expanded(
          child: Column(children: [
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: i <= current ? 1 : 0),
              duration: Duration(milliseconds: 400 + i * 120),
              curve: Curves.easeOutBack,
              builder: (_, v, _) => Container(
                width: 38,
                height: 38,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Color.lerp(C.slate100, i == current ? color : color.withValues(alpha: 0.15), v),
                  boxShadow: i == current ? [BoxShadow(color: color.withValues(alpha: 0.45), blurRadius: 14, spreadRadius: -2)] : null,
                ),
                child: Transform.scale(scale: 0.85 + 0.15 * v, child: Text(steps[i].$1, style: const TextStyle(fontSize: 18))),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              steps[i].$2,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 10, fontWeight: i == current ? FontWeight.w900 : FontWeight.w600, color: i <= current ? C.slate800 : C.slate400),
            ),
          ]),
        ),
        if (i < steps.length - 1)
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 18),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(9),
                child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: i < current ? 1 : 0),
                  duration: const Duration(milliseconds: 600),
                  curve: Curves.easeOutCubic,
                  builder: (_, v, _) => LinearProgressIndicator(value: v, minHeight: 4, color: color, backgroundColor: C.slate100),
                ),
              ),
            ),
          ),
      ],
    ]);
  }
}

/// Scrollable filter chips with counts and a sliding active state.
class FilterTabs extends StatelessWidget {
  final List<(String, int?)> tabs; // label, count
  final int selected;
  final ValueChanged<int> onSelect;
  const FilterTabs({super.key, required this.tabs, required this.selected, required this.onSelect});
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: tabs.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final active = i == selected;
          return Pressable(
            onTap: () {
              HapticFeedback.selectionClick();
              onSelect(i);
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeOutCubic,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                gradient: active ? C.buttonGradient : null,
                color: active ? null : Colors.white,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: active ? Colors.transparent : C.slate200),
                boxShadow: active ? Shadows.glow : null,
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Text(tabs[i].$1, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: active ? Colors.white : C.slate600)),
                if ((tabs[i].$2 ?? 0) > 0) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
                    decoration: BoxDecoration(color: active ? Colors.white.withValues(alpha: 0.25) : C.slate100, borderRadius: BorderRadius.circular(999)),
                    child: Text('${tabs[i].$2}', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: active ? Colors.white : C.slate600)),
                  ),
                ],
              ]),
            ),
          );
        },
      ),
    );
  }
}

/// Pulsing coloured border for things that need attention (new orders).
class PulseBorder extends StatefulWidget {
  final Widget child;
  final bool active;
  final Color color;
  const PulseBorder({super.key, required this.child, this.active = true, this.color = C.amber500});
  @override
  State<PulseBorder> createState() => _PulseBorderState();
}

class _PulseBorderState extends State<PulseBorder> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1100))..repeat(reverse: true);
  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.active) return widget.child;
    return AnimatedBuilder(
      animation: _c,
      builder: (_, child) => DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(color: widget.color.withValues(alpha: 0.25 + 0.3 * _c.value), blurRadius: 10 + 14 * _c.value, spreadRadius: -2)],
        ),
        child: child,
      ),
      child: widget.child,
    );
  }
}

/// Full-screen emoji burst (delivery done, restaurant approved…). Call `celebrate(context)`.
void celebrate(BuildContext context, {List<String> emojis = const ['🎉', '✨', '🧡', '⭐', '🥳']}) {
  final overlay = Overlay.of(context);
  late OverlayEntry entry;
  entry = OverlayEntry(builder: (_) => _Burst(emojis: emojis, onDone: () => entry.remove()));
  overlay.insert(entry);
  HapticFeedback.heavyImpact();
}

class _Burst extends StatefulWidget {
  final List<String> emojis;
  final VoidCallback onDone;
  const _Burst({required this.emojis, required this.onDone});
  @override
  State<_Burst> createState() => _BurstState();
}

class _BurstState extends State<_Burst> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1600))
    ..forward().whenComplete(widget.onDone);
  final _rnd = math.Random();
  late final _parts = List.generate(26, (i) => (_rnd.nextDouble() * 2 * math.pi, 180 + _rnd.nextDouble() * 220, widget.emojis[i % widget.emojis.length], 18 + _rnd.nextDouble() * 18));

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _c,
        builder: (_, _) {
          final t = Curves.easeOutCubic.transform(_c.value);
          final fade = (1 - _c.value * 1.1).clamp(0.0, 1.0);
          return Stack(children: [
            for (final p in _parts)
              Positioned(
                left: size.width / 2 + math.cos(p.$1) * p.$2 * t - p.$4 / 2,
                top: size.height * 0.45 + math.sin(p.$1) * p.$2 * t + 260 * _c.value * _c.value - p.$4 / 2,
                child: Opacity(opacity: fade, child: Text(p.$3, style: TextStyle(fontSize: p.$4, decoration: TextDecoration.none))),
              ),
          ]);
        },
      ),
    );
  }
}
