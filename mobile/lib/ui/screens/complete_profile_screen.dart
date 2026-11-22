import 'package:material_ui/material_ui.dart';

import '../../core/theme.dart';
import '../../data/repo.dart';
import '../auth_gate.dart';
import '../widgets.dart';

/// "Just one more thing" — phone and/or first delivery address (same rule as the website).
class CompleteProfileScreen extends StatefulWidget {
  final bool needsPhone, needsAddress;
  final Future<void> Function() onDone;
  const CompleteProfileScreen({super.key, required this.needsPhone, required this.needsAddress, required this.onDone});
  @override
  State<CompleteProfileScreen> createState() => _CompleteProfileScreenState();
}

class _CompleteProfileScreenState extends State<CompleteProfileScreen> {
  final _phone = TextEditingController(), _line = TextEditingController();
  late final _label = TextEditingController(text: context.i18n.t('Home'));
  bool _loading = false;
  String? _error;

  Future<void> _save() async {
    final i = context.i18n;
    if ((widget.needsPhone && _phone.text.trim().isEmpty) || (widget.needsAddress && _line.text.trim().isEmpty)) {
      return setState(() => _error = i.t('Required field'));
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      if (widget.needsPhone) await Repo.updatePhone(_phone.text.trim());
      if (widget.needsAddress) {
        await Repo.addAddress(label: _label.text.trim().isEmpty ? i.t('Home') : _label.text.trim(), line: _line.text.trim(), isDefault: true);
      }
      await widget.onDone();
    } catch (e) {
      if (mounted) setState(() => _error = i.t(errorMessage(e)));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final subtitle = widget.needsAddress && widget.needsPhone
        ? context.t('We need your phone number and a delivery address before you can order.')
        : widget.needsAddress
            ? context.t('Add a delivery address to start ordering.')
            : context.t('Add your phone number so drivers and restaurants can reach you.');
    return Scaffold(
      body: AuthBackground(
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: CardBox(
                padding: const EdgeInsets.all(24),
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  const Center(child: Logo(height: 56)),
                  const SizedBox(height: 12),
                  Text(context.t('Just one more thing'), style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: C.slate900)),
                  const SizedBox(height: 4),
                  Text(subtitle, style: const TextStyle(color: C.slate500)),
                  const SizedBox(height: 20),
                  if (widget.needsPhone) ...[
                    TextField(controller: _phone, keyboardType: TextInputType.phone, decoration: InputDecoration(labelText: context.t('Phone number'), prefixIcon: const Icon(Icons.phone_outlined))),
                    const SizedBox(height: 12),
                  ],
                  if (widget.needsAddress) ...[
                    TextField(controller: _label, decoration: InputDecoration(labelText: context.t('Label'), prefixIcon: const Icon(Icons.bookmark_outline))),
                    const SizedBox(height: 12),
                    TextField(controller: _line, decoration: InputDecoration(labelText: context.t('Delivery address'), prefixIcon: const Icon(Icons.location_on_outlined))),
                    const SizedBox(height: 12),
                  ],
                  if (_error != null) Text(_error!, style: const TextStyle(color: C.red600, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  PrimaryButton(context.t('Continue'), loading: _loading, onPressed: _save),
                  TextButton(onPressed: () => sb.auth.signOut(), child: Text(context.t('Sign out'), style: const TextStyle(color: C.slate500))),
                ]),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
