import 'package:material_ui/material_ui.dart';

import '../../core/theme.dart';
import '../../data/repo.dart';
import '../auth_gate.dart';
import '../widgets.dart';

/// Glass card used by login & signup.
class _AuthCard extends StatelessWidget {
  final List<Widget> children;
  const _AuthCard({required this.children});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: AuthBackground(
        child: SafeArea(
          child: Stack(children: [
            const Positioned(right: 16, top: 12, child: LanguageSwitcher(glass: true)),
            Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 64, 20, 24),
                child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0.94, end: 1),
                  duration: const Duration(milliseconds: 450),
                  curve: const Cubic(0.22, 1, 0.36, 1),
                  builder: (_, v, c) => Opacity(opacity: ((v - 0.94) / 0.06).clamp(0, 1), child: Transform.scale(scale: v, child: c)),
                  child: Container(
                    constraints: const BoxConstraints(maxWidth: 420),
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.9),
                      borderRadius: BorderRadius.circular(28),
                      border: Border.all(color: Colors.white),
                      boxShadow: Shadows.lift,
                    ),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children),
                  ),
                ),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

Widget _gradientTitle(String text) => ShaderMask(
      shaderCallback: (r) => const LinearGradient(colors: [C.brand600, C.rose500]).createShader(r),
      child: Text(text, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: Colors.white)),
    );

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _email = TextEditingController(), _password = TextEditingController();
  bool _loading = false, _obscure = true;
  String? _error;

  Future<void> _submit() async {
    if (_email.text.trim().isEmpty || _password.text.isEmpty) {
      return setState(() => _error = context.i18n.t('Required field'));
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await sb.auth.signInWithPassword(email: _email.text.trim(), password: _password.text);
      // AuthGate reacts to the sign-in event.
    } catch (e) {
      if (mounted) setState(() => _error = context.i18n.t(errorMessage(e)));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return _AuthCard(children: [
      const Center(child: Logo(height: 80)),
      const SizedBox(height: 12),
      _gradientTitle(context.t('Welcome back')),
      const SizedBox(height: 4),
      Text(context.t("Sign in — you'll be routed to your dashboard automatically."), style: const TextStyle(color: C.slate500)),
      const SizedBox(height: 22),
      TextField(
        controller: _email,
        keyboardType: TextInputType.emailAddress,
        autofillHints: const [AutofillHints.email],
        decoration: InputDecoration(labelText: context.t('Email'), prefixIcon: const Icon(Icons.mail_outline)),
      ),
      const SizedBox(height: 12),
      TextField(
        controller: _password,
        obscureText: _obscure,
        autofillHints: const [AutofillHints.password],
        onSubmitted: (_) => _submit(),
        decoration: InputDecoration(
          labelText: context.t('Password'),
          prefixIcon: const Icon(Icons.lock_outline),
          suffixIcon: IconButton(
            icon: Icon(_obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined),
            onPressed: () => setState(() => _obscure = !_obscure),
          ),
        ),
      ),
      if (_error != null) ...[
        const SizedBox(height: 10),
        Text(_error!, style: const TextStyle(color: C.red600, fontWeight: FontWeight.w600)),
      ],
      const SizedBox(height: 18),
      PrimaryButton(_loading ? context.t('Signing in…') : context.t('Sign in'), loading: _loading, onPressed: _submit),
      const SizedBox(height: 14),
      Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        Text(context.t('No account yet?'), style: const TextStyle(color: C.slate500)),
        TextButton(
          onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SignupScreen())),
          child: Text(context.t('Sign up'), style: const TextStyle(color: C.brand600, fontWeight: FontWeight.w700)),
        ),
      ]),
    ]);
  }
}

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});
  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _name = TextEditingController(), _phone = TextEditingController();
  final _email = TextEditingController(), _password = TextEditingController();
  bool _loading = false;
  String? _error;
  String _role = 'client';

  static const _roles = [
    ('client', 'Client', 'Order food for delivery', '🍔'),
    ('restaurant_owner', 'Restaurant', 'Sell food on the platform', '🧑‍🍳'),
    ('driver', 'Driver', 'Deliver orders and earn', '🛵'),
  ];

  Future<void> _submit() async {
    final i = context.i18n;
    if ([_name, _phone, _email].any((c) => c.text.trim().isEmpty)) return setState(() => _error = i.t('Required field'));
    if (_password.text.length < 6) return setState(() => _error = i.t('Password must be at least 6 characters'));
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = await sb.auth.signUp(email: _email.text.trim(), password: _password.text);
      if (res.user == null || res.session == null) {
        setState(() => _error = i.t(
            'Account created, but email confirmation is required before you can continue. Check your inbox, or ask the project owner to disable email confirmation for development.'));
        return;
      }
      // Restaurant and driver accounts still need admin approval after signup (same as the website).
      await sb.from('profiles').insert({
        'id': res.user!.id,
        'role': _role,
        'full_name': _name.text.trim(),
        'phone': _phone.text.trim(),
      });
      if (mounted) Navigator.of(context).popUntil((r) => r.isFirst);
      // Re-run the gate now that the profile exists.
      gateRefresh.value++;
    } catch (e) {
      if (mounted) setState(() => _error = i.t(errorMessage(e)));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return _AuthCard(children: [
      Align(
        alignment: Alignment.centerLeft,
        child: IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.arrow_back)),
      ),
      const Center(child: Logo(height: 64)),
      const SizedBox(height: 8),
      _gradientTitle(context.t('Create account')),
      const SizedBox(height: 4),
      Text(context.t('Restaurant and driver accounts need admin approval after signup.'), textAlign: TextAlign.center, style: const TextStyle(color: C.slate500, fontSize: 13)),
      const SizedBox(height: 14),
      Row(children: [
        for (final r in _roles)
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3),
              child: Pressable(
                onTap: () => setState(() => _role = r.$1),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: _role == r.$1 ? C.brand50 : Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: _role == r.$1 ? C.brand600 : C.slate200, width: _role == r.$1 ? 2 : 1),
                  ),
                  child: Column(children: [
                    Text(r.$4, style: const TextStyle(fontSize: 22)),
                    const SizedBox(height: 2),
                    Text(context.t(r.$2), style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: _role == r.$1 ? C.brand700 : C.slate600)),
                  ]),
                ),
              ),
            ),
          ),
      ]),
      const SizedBox(height: 6),
      Text(context.t(_roles.firstWhere((r) => r.$1 == _role).$3), textAlign: TextAlign.center, style: const TextStyle(fontSize: 12, color: C.slate400)),
      const SizedBox(height: 14),
      TextField(controller: _name, textCapitalization: TextCapitalization.words, decoration: InputDecoration(labelText: context.t('Full name'), prefixIcon: const Icon(Icons.person_outline))),
      const SizedBox(height: 12),
      TextField(
        controller: _phone,
        keyboardType: TextInputType.phone,
        decoration: InputDecoration(labelText: context.t('Phone number'), hintText: '+216 20 123 456', prefixIcon: const Icon(Icons.phone_outlined)),
      ),
      const SizedBox(height: 12),
      TextField(controller: _email, keyboardType: TextInputType.emailAddress, decoration: InputDecoration(labelText: context.t('Email'), prefixIcon: const Icon(Icons.mail_outline))),
      const SizedBox(height: 12),
      TextField(controller: _password, obscureText: true, decoration: InputDecoration(labelText: context.t('Password'), prefixIcon: const Icon(Icons.lock_outline))),
      if (_error != null) ...[
        const SizedBox(height: 10),
        Text(_error!, style: const TextStyle(color: C.red600, fontWeight: FontWeight.w600)),
      ],
      const SizedBox(height: 18),
      PrimaryButton(_loading ? context.t('Creating account…') : context.t('Create account'), loading: _loading, onPressed: _submit),
      const SizedBox(height: 10),
      Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        Text(context.t('Already have an account?'), style: const TextStyle(color: C.slate500)),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(context.t('Sign in'), style: const TextStyle(color: C.brand600, fontWeight: FontWeight.w700)),
        ),
      ]),
    ]);
  }
}
