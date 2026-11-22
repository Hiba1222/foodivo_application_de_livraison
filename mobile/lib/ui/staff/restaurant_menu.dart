import 'package:material_ui/material_ui.dart';

import '../../core/money.dart';
import '../../core/theme.dart';
import '../../data/models.dart';
import '../../data/repo.dart';
import '../../data/staff_repo.dart';
import '../widgets.dart';
import 'staff_widgets.dart';

/// Offer info for a raw menu_items row (same rules as the customer app).
ActiveOffer? _offerOf(Map<String, dynamic> row) => MenuItem.fromJson({...row, 'menu_option_groups': null}).offer;

int _groupCount(Map<String, dynamic> row) => ((row['menu_option_groups'] as List?)?.firstOrNull?['count'] as num?)?.toInt() ?? 0;

// =====================================================================
// Menu list
// =====================================================================

class RestaurantMenuScreen extends StatefulWidget {
  final Map<String, dynamic> restaurant;
  const RestaurantMenuScreen({super.key, required this.restaurant});
  @override
  State<RestaurantMenuScreen> createState() => _RestaurantMenuScreenState();
}

class _RestaurantMenuScreenState extends State<RestaurantMenuScreen> {
  List<Map<String, dynamic>> _cats = [], _items = [];
  bool _loaded = false;
  String? _error;
  final _toggling = <String>{};

  String get _rid => widget.restaurant['id'];

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    try {
      final (cats, items) = await RestaurantRepo.menu(_rid);
      if (mounted) setState(() => (_cats = cats, _items = items, _loaded = true, _error = null));
    } catch (e) {
      if (mounted) setState(() => (_error = errorMessage(e), _loaded = true));
    }
  }

  Future<void> _addCategory() async {
    final ctrl = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(c.t('Add category')),
        content: TextField(controller: ctrl, autofocus: true, decoration: InputDecoration(hintText: c.t('e.g. Burgers'))),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: Text(c.t('Cancel'))),
          TextButton(onPressed: () => Navigator.pop(c, ctrl.text.trim()), child: Text(c.t('Add'), style: const TextStyle(fontWeight: FontWeight.w800))),
        ],
      ),
    );
    if (name == null || name.isEmpty) return;
    try {
      await RestaurantRepo.addCategory(_rid, name);
      await _refresh();
    } catch (e) {
      if (mounted) showError(context, errorMessage(e));
    }
  }

  Future<void> _addItem() async {
    final id = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => _AddItemSheet(restaurantId: _rid, categories: _cats),
    );
    if (id == null || !mounted) return;
    await _refresh();
    if (mounted) await _openEditor(id, isNew: true);
  }

  Future<void> _openEditor(String itemId, {bool isNew = false}) async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => MenuItemEditor(restaurantId: _rid, itemId: itemId, isNew: isNew)));
    _refresh();
  }

  Future<void> _toggle(Map<String, dynamic> item) async {
    setState(() => _toggling.add(item['id']));
    try {
      await RestaurantRepo.updateItem(item['id'], {'is_available': !(item['is_available'] == true)});
      await _refresh();
    } catch (e) {
      if (mounted) showError(context, errorMessage(e));
    } finally {
      if (mounted) setState(() => _toggling.remove(item['id']));
    }
  }

  @override
  Widget build(BuildContext context) {
    // Group items by category (categories in their order, then "No category").
    final sections = <(String, List<Map<String, dynamic>>)>[
      for (final c in _cats) (c['name'] as String, _items.where((i) => i['category_id'] == c['id']).toList()),
      (context.t('No category'), _items.where((i) => i['category_id'] == null || !_cats.any((c) => c['id'] == i['category_id'])).toList()),
    ].where((s) => s.$2.isNotEmpty).toList();

    var n = 0;
    return SafeArea(
      child: RefreshIndicator(
        color: C.brand600,
        onRefresh: _refresh,
        child: ListView(padding: const EdgeInsets.fromLTRB(16, 12, 16, 24), children: [
          PageHeader(context.t('Menu'), subtitle: context.t('Tap an item to edit its photo, price, offer and options. Use the switch to hide it instantly.')),
          Row(children: [
            Expanded(child: PrimaryButton(context.t('Add menu item'), onPressed: _addItem, trailing: const Icon(Icons.add, color: Colors.white, size: 18))),
            const SizedBox(width: 10),
            ActionChipButton(context.t('Add category'), bg: C.slate800, icon: Icons.create_new_folder_outlined, onTap: _addCategory),
          ]),
          const SizedBox(height: 16),
          if (!_loaded)
            const Padding(padding: EdgeInsets.all(40), child: Center(child: CircularProgressIndicator(color: C.brand600)))
          else if (_error != null && _items.isEmpty)
            EmptyState(emoji: '📡', title: context.t(_error!), action: PrimaryButton(context.t('Retry'), expand: false, onPressed: _refresh))
          else if (_items.isEmpty)
            EmptyState(emoji: '🍔', title: context.t('No menu items yet — add your first one above.'))
          else
            for (final s in sections) ...[
              Padding(
                padding: const EdgeInsets.only(top: 8, bottom: 8),
                child: Text('${s.$1}  ·  ${s.$2.length}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: C.slate500, letterSpacing: 0.5)),
              ),
              for (final item in s.$2) Padding(padding: const EdgeInsets.only(bottom: 10), child: FadeInUp(index: n++, child: _itemRow(item))),
            ],
        ]),
      ),
    );
  }

  Widget _itemRow(Map<String, dynamic> item) {
    final available = item['is_available'] == true;
    final offer = _offerOf(item);
    final price = (item['price_cents'] as num).toInt();
    final groups = _groupCount(item);
    return Pressable(
      onTap: () => _openEditor(item['id']),
      child: CardBox(
        padding: const EdgeInsets.all(10),
        child: Opacity(
          opacity: available ? 1 : 0.55,
          child: Row(children: [
            ClipRRect(borderRadius: BorderRadius.circular(12), child: SizedBox(width: 64, height: 64, child: NetImage(item['image_url']))),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(item['name'] ?? '', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800, color: C.slate900)),
                const SizedBox(height: 3),
                if (offer != null && offer.percentOff > 0)
                  Wrap(crossAxisAlignment: WrapCrossAlignment.center, spacing: 6, children: [
                    Text(formatPrice(price), style: const TextStyle(fontSize: 12, color: C.slate400, decoration: TextDecoration.lineThrough)),
                    Text(formatPrice(offer.priceCents), style: const TextStyle(fontWeight: FontWeight.w900, color: C.rose600)),
                    Pill('-${offer.percentOff}%', bg: C.rose600, fg: Colors.white, fontSize: 10),
                  ])
                else
                  Text(formatPrice(price), style: const TextStyle(fontWeight: FontWeight.w700, color: C.slate700)),
                const SizedBox(height: 4),
                Wrap(spacing: 6, runSpacing: 4, children: [
                  Pill(groups > 0 ? context.t(groups == 1 ? '{n} group' : '{n} groups', {'n': groups}) : '+ ${context.t('Customize')}', bg: C.brand50, fg: C.brand700, fontSize: 10),
                  if (offer?.featured == true) Pill('⭐ ${context.t('Featured')}', bg: C.amber100, fg: C.amber800, fontSize: 10),
                ]),
              ]),
            ),
            Column(children: [
              Switch(value: available, activeThumbColor: C.green600, onChanged: _toggling.contains(item['id']) ? null : (_) => _toggle(item)),
              Text(context.t(available ? 'Available' : 'Hidden'), style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: available ? C.green700 : C.slate500)),
            ]),
          ]),
        ),
      ),
    );
  }
}

class _AddItemSheet extends StatefulWidget {
  final String restaurantId;
  final List<Map<String, dynamic>> categories;
  const _AddItemSheet({required this.restaurantId, required this.categories});
  @override
  State<_AddItemSheet> createState() => _AddItemSheetState();
}

class _AddItemSheetState extends State<_AddItemSheet> {
  final _name = TextEditingController(), _price = TextEditingController(), _desc = TextEditingController();
  String? _cat;
  bool _busy = false;
  String? _error;

  Future<void> _save() async {
    final i = context.i18n;
    if (_name.text.trim().isEmpty || _price.text.trim().isEmpty) return setState(() => _error = i.t('Required field'));
    setState(() => _busy = true);
    try {
      final id = await RestaurantRepo.addItem(
        widget.restaurantId,
        name: _name.text.trim(),
        price: parsePrice(_price.text),
        categoryId: _cat,
        description: _desc.text.trim().isEmpty ? null : _desc.text.trim(),
      );
      if (mounted) Navigator.pop(context, id);
    } catch (e) {
      if (mounted) setState(() => (_error = errorMessage(e), _busy = false));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(context.t('Add menu item'), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
          const SizedBox(height: 14),
          TextField(controller: _name, autofocus: true, decoration: InputDecoration(labelText: context.t('Item name'))),
          const SizedBox(height: 10),
          PriceField(_price, label: context.t('Price (TND)')),
          const SizedBox(height: 10),
          _CategoryDropdown(categories: widget.categories, value: _cat, onChanged: (v) => setState(() => _cat = v)),
          const SizedBox(height: 10),
          TextField(controller: _desc, maxLines: 2, decoration: InputDecoration(labelText: context.t('Description (optional)'))),
          if (_error != null) ...[const SizedBox(height: 8), Text(context.t(_error!), style: const TextStyle(color: C.red600))],
          const SizedBox(height: 14),
          PrimaryButton('${context.t('Add item & set up options')} →', loading: _busy, onPressed: _save),
        ]),
      ),
    );
  }
}

class _CategoryDropdown extends StatelessWidget {
  final List<Map<String, dynamic>> categories;
  final String? value;
  final ValueChanged<String?> onChanged;
  const _CategoryDropdown({required this.categories, required this.value, required this.onChanged});
  @override
  Widget build(BuildContext context) => DropdownButtonFormField<String?>(
        initialValue: categories.any((c) => c['id'] == value) ? value : null,
        decoration: InputDecoration(labelText: context.t('Category')),
        items: [
          DropdownMenuItem(value: null, child: Text(context.t('No category'))),
          for (final c in categories) DropdownMenuItem(value: c['id'] as String, child: Text(c['name'] ?? '')),
        ],
        onChanged: onChanged,
      );
}

// =====================================================================
// Item editor
// =====================================================================

class MenuItemEditor extends StatefulWidget {
  final String restaurantId, itemId;
  final bool isNew;
  const MenuItemEditor({super.key, required this.restaurantId, required this.itemId, this.isNew = false});
  @override
  State<MenuItemEditor> createState() => _MenuItemEditorState();
}

class _MenuItemEditorState extends State<MenuItemEditor> {
  Map<String, dynamic>? _item;
  List<Map<String, dynamic>> _cats = [], _copySources = [];
  bool _loaded = false;

  // Details
  final _name = TextEditingController(), _price = TextEditingController(), _desc = TextEditingController();
  String? _cat;
  bool _savingDetails = false;

  // Offer
  final _offerPrice = TextEditingController(), _offerLabel = TextEditingController();
  DateTime? _offerEnds;
  bool _featured = false, _savingOffer = false;

  @override
  void initState() {
    super.initState();
    _load(initial: true);
  }

  Future<void> _load({bool initial = false}) async {
    try {
      final r = await Future.wait([
        RestaurantRepo.item(widget.restaurantId, widget.itemId),
        RestaurantRepo.menu(widget.restaurantId),
        RestaurantRepo.otherItemsWithOptions(widget.restaurantId, widget.itemId),
      ]);
      final item = r[0] as Map<String, dynamic>?;
      if (!mounted) return;
      setState(() {
        _item = item;
        _cats = (r[1] as (List<Map<String, dynamic>>, List<Map<String, dynamic>>)).$1;
        _copySources = r[2] as List<Map<String, dynamic>>;
        _loaded = true;
        if (initial && item != null) {
          _name.text = item['name'] ?? '';
          _price.text = priceInput((item['price_cents'] as num).toInt());
          _desc.text = item['description'] ?? '';
          _cat = item['category_id'];
          _offerPrice.text = priceText((item['offer_price_cents'] as num?)?.toInt()) ?? '';
          _offerLabel.text = item['offer_label'] ?? '';
          _offerEnds = item['offer_ends_at'] == null ? null : DateTime.parse(item['offer_ends_at']).toLocal();
          _featured = item['is_featured'] == true;
        }
      });
    } catch (e) {
      if (mounted) {
        setState(() => _loaded = true);
        showError(context, errorMessage(e));
      }
    }
  }

  /// Runs a write, then reloads the item. Shows the error if it fails.
  Future<void> _run(Future<void> Function() action, {String? toast}) async {
    try {
      await action();
      await _load();
      if (toast != null && mounted) showToast(context, context.i18n.t(toast));
    } catch (e) {
      if (mounted) showError(context, errorMessage(e));
    }
  }

  Future<void> _saveDetails() async {
    if (_name.text.trim().isEmpty) return showError(context, context.i18n.t('Required field'));
    setState(() => _savingDetails = true);
    await _run(
      () => RestaurantRepo.updateItem(widget.itemId, {
        'name': _name.text.trim(),
        'description': _desc.text.trim().isEmpty ? null : _desc.text.trim(),
        'category_id': _cat,
        'price_cents': parsePrice(_price.text),
      }),
      toast: 'Saved',
    );
    if (mounted) setState(() => _savingDetails = false);
  }

  Future<void> _saveOffer() async {
    final i = context.i18n;
    final price = (_item!['price_cents'] as num).toInt();
    final raw = _offerPrice.text.trim();
    final offer = raw.isEmpty ? null : parsePrice(raw);
    if (offer != null && (offer <= 0 || offer >= price)) return showError(context, i.t('The offer price must be lower than the normal price.'));
    setState(() => _savingOffer = true);
    await _run(() => RestaurantRepo.setOffer(widget.itemId, offerPrice: offer, label: _offerLabel.text, endsAt: _offerEnds, featured: _featured), toast: 'Saved');
    if (mounted) setState(() => _savingOffer = false);
  }

  Future<void> _clearOffer() async {
    await _run(() => RestaurantRepo.clearOffer(widget.itemId), toast: 'Saved');
    if (!mounted) return;
    setState(() {
      _offerPrice.clear();
      _offerLabel.clear();
      _offerEnds = null;
      _featured = false;
    });
  }

  Future<void> _pickEnd() async {
    final now = DateTime.now();
    final d = await showDatePicker(context: context, firstDate: now, lastDate: now.add(const Duration(days: 365)), initialDate: _offerEnds ?? now.add(const Duration(days: 7)));
    if (d == null || !mounted) return;
    final t = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(_offerEnds ?? DateTime(d.year, d.month, d.day, 23, 59)));
    if (!mounted) return;
    setState(() => _offerEnds = DateTime(d.year, d.month, d.day, t?.hour ?? 23, t?.minute ?? 59));
  }

  Future<void> _delete() async {
    if (!await confirm(context, context.i18n.t('Delete this item from your menu?'))) return;
    try {
      await RestaurantRepo.deleteItem(widget.itemId);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) showError(context, errorMessage(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final item = _item;
    return Scaffold(
      appBar: AppBar(
        title: Text(item?['name'] ?? context.t('Menu')),
        actions: [if (item != null) IconButton(onPressed: _delete, icon: const Icon(Icons.delete_outline, color: C.red600), tooltip: context.t('Delete'))],
      ),
      body: !_loaded
          ? const Center(child: CircularProgressIndicator(color: C.brand600))
          : item == null
              ? EmptyState(emoji: '🤷', title: context.t('Item not found.'))
              : _body(item),
    );
  }

  Widget _body(Map<String, dynamic> item) {
    final groupsRaw = [...((item['menu_option_groups'] as List?) ?? []).cast<Map<String, dynamic>>()]
      ..sort((a, b) {
        final s = ((a['sort_order'] as num?) ?? 0).compareTo((b['sort_order'] as num?) ?? 0);
        return s != 0 ? s : (a['created_at'] ?? '').toString().compareTo((b['created_at'] ?? '').toString());
      });
    final price = (item['price_cents'] as num).toInt();
    final offer = _offerOf(item);

    return ListView(padding: const EdgeInsets.fromLTRB(16, 12, 16, 32), children: [
      if (widget.isNew)
        Container(
          margin: const EdgeInsets.only(bottom: 14),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: const Color(0xFFF0FDF4), borderRadius: BorderRadius.circular(14), border: Border.all(color: const Color(0xFFBBF7D0))),
          child: Text(
            '✅ ${item['name']} ${context.t('was added to your menu. Now set up how customers can customize it — pick a quick start below, or skip this if the item has no options.')}',
            style: const TextStyle(color: Color(0xFF166534)),
          ),
        ),

      // ---------- Details ----------
      _sectionTitle(context.t('Item details')),
      CardBox(
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          PhotoPicker(
            currentUrl: item['image_url'],
            storagePath: 'restaurants/${widget.restaurantId}/items/${item['id']}.jpg',
            table: 'menu_items',
            column: 'image_url',
            rowId: item['id'],
          ),
          const SizedBox(height: 14),
          TextField(controller: _name, decoration: InputDecoration(labelText: context.t('Item name'))),
          const SizedBox(height: 10),
          PriceField(_price, label: context.t('Base price (TND)')),
          const SizedBox(height: 10),
          _CategoryDropdown(categories: _cats, value: _cat, onChanged: (v) => setState(() => _cat = v)),
          const SizedBox(height: 10),
          TextField(controller: _desc, maxLines: 2, decoration: InputDecoration(labelText: context.t('Description (optional)'))),
          const SizedBox(height: 14),
          PrimaryButton(context.t('Save details'), loading: _savingDetails, onPressed: _saveDetails),
        ]),
      ),

      // ---------- Offer ----------
      _sectionTitle('🔥 ${context.t('Discount & special offer')}'),
      CardBox(
        borderColor: offer != null ? C.rose300 : null,
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          if (offer != null && offer.percentOff > 0)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(children: [
                DiscountBadge(offer.percentOff, size: 46),
                const SizedBox(width: 12),
                Expanded(
                  child: Text('${formatPrice(price)} → ${formatPrice(offer.priceCents)}', style: const TextStyle(fontWeight: FontWeight.w900, color: C.rose600)),
                ),
              ]),
            ),
          PriceField(_offerPrice, label: context.t('Offer price (TND)')),
          const SizedBox(height: 4),
          Text(context.t('Leave empty for no discount. Must be lower than {price}.', {'price': formatPrice(price)}), style: const TextStyle(fontSize: 12, color: C.slate500)),
          const SizedBox(height: 10),
          TextField(controller: _offerLabel, maxLength: 40, decoration: InputDecoration(labelText: context.t('Offer label (optional)'), hintText: context.t('e.g. Ramadan special'))),
          Row(children: [
            Expanded(
              child: Text(
                _offerEnds == null ? context.t('No end date') : '${context.t('Ends')}: ${context.i18n.dateTime(_offerEnds!.toUtc().toIso8601String())}',
                style: const TextStyle(fontWeight: FontWeight.w600, color: C.slate700),
              ),
            ),
            TextButton(onPressed: _pickEnd, child: Text(context.t(_offerEnds == null ? 'Set end date' : 'Change'))),
            if (_offerEnds != null) IconButton(onPressed: () => setState(() => _offerEnds = null), icon: const Icon(Icons.close, size: 18)),
          ]),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: _featured,
            activeThumbColor: C.amber500,
            onChanged: (v) => setState(() => _featured = v),
            title: Text('⭐ ${context.t('Featured')}', style: const TextStyle(fontWeight: FontWeight.w700)),
            subtitle: Text(context.t('Show this item in the Special offers section at the top of your menu.')),
          ),
          const SizedBox(height: 6),
          Row(children: [
            Expanded(child: PrimaryButton(context.t('Save offer'), loading: _savingOffer, onPressed: _saveOffer)),
            if (offer != null || item['offer_price_cents'] != null) ...[
              const SizedBox(width: 10),
              ActionChipButton(context.t('Remove offer'), bg: const Color(0xFFFEF2F2), fg: const Color(0xFFB91C1C), onTap: _clearOffer),
            ],
          ]),
        ]),
      ),

      // ---------- Customization ----------
      _sectionTitle(context.t('Customization')),
      Text(
        context.t('Let customers build their meal: choose the bread, remove or double ingredients, add paid extras. The price updates automatically as they choose, and every choice shows on the order ticket.'),
        style: const TextStyle(color: C.slate500, fontSize: 13),
      ),
      const SizedBox(height: 12),
      CardBox(
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(context.t('Quick start'), style: const TextStyle(fontWeight: FontWeight.w800)),
          Text(context.t('Adds a ready-made group with common options. Rename, re-price or delete anything after.'), style: const TextStyle(fontSize: 12, color: C.slate500)),
          const SizedBox(height: 10),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final tpl in optionTemplates)
              Pressable(
                onTap: () => _run(() => RestaurantRepo.addGroupFromTemplate(widget.itemId, tpl, context.i18n.t)),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                  decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), border: Border.all(color: C.slate200)),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('+ ${context.t(tpl.label)}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
                    Text(context.t(tpl.hint), style: const TextStyle(fontSize: 11, color: C.slate500)),
                  ]),
                ),
              ),
          ]),
          if (_copySources.isNotEmpty) ...[
            const Divider(height: 24),
            Row(children: [
              Expanded(child: Text(context.t('Or copy all options from'), style: const TextStyle(fontSize: 13, color: C.slate700))),
              PopupMenuButton<String>(
                onSelected: (src) => _run(() => RestaurantRepo.copyGroups(widget.itemId, src)),
                itemBuilder: (_) => [for (final s in _copySources) PopupMenuItem(value: s['id'] as String, child: Text(s['name'] ?? ''))],
                child: Pill('${context.t('Copy')} ▾', bg: C.slate100, fg: C.slate800, fontSize: 13),
              ),
            ]),
          ],
        ]),
      ),
      const SizedBox(height: 12),
      if (groupsRaw.isEmpty)
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(18), border: Border.all(color: C.slate200, width: 2)),
          child: Text(context.t('No customization yet. Customers will add this item as-is.'), textAlign: TextAlign.center, style: const TextStyle(color: C.slate400)),
        ),
      for (var i = 0; i < groupsRaw.length; i++)
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: _GroupEditor(
            key: ValueKey(groupsRaw[i]['id']),
            itemId: widget.itemId,
            group: groupsRaw[i],
            isFirst: i == 0,
            isLast: i == groupsRaw.length - 1,
            run: _run,
          ),
        ),
      _AddGroupCard(itemId: widget.itemId, run: _run),
    ]);
  }

  Widget _sectionTitle(String text) => Padding(
        padding: const EdgeInsets.only(top: 18, bottom: 10),
        child: Text(text, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: C.slate900)),
      );
}

typedef _Runner = Future<void> Function(Future<void> Function() action, {String? toast});

class _GroupEditor extends StatefulWidget {
  final String itemId;
  final Map<String, dynamic> group;
  final bool isFirst, isLast;
  final _Runner run;
  const _GroupEditor({super.key, required this.itemId, required this.group, required this.isFirst, required this.isLast, required this.run});
  @override
  State<_GroupEditor> createState() => _GroupEditorState();
}

class _GroupEditorState extends State<_GroupEditor> {
  bool _settingsOpen = false;
  late final _name = TextEditingController(text: widget.group['name'] ?? '');
  late final _min = TextEditingController(text: '${widget.group['min_select'] ?? 0}');
  late final _max = TextEditingController(text: widget.group['max_select'] == null ? '' : '${widget.group['max_select']}');
  final _newName = TextEditingController(), _newPrice = TextEditingController();

  Map<String, dynamic> get g => widget.group;
  bool get _ingredients => g['kind'] == 'ingredients';
  String get _id => g['id'];

  Future<void> _addOption() async {
    final name = _newName.text.trim();
    if (name.isEmpty) return showError(context, context.i18n.t('Option name is required'));
    await widget.run(() => RestaurantRepo.addOption(_id, name, parsePrice(_newPrice.text)));
    _newName.clear();
    _newPrice.clear();
  }

  Future<void> _editOption(Map<String, dynamic> o) async {
    final name = TextEditingController(text: o['name'] ?? '');
    final price = TextEditingController(text: priceInput((o['price_cents'] as num).toInt()));
    var flag = _ingredients ? o['allow_extra'] != false : o['is_default'] == true;
    final result = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (c) => StatefulBuilder(
        builder: (c, setS) => Padding(
          padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + MediaQuery.of(c).viewInsets.bottom),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text(c.t('Edit'), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
            const SizedBox(height: 14),
            TextField(controller: name, decoration: InputDecoration(labelText: c.t('Name'))),
            const SizedBox(height: 10),
            PriceField(price, label: _ingredients ? '${c.t('Extra')} +' : '+'),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              value: flag,
              activeColor: C.brand600,
              controlAffinity: ListTileControlAffinity.leading,
              onChanged: (v) => setS(() => flag = v ?? false),
              title: Text(c.t(_ingredients ? 'Can be extra' : 'Pre-selected')),
            ),
            const SizedBox(height: 8),
            Row(children: [
              ActionChipButton(c.t('Delete'), bg: const Color(0xFFFEF2F2), fg: const Color(0xFFB91C1C), icon: Icons.delete_outline, onTap: () => Navigator.pop(c, 'delete')),
              const SizedBox(width: 10),
              Expanded(child: PrimaryButton(c.t('Save'), onPressed: () => Navigator.pop(c, 'save'))),
            ]),
          ]),
        ),
      ),
    );
    if (result == 'save') {
      await widget.run(() => RestaurantRepo.updateOption(o['id'], {
            'name': name.text.trim().isEmpty ? 'Option' : name.text.trim(),
            'price_cents': parsePrice(price.text),
            if (_ingredients) 'allow_extra': flag else 'is_default': flag,
          }));
    } else if (result == 'delete') {
      await widget.run(() => RestaurantRepo.deleteOption(o['id']));
    }
  }

  @override
  Widget build(BuildContext context) {
    final options = [...((g['menu_options'] as List?) ?? []).cast<Map<String, dynamic>>()]
      ..sort((a, b) => ((a['sort_order'] as num?) ?? 0).compareTo((b['sort_order'] as num?) ?? 0));
    final required = !_ingredients && ((g['min_select'] as num?) ?? 0) > 0;
    final rule = OptionGroup.fromJson({...g, 'menu_options': const []}).ruleText(context.i18n);

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18), border: Border.all(color: C.slate200), boxShadow: Shadows.soft),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        // Header
        Container(
          color: C.slate50,
          padding: const EdgeInsets.fromLTRB(14, 10, 4, 10),
          child: Row(children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Wrap(spacing: 6, runSpacing: 4, crossAxisAlignment: WrapCrossAlignment.center, children: [
                  Text(g['name'] ?? '', style: const TextStyle(fontWeight: FontWeight.w900, color: C.slate900)),
                  Pill(context.t(_ingredients ? 'Ingredients' : 'Choice'), bg: _ingredients ? C.amber100 : C.blue100, fg: _ingredients ? C.amber800 : const Color(0xFF1E40AF), fontSize: 10),
                  if (required)
                    Pill(context.t('Required'), bg: C.slate900, fg: Colors.white, fontSize: 10)
                  else if (!_ingredients)
                    Pill(context.t('Optional'), bg: C.slate200, fg: C.slate600, fontSize: 10),
                ]),
                const SizedBox(height: 2),
                Text(rule, style: const TextStyle(fontSize: 12, color: C.slate500)),
              ]),
            ),
            IconButton(
              visualDensity: VisualDensity.compact,
              onPressed: widget.isFirst ? null : () => widget.run(() => RestaurantRepo.moveGroup(widget.itemId, _id, -1)),
              icon: const Icon(Icons.arrow_upward, size: 18),
            ),
            IconButton(
              visualDensity: VisualDensity.compact,
              onPressed: widget.isLast ? null : () => widget.run(() => RestaurantRepo.moveGroup(widget.itemId, _id, 1)),
              icon: const Icon(Icons.arrow_downward, size: 18),
            ),
            PopupMenuButton<String>(
              onSelected: (v) async {
                if (v == 'settings') setState(() => _settingsOpen = !_settingsOpen);
                if (v == 'delete' && await confirm(context, context.i18n.t('Delete group'))) {
                  await widget.run(() => RestaurantRepo.deleteGroup(_id));
                }
              },
              itemBuilder: (_) => [
                PopupMenuItem(value: 'settings', child: Text(context.i18n.t('Group settings'))),
                PopupMenuItem(value: 'delete', child: Text(context.i18n.t('Delete group'), style: const TextStyle(color: C.red600))),
              ],
            ),
          ]),
        ),

        // Group settings
        AnimatedSize(
          duration: const Duration(milliseconds: 250),
          child: !_settingsOpen
              ? const SizedBox(width: double.infinity)
              : Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    TextField(controller: _name, decoration: InputDecoration(labelText: context.t('Name'))),
                    if (!_ingredients) ...[
                      const SizedBox(height: 10),
                      Row(children: [
                        Expanded(child: TextField(controller: _min, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: context.t('Min picks')))),
                        const SizedBox(width: 10),
                        Expanded(child: TextField(controller: _max, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: context.t('Max picks (blank = any)')))),
                      ]),
                      const SizedBox(height: 6),
                      Text(context.t('Min 1 makes the group required. Min 1 + max 1 = pick exactly one (e.g. bread).'), style: const TextStyle(fontSize: 12, color: C.slate400)),
                    ],
                    const SizedBox(height: 10),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: ActionChipButton(context.t('Save'), bg: C.slate800, onTap: () async {
                        await widget.run(
                          () => RestaurantRepo.updateGroup(_id,
                              name: _name.text.trim(), kind: g['kind'], min: int.tryParse(_min.text.trim()), max: int.tryParse(_max.text.trim())),
                          toast: 'Saved',
                        );
                        if (mounted) setState(() => _settingsOpen = false);
                      }),
                    ),
                  ]),
                ),
        ),

        // Options
        if (options.isEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 4),
            child: Text(context.t("No options yet. Customers won't see this group until you add one."), style: const TextStyle(fontSize: 12, color: C.amber800)),
          ),
        for (final o in options) _optionRow(o),

        // Add option
        Container(
          color: C.slate50,
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
          child: Row(children: [
            Expanded(
              flex: 3,
              child: TextField(
                controller: _newName,
                decoration: InputDecoration(isDense: true, hintText: context.t(_ingredients ? 'Ingredient, e.g. Onion' : 'Option, e.g. Bacon')),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              flex: 2,
              child: TextField(
                controller: _newPrice,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(isDense: true, hintText: '0.000', suffixText: 'TND'),
              ),
            ),
            const SizedBox(width: 8),
            Pressable(
              onTap: _addOption,
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(gradient: C.buttonGradient, borderRadius: BorderRadius.circular(12), boxShadow: Shadows.glow),
                child: const Icon(Icons.add, color: Colors.white),
              ),
            ),
          ]),
        ),
      ]),
    );
  }

  Widget _optionRow(Map<String, dynamic> o) {
    final available = o['is_available'] != false;
    final price = (o['price_cents'] as num).toInt();
    final flag = _ingredients ? (o['allow_extra'] != false ? context.t('Can be extra') : null) : (o['is_default'] == true ? context.t('Pre-selected') : null);
    return InkWell(
      onTap: () => _editOption(o),
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 8, 8, 8),
        decoration: BoxDecoration(color: available ? Colors.white : C.slate50, border: const Border(top: BorderSide(color: C.slate100))),
        child: Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(
                o['name'] ?? '',
                style: TextStyle(fontWeight: FontWeight.w700, color: available ? C.slate800 : C.slate400, decoration: available ? null : TextDecoration.lineThrough),
              ),
              Text(
                [if (price > 0) '${_ingredients ? '${context.t('Extra')} ' : ''}+${formatPrice(price)}', ?flag].join(' · '),
                style: const TextStyle(fontSize: 12, color: C.slate500),
              ),
            ]),
          ),
          Pressable(
            onTap: () => widget.run(() => RestaurantRepo.updateOption(o['id'], {'is_available': !available})),
            child: Pill(context.t(available ? 'In stock' : 'Sold out'), bg: available ? C.green100 : C.slate200, fg: available ? C.green700 : C.slate600),
          ),
          const Icon(Icons.chevron_right, color: C.slate300),
        ]),
      ),
    );
  }
}

class _AddGroupCard extends StatefulWidget {
  final String itemId;
  final _Runner run;
  const _AddGroupCard({required this.itemId, required this.run});
  @override
  State<_AddGroupCard> createState() => _AddGroupCardState();
}

class _AddGroupCardState extends State<_AddGroupCard> {
  final _name = TextEditingController(), _max = TextEditingController();
  String _kind = 'choice';
  bool _required = false;

  Future<void> _add() async {
    final name = _name.text.trim();
    if (name.isEmpty) return showError(context, context.i18n.t('Group name is required'));
    await widget.run(() => RestaurantRepo.addGroup(widget.itemId, name: name, kind: _kind, required: _required, max: int.tryParse(_max.text.trim())));
    _name.clear();
    _max.clear();
    setState(() => _required = false);
  }

  @override
  Widget build(BuildContext context) {
    return CardBox(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text(context.t('Add a custom group'), style: const TextStyle(fontWeight: FontWeight.w800)),
        const SizedBox(height: 10),
        TextField(controller: _name, decoration: InputDecoration(labelText: context.t('Group name'), hintText: context.t('e.g. Choose your drink'))),
        const SizedBox(height: 10),
        SegmentedButton<String>(
          segments: [
            ButtonSegment(value: 'choice', label: Text(context.t('Choice'))),
            ButtonSegment(value: 'ingredients', label: Text(context.t('Ingredients'))),
          ],
          selected: {_kind},
          onSelectionChanged: (s) => setState(() => _kind = s.first),
        ),
        const SizedBox(height: 4),
        Text(
          context.t(_kind == 'choice' ? 'Customer picks from a list (bread, size, sauces, paid extras).' : 'Customer can remove each ingredient or ask for extra.'),
          style: const TextStyle(fontSize: 12, color: C.slate500),
        ),
        if (_kind == 'choice') ...[
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            value: _required,
            activeColor: C.brand600,
            controlAffinity: ListTileControlAffinity.leading,
            onChanged: (v) => setState(() => _required = v ?? false),
            title: Text(context.t('Required')),
          ),
          TextField(controller: _max, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: context.t('Max picks (blank = any)'))),
        ],
        const SizedBox(height: 12),
        PrimaryButton(context.t('Add group'), onPressed: _add),
      ]),
    );
  }
}
