import 'dart:convert';
import 'dart:io';

import 'package:material_ui/material_ui.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/env.dart';
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
      Align(
        alignment: Alignment.centerRight,
        child: TextButton(
          onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ForgotPasswordScreen())),
          child: Text(context.t('Forgot password?'), style: const TextStyle(color: C.brand600, fontSize: 13)),
        ),
      ),
      const SizedBox(height: 8),
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

// ---------------------------------------------------------------------------
// Forgot password
// ---------------------------------------------------------------------------

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});
  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _email = TextEditingController();
  final _code = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _loading = false, _obscure = true;
  // 'email' | 'code' | 'done'
  String _step = 'email';
  String? _error;

  Future<void> _sendCode() async {
    final email = _email.text.trim();
    if (email.isEmpty) return setState(() => _error = context.t('Required field'));
    setState(() { _loading = true; _error = null; });
    try {
      if (Env.appUrl.isNotEmpty) {
        final client = HttpClient();
        final req = await client.postUrl(Uri.parse('${Env.appUrl}/api/forgot-password'));
        req.headers.set(HttpHeaders.contentTypeHeader, 'application/json');
        req.write(jsonEncode({'email': email}));
        final resp = await req.close();
        final body = await resp.transform(utf8.decoder).join();
        client.close();
        if (resp.statusCode != 200) {
          final decoded = jsonDecode(body);
          throw Exception(decoded['error'] ?? 'Failed to send code');
        }
      } else {
        await sb.auth.resetPasswordForEmail(email);
      }
      if (mounted) setState(() => _step = 'code');
    } catch (e) {
      if (mounted) setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _resetPassword() async {
    if (_password.text != _confirm.text) return setState(() => _error = context.t('Passwords do not match.'));
    if (_password.text.length < 6) return setState(() => _error = context.t('Password must be at least 6 characters'));
    setState(() { _loading = true; _error = null; });
    try {
      final verifyRes = await sb.auth.verifyOTP(
        email: _email.text.trim(),
        token: _code.text.trim(),
        type: OtpType.recovery,
      );
      if (verifyRes.session == null) throw Exception(context.t('Invalid or expired code. Please request a new one.'));
      await sb.auth.updateUser(UserAttributes(password: _password.text));
      if (mounted) setState(() => _step = 'done');
    } catch (e) {
      if (mounted) setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return _AuthCard(children: [
      Align(
        alignment: Alignment.centerLeft,
        child: IconButton(
          onPressed: () => _step == 'code'
              ? setState(() { _step = 'email'; _error = null; })
              : Navigator.pop(context),
          icon: const Icon(Icons.arrow_back),
        ),
      ),
      const Center(child: Logo(height: 64)),
      const SizedBox(height: 12),

      if (_step == 'done') ...[
        const Center(child: Text('✅', style: TextStyle(fontSize: 48))),
        const SizedBox(height: 12),
        _gradientTitle(context.t('Password updated!')),
        const SizedBox(height: 8),
        Text(context.t('Your password has been changed successfully. Redirecting you to sign in…'), style: const TextStyle(color: C.slate500)),
        const SizedBox(height: 16),
        TextButton(onPressed: () => Navigator.pop(context), child: Text('← ${context.t('Back to sign in')}', style: const TextStyle(color: C.brand600))),

      ] else if (_step == 'email') ...[
        _gradientTitle(context.t('Forgot password?')),
        const SizedBox(height: 6),
        Text(context.t("Enter your email and we'll send you a 6-digit code."), style: const TextStyle(color: C.slate500)),
        const SizedBox(height: 20),
        TextField(
          controller: _email,
          keyboardType: TextInputType.emailAddress,
          onSubmitted: (_) => _sendCode(),
          decoration: InputDecoration(labelText: context.t('Email'), prefixIcon: const Icon(Icons.mail_outline)),
        ),
        if (_error != null) ...[const SizedBox(height: 10), Text(_error!, style: const TextStyle(color: C.red600, fontWeight: FontWeight.w600))],
        const SizedBox(height: 18),
        PrimaryButton(_loading ? context.t('Sending…') : context.t('Send code'), loading: _loading, onPressed: _sendCode),
        const SizedBox(height: 10),
        TextButton(onPressed: () => Navigator.pop(context), child: Text('← ${context.t('Back to sign in')}', style: const TextStyle(color: C.brand600))),

      ] else ...[
        _gradientTitle(context.t('Check your email')),
        const SizedBox(height: 6),
        Text('${context.t('We sent a 6-digit code to')} ${_email.text.trim()}.', style: const TextStyle(color: C.slate500)),
        const SizedBox(height: 20),
        TextField(
          controller: _code,
          keyboardType: TextInputType.number,
          maxLength: 6,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900, letterSpacing: 12),
          decoration: InputDecoration(labelText: context.t('6-digit code'), counterText: '', prefixIcon: const Icon(Icons.pin_outlined)),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _password,
          obscureText: _obscure,
          decoration: InputDecoration(
            labelText: context.t('New password'),
            prefixIcon: const Icon(Icons.lock_outline),
            suffixIcon: IconButton(icon: Icon(_obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined), onPressed: () => setState(() => _obscure = !_obscure)),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _confirm,
          obscureText: _obscure,
          onSubmitted: (_) => _resetPassword(),
          decoration: InputDecoration(labelText: context.t('Confirm password'), prefixIcon: const Icon(Icons.lock_outline)),
        ),
        if (_error != null) ...[const SizedBox(height: 10), Text(_error!, style: const TextStyle(color: C.red600, fontWeight: FontWeight.w600))],
        const SizedBox(height: 18),
        PrimaryButton(_loading ? context.t('Saving…') : context.t('Set new password'), loading: _loading, onPressed: _resetPassword),
        const SizedBox(height: 8),
        TextButton(
          onPressed: () => setState(() { _step = 'email'; _error = null; _code.clear(); }),
          child: Text(context.t('try again'), style: const TextStyle(color: C.brand600, fontSize: 13)),
        ),
      ],
    ]);
  }
}
