import 'package:material_ui/material_ui.dart';

import '../../core/theme.dart';
import '../../data/models.dart';
import '../../data/repo.dart';
import '../widgets.dart';

/// Bottom sheet to add a delivery address. Returns true if one was saved.
Future<bool> showAddAddressSheet(BuildContext context) async {
  final ok = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    builder: (_) => const _AddAddressSheet(),
  );
  return ok == true;
}

class _AddAddressSheet extends StatefulWidget {
  const _AddAddressSheet();
  @override
  State<_AddAddressSheet> createState() => _AddAddressSheetState();
}

class _AddAddressSheetState extends State<_AddAddressSheet> {
  final _label = TextEditingController(), _line = TextEditingController();
  bool _default = false, _saving = false;
  String? _error;

  Future<void> _save() async {
    if (_line.text.trim().isEmpty) return setState(() => _error = context.i18n.t('Required field'));
    setState(() => _saving = true);
    try {
      await Repo.addAddress(
        label: _label.text.trim().isEmpty ? context.i18n.t('Address') : _label.text.trim(),
        line: _line.text.trim(),
        isDefault: _default,
      );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      setState(() {
        _error = errorMessage(e);
        _saving = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + MediaQuery.of(context).viewInsets.bottom),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text(context.t('Add a new address'), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
        const SizedBox(height: 14),
        TextField(controller: _label, decoration: InputDecoration(labelText: context.t('Label (e.g. Home, Work)'))),
        const SizedBox(height: 10),
        TextField(controller: _line, autofocus: true, decoration: InputDecoration(labelText: context.t('Full address'))),
        CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          value: _default,
          activeColor: C.brand600,
          onChanged: (v) => setState(() => _default = v ?? false),
          title: Text(context.t('Set as default')),
          controlAffinity: ListTileControlAffinity.leading,
        ),
        if (_error != null) Text(context.t(_error!), style: const TextStyle(color: C.red600)),
        const SizedBox(height: 8),
        PrimaryButton(context.t('Save address'), loading: _saving, onPressed: _save),
      ]),
    );
  }
}

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  Map<String, dynamic>? _profile;
  List<Address> _addresses = [];
  final _phone = TextEditingController();
  bool _savingPhone = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final results = await Future.wait([Repo.myProfile(), Repo.addresses()]);
      setState(() {
        _profile = results[0] as Map<String, dynamic>?;
        _addresses = results[1] as List<Address>;
        _phone.text = (_profile?['phone'] as String?) ?? '';
      });
    } catch (e) {
      if (mounted) showError(context, context.i18n.t(errorMessage(e)));
    }
  }

  Future<void> _savePhone() async {
    if (_phone.text.trim().isEmpty) return showError(context, context.i18n.t('Phone number is required'));
    setState(() => _savingPhone = true);
    try {
      await Repo.updatePhone(_phone.text.trim());
      if (mounted) showToast(context, context.i18n.t('Saved'));
    } catch (e) {
      if (mounted) showError(context, context.i18n.t(errorMessage(e)));
    } finally {
      if (mounted) setState(() => _savingPhone = false);
    }
  }

  Future<void> _run(Future<void> Function() action) async {
    try {
      await action();
      await _load();
    } catch (e) {
      if (mounted) showError(context, context.i18n.t(errorMessage(e)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final name = (_profile?['full_name'] as String?) ?? '';
    return SafeArea(
      child: RefreshIndicator(
        color: C.brand600,
        onRefresh: _load,
        child: ListView(padding: const EdgeInsets.fromLTRB(16, 12, 16, 24), children: [
          Text(context.t('Settings'), style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: C.slate900)),
          const SizedBox(height: 16),
          CardBox(
            child: Row(children: [
              Container(
                width: 52,
                height: 52,
                alignment: Alignment.center,
                decoration: const BoxDecoration(shape: BoxShape.circle, gradient: LinearGradient(colors: [C.brand100, C.rose100])),
                child: Text(name.isNotEmpty ? name[0].toUpperCase() : '🙂', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: C.brand700)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(name, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
                  Text(sb.auth.currentUser?.email ?? '', style: const TextStyle(color: C.slate500, fontSize: 13)),
                ]),
              ),
            ]),
          ),
          const SizedBox(height: 12),
          CardBox(
            child: Row(children: [
              Expanded(child: Text(context.t('Language'), style: const TextStyle(fontWeight: FontWeight.w800))),
              const LanguageSwitcher(),
            ]),
          ),
          const SizedBox(height: 12),
          CardBox(
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Text(context.t('Phone number'), style: const TextStyle(fontWeight: FontWeight.w800)),
              const SizedBox(height: 10),
              TextField(controller: _phone, keyboardType: TextInputType.phone, decoration: const InputDecoration(prefixIcon: Icon(Icons.phone_outlined))),
              const SizedBox(height: 10),
              Align(alignment: Alignment.centerLeft, child: PrimaryButton(context.t('Save phone'), expand: false, loading: _savingPhone, onPressed: _savePhone)),
            ]),
          ),
          const SizedBox(height: 12),
          CardBox(
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Text(context.t('Delivery addresses'), style: const TextStyle(fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              if (_addresses.isEmpty) Text(context.t('No addresses saved yet.'), style: const TextStyle(color: C.slate400)),
              for (final a in _addresses)
                Container(
                  margin: const EdgeInsets.only(top: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), border: Border.all(color: a.isDefault ? C.brand200 : C.slate100)),
                  child: Row(children: [
                    Icon(Icons.location_on_outlined, color: a.isDefault ? C.brand600 : C.slate400),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text.rich(TextSpan(children: [
                          TextSpan(text: a.label ?? context.t('Address'), style: const TextStyle(fontWeight: FontWeight.w700)),
                          if (a.isDefault) TextSpan(text: '  (${context.t('default')})', style: const TextStyle(color: C.brand600, fontSize: 12)),
                        ])),
                        Text(a.line, style: const TextStyle(color: C.slate500, fontSize: 13)),
                      ]),
                    ),
                    PopupMenuButton<String>(
                      onSelected: (v) => v == 'default' ? _run(() => Repo.setDefaultAddress(a.id)) : _run(() => Repo.deleteAddress(a.id)),
                      itemBuilder: (_) => [
                        if (!a.isDefault) PopupMenuItem(value: 'default', child: Text(context.i18n.t('Set default'))),
                        PopupMenuItem(value: 'delete', child: Text(context.i18n.t('Delete'), style: const TextStyle(color: C.red600))),
                      ],
                    ),
                  ]),
                ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () async {
                    if (await showAddAddressSheet(context)) await _load();
                  },
                  icon: const Icon(Icons.add, color: C.brand600),
                  label: Text(context.t('Add a new address'), style: const TextStyle(color: C.brand600, fontWeight: FontWeight.w700)),
                ),
              ),
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
        ]),
      ),
    );
  }
}
