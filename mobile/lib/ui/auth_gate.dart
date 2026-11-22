import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/theme.dart';
import '../data/repo.dart';
import '../state/cart.dart';
import 'screens/auth_screens.dart';
import 'screens/complete_profile_screen.dart';
import 'shell.dart';
import 'staff/admin_area.dart';
import 'staff/driver_area.dart';
import 'staff/restaurant_area.dart';
import 'widgets.dart';

/// Bump to make the gate re-check the profile (e.g. right after signup saves it).
final gateRefresh = ValueNotifier<int>(0);

/// Decides what to show: login → the app for the account's role
/// (client: complete profile → shop · restaurant_owner: restaurant app · driver: driver app · admin: admin app).
class AuthGate extends StatefulWidget {
  const AuthGate({super.key});
  @override
  State<AuthGate> createState() => _AuthGateState();
}

enum _Stage { loading, signedOut, admin, restaurant, driver, needsProfile, ready, offline }

class _AuthGateState extends State<AuthGate> {
  _Stage _stage = _Stage.loading;
  bool _needsPhone = false, _needsAddress = false;
  StreamSubscription<AuthState>? _sub;

  @override
  void initState() {
    super.initState();
    _sub = sb.auth.onAuthStateChange.listen((e) {
      if (e.event == AuthChangeEvent.signedIn || e.event == AuthChangeEvent.signedOut || e.event == AuthChangeEvent.initialSession) {
        _resolve();
      }
    });
    gateRefresh.addListener(_resolve);
  }

  @override
  void dispose() {
    _sub?.cancel();
    gateRefresh.removeListener(_resolve);
    super.dispose();
  }

  Future<void> _resolve() async {
    if (sb.auth.currentSession == null) {
      if (mounted) {
        context.read<Cart>().clear();
        setState(() => _stage = _Stage.signedOut);
      }
      return;
    }
    try {
      final profile = await Repo.myProfile();
      if (profile == null) return setState(() => _stage = _Stage.signedOut);
      final role = profile['role'];
      if (role == 'restaurant_owner') return setState(() => _stage = _Stage.restaurant);
      if (role == 'driver') return setState(() => _stage = _Stage.driver);
      if (role == 'admin') return setState(() => _stage = _Stage.admin);
      final addresses = await Repo.addresses();
      _needsPhone = (profile['phone'] as String?)?.isNotEmpty != true;
      _needsAddress = addresses.isEmpty;
      if (mounted) setState(() => _stage = _needsPhone || _needsAddress ? _Stage.needsProfile : _Stage.ready);
    } catch (_) {
      if (mounted) setState(() => _stage = _Stage.offline);
    }
  }

  @override
  Widget build(BuildContext context) {
    final Widget child = switch (_stage) {
      _Stage.loading => const _Splash(),
      _Stage.signedOut => const LoginScreen(),
      _Stage.admin => const AdminArea(),
      _Stage.restaurant => const RestaurantArea(),
      _Stage.driver => const DriverArea(),
      _Stage.needsProfile => CompleteProfileScreen(needsPhone: _needsPhone, needsAddress: _needsAddress, onDone: _resolve),
      _Stage.ready => const AppShell(),
      _Stage.offline => _Offline(onRetry: () {
          setState(() => _stage = _Stage.loading);
          _resolve();
        }),
    };
    return AnimatedSwitcher(duration: const Duration(milliseconds: 350), child: KeyedSubtree(key: ValueKey(_stage), child: child));
  }
}

class _Splash extends StatelessWidget {
  const _Splash();
  @override
  Widget build(BuildContext context) => const Scaffold(
        backgroundColor: Colors.white,
        body: Center(child: Logo(height: 90)),
      );
}

class _Offline extends StatelessWidget {
  final VoidCallback onRetry;
  const _Offline({required this.onRetry});
  @override
  Widget build(BuildContext context) => Scaffold(
        body: EmptyState(
          emoji: '📡',
          title: context.t('No internet connection'),
          action: PrimaryButton(context.t('Retry'), expand: false, onPressed: onRetry),
        ),
      );
}

/// Shared background for auth screens (gradient + floating blobs + food emoji).
class AuthBackground extends StatefulWidget {
  final Widget child;
  const AuthBackground({super.key, required this.child});
  @override
  State<AuthBackground> createState() => _AuthBackgroundState();
}

class _AuthBackgroundState extends State<AuthBackground> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: const Duration(seconds: 12))..repeat(reverse: true);
  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  Widget _blob(Color color, double size) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(shape: BoxShape.circle, boxShadow: [BoxShadow(color: color, blurRadius: 90, spreadRadius: size / 4)]),
      );

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(colors: [C.brand50, Colors.white, C.rose50], begin: Alignment.topLeft, end: Alignment.bottomRight),
      ),
      child: AnimatedBuilder(
        animation: _c,
        builder: (_, child) {
          final v = Curves.easeInOut.transform(_c.value);
          return Stack(children: [
            Positioned(left: -80 + 20 * v, top: -60 - 20 * v, child: _blob(C.brand300.withValues(alpha: 0.35), 220)),
            Positioned(right: -90 - 20 * v, bottom: -80 + 24 * v, child: _blob(C.rose300.withValues(alpha: 0.35), 240)),
            Positioned(left: 30, top: 120 + 14 * v, child: Opacity(opacity: 0.2, child: Text('🍕', style: TextStyle(fontSize: 34)))),
            Positioned(right: 36, top: 90 - 10 * v, child: Opacity(opacity: 0.2, child: Text('🍔', style: TextStyle(fontSize: 34)))),
            Positioned(left: 44, bottom: 110 - 12 * v, child: Opacity(opacity: 0.2, child: Text('🌮', style: TextStyle(fontSize: 34)))),
            Positioned(right: 40, bottom: 150 + 10 * v, child: Opacity(opacity: 0.2, child: Text('🥗', style: TextStyle(fontSize: 34)))),
            child!,
          ]);
        },
        child: widget.child,
      ),
    );
  }
}
