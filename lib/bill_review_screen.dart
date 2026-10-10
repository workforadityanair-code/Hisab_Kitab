import 'package:flutter/material.dart';

import 'bill_parser.dart';
import 'categories.dart';
import 'media.dart';
import 'models.dart';
import 'people_picker.dart';
import 'settings.dart';
import 'store.dart';
import 'widgets.dart';

double _parse(TextEditingController controller) =>
    double.tryParse(controller.text.trim()) ?? 0;

double _round(double value) => (value * 100).round() / 100;

String _plain(double value) => value == value.roundToDouble()
    ? value.toStringAsFixed(0)
    : value.toStringAsFixed(2);

class _ItemDraft {
  _ItemDraft({String name = '', String amount = '', Set<String>? sharedBy})
    : name = TextEditingController(text: name),
      amount = TextEditingController(text: amount),
      sharedBy = sharedBy ?? {};

  final TextEditingController name;
  final TextEditingController amount;
  final Set<String> sharedBy;

  void dispose() {
    name.dispose();
    amount.dispose();
  }
}

class BillReviewScreen extends StatefulWidget {
  const BillReviewScreen({
    super.key,
    required this.group,
    this.parsed,
    this.existing,
    this.scannedPath,
  });

  final ExpenseGroup group;
  final ParsedBill? parsed;
  final GroupExpense? existing;
  final String? scannedPath;

  @override
  State<BillReviewScreen> createState() => _BillReviewScreenState();
}

class _BillReviewScreenState extends State<BillReviewScreen> {
  late final TextEditingController _title;
  late final TextEditingController _tax;
  final List<_ItemDraft> _items = [];
  late String _payer;
  late DateTime _date;
  late String _category;
  String? _receiptPick;
  String? _error;

  static const _taxChips = [0.0, 5.0, 12.0, 18.0, 28.0];

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    final parsed = widget.parsed;
    final everyone = {...widget.group.memberIds};

    _title = TextEditingController(text: existing?.title ?? 'Bill');
    _payer = existing?.paidBy ?? meId;
    _date = existing?.createdAt ?? DateTime.now();
    _category = existing?.category ?? '';
    _receiptPick = widget.scannedPath;

    if (existing != null) {
      for (final item in existing.items) {
        _items.add(
          _ItemDraft(
            name: item.name,
            amount: _plain(item.amount),
            sharedBy: {...item.sharedBy},
          ),
        );
      }
      _tax = TextEditingController(
        text: existing.taxPercent == 0 ? '' : _plain(existing.taxPercent),
      );
    } else {
      for (final item in parsed?.items ?? const <ParsedItem>[]) {
        _items.add(
          _ItemDraft(
            name: item.name,
            amount: _plain(item.amount),
            sharedBy: {...everyone},
          ),
        );
      }
      final detected = parsed?.taxPercent ?? 0;
      final pct = detected > 0 ? detected : appSettings.defaultTax;
      _tax = TextEditingController(text: pct == 0 ? '' : _plain(pct));
    }
    if (_items.isEmpty) _items.add(_ItemDraft(sharedBy: {...everyone}));
  }

  @override
  void dispose() {
    _title.dispose();
    _tax.dispose();
    for (final item in _items) {
      item.dispose();
    }
    super.dispose();
  }

  List<String> get _memberIds => widget.group.memberIds;

  String _label(String id) => id == meId ? 'You' : appStore.nameOf(id);

  double get _itemsTotal =>
      _items.fold(0.0, (sum, i) => sum + _parse(i.amount));

  double get _taxPercent => _parse(_tax);

  double get _taxAmount => _itemsTotal * _taxPercent / 100;

  Map<String, double> _shares() {
    final shares = <String, double>{};
    final factor = 1 + _taxPercent / 100;
    for (final item in _items) {
      final amount = _parse(item.amount);
      final sharers = item.sharedBy.where(_memberIds.contains).toList();
      if (sharers.isEmpty || amount == 0) continue;
      final each = amount / sharers.length;
      for (final id in sharers) {
        shares[id] = (shares[id] ?? 0) + each * factor;
      }
    }
    return {for (final e in shares.entries) e.key: _round(e.value)};
  }

  Future<void> _addPeople() async {
    final before = {..._memberIds};
    final picked = await pickPeople(
      context,
      title: 'People in ${widget.group.name}',
      initial: before,
    );
    if (picked == null || !mounted) return;
    final blocked = appStore.setGroupMembers(widget.group, picked);
    setState(() {
      for (final item in _items) {
        item.sharedBy.removeWhere((id) => !_memberIds.contains(id));
      }
      if (!_memberIds.contains(_payer)) _payer = meId;
    });
    if (blocked.isNotEmpty) {
      showMessage(
        context,
        "Can't remove ${blocked.join(', ')} because they have expenses here",
      );
    }
  }

  void _shareAllWithEveryone() {
    setState(() {
      for (final item in _items) {
        item.sharedBy
          ..clear()
          ..addAll(_memberIds);
      }
    });
  }

  void _fail(String message) => setState(() => _error = message);

  String? get _shownReceipt => _receiptPick == removePhoto
      ? null
      : (_receiptPick ?? widget.existing?.receiptPath);

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _pickReceipt() async {
    final picked = await choosePhoto(context, canRemove: _shownReceipt != null);
    if (picked != null) setState(() => _receiptPick = picked);
  }

  Future<void> _save() async {
    final title = _title.text.trim();
    final drafts = _items
        .where((i) => i.name.text.trim().isNotEmpty || _parse(i.amount) != 0)
        .toList();

    if (drafts.isEmpty) {
      _fail('Add at least one item');
      return;
    }
    for (var i = 0; i < drafts.length; i++) {
      final item = drafts[i];
      final label = item.name.text.trim().isEmpty
          ? 'Item ${i + 1}'
          : item.name.text.trim();
      if (_parse(item.amount) == 0) {
        _fail('Enter an amount for $label');
        return;
      }
      if (item.sharedBy.where(_memberIds.contains).isEmpty) {
        _fail('Choose who shared $label');
        return;
      }
    }

    final shares = _shares();
    final total = _round(shares.values.fold(0.0, (a, b) => a + b));
    if (total <= 0) {
      _fail('The bill total must be more than zero');
      return;
    }

    final existing = widget.existing;
    final now = DateTime.now();
    final sameDay =
        _date.year == now.year &&
        _date.month == now.month &&
        _date.day == now.day;
    final when = existing != null && existing.createdAt == _date
        ? existing.createdAt
        : (sameDay
              ? now
              : DateTime(
                  _date.year,
                  _date.month,
                  _date.day,
                  now.hour,
                  now.minute,
                ));
    final receipt = await commitPhoto(
      _receiptPick,
      existing?.receiptPath,
      'receipts',
    );
    final category = _category.isEmpty ? guessCategory(title) : _category;

    appStore.saveExpense(
      GroupExpense(
        id: existing?.id ?? newId(),
        groupId: widget.group.id,
        title: title.isEmpty ? 'Bill' : title,
        amount: total,
        paidBy: _payer,
        splitShares: shares,
        createdAt: when,
        category: category,
        receiptPath: receipt,
        subtotal: _round(_itemsTotal),
        taxPercent: _taxPercent,
        items: [
          for (var i = 0; i < drafts.length; i++)
            ExpenseItem(
              name: drafts[i].name.text.trim().isEmpty
                  ? 'Item ${i + 1}'
                  : drafts[i].name.text.trim(),
              amount: _parse(drafts[i].amount),
              sharedBy: drafts[i].sharedBy.where(_memberIds.contains).toList(),
            ),
        ],
      ),
    );
    if (mounted) Navigator.pop(context);
  }

  Future<void> _delete() async {
    final existing = widget.existing;
    if (existing == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete "${existing.title}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    appStore.deleteExpense(existing);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final members = _memberIds;
    final shares = _shares();
    final grandTotal = _itemsTotal + _taxAmount;
    final detected = widget.parsed?.detectedTotal;
    final mismatch = detected != null && (detected - grandTotal).abs() > 1;
    final isEdit = widget.existing != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(isEdit ? 'Edit bill' : 'Review bill'),
        actions: [
          if (isEdit)
            IconButton(
              tooltip: 'Delete',
              icon: const Icon(Icons.delete_outline_rounded),
              onPressed: _delete,
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          if (!isEdit)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    Icon(Icons.auto_awesome_rounded, color: scheme.primary),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'Check the items we read, then tap who shared each one.',
                      ),
                    ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 16),
          TextField(
            controller: _title,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              labelText: 'Bill name',
              prefixIcon: Icon(Icons.storefront_outlined),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _pickDate,
                  icon: const Icon(Icons.event_rounded),
                  label: Text(formatDate(_date)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _pickReceipt,
                  icon: Icon(
                    _shownReceipt == null
                        ? Icons.receipt_rounded
                        : Icons.check_circle_outline_rounded,
                  ),
                  label: Text(
                    _shownReceipt == null ? 'Receipt' : 'Receipt saved',
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Text('Category', style: theme.textTheme.titleSmall),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final c in expenseCategories)
                ChoiceChip(
                  avatar: Icon(c.icon, size: 18),
                  label: Text(c.label),
                  selected: _category == c.id,
                  onSelected: (on) =>
                      setState(() => _category = on ? c.id : ''),
                ),
            ],
          ),
          const SizedBox(height: 24),
          Text('Paid by', style: theme.textTheme.titleSmall),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final id in members)
                ChoiceChip(
                  label: Text(_label(id)),
                  selected: _payer == id,
                  onSelected: (_) => setState(() => _payer = id),
                ),
              ActionChip(
                avatar: const Icon(Icons.person_add_alt_1_rounded, size: 18),
                label: const Text('Add people'),
                onPressed: _addPeople,
              ),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(child: Text('Items', style: theme.textTheme.titleSmall)),
              TextButton(
                onPressed: _shareAllWithEveryone,
                child: const Text('Everyone shares all'),
              ),
            ],
          ),
          for (var i = 0; i < _items.length; i++) _itemCard(i, members),
          const SizedBox(height: 4),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () => setState(
                () => _items.add(_ItemDraft(sharedBy: {...members})),
              ),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Add item'),
            ),
          ),
          const SizedBox(height: 16),
          Text('Tax', style: theme.textTheme.titleSmall),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              for (final pct in _taxChips)
                ChoiceChip(
                  label: Text(pct == 0 ? 'No tax' : '${_plain(pct)}%'),
                  selected: _taxPercent == pct,
                  onSelected: (_) =>
                      setState(() => _tax.text = pct == 0 ? '' : _plain(pct)),
                ),
              SizedBox(
                width: 110,
                child: TextField(
                  controller: _tax,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(
                    labelText: 'Custom %',
                    isDense: true,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _summaryRow('Items', rupees(_itemsTotal)),
                  _summaryRow(
                    'Tax (${_plain(_taxPercent)}%)',
                    rupees(_taxAmount),
                  ),
                  const Divider(height: 20),
                  _summaryRow('Total', rupees(grandTotal), bold: true),
                  if (mismatch)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        'The bill says ${rupees(detected)}. Check the items.',
                        style: TextStyle(color: scheme.error),
                      ),
                    ),
                ],
              ),
            ),
          ),
          if (shares.isNotEmpty) ...[
            const SizedBox(height: 20),
            Text('Each person pays', style: theme.textTheme.titleSmall),
            const SizedBox(height: 8),
            for (final entry in shares.entries)
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: NameAvatar(
                  name: appStore.nameOf(entry.key),
                  radius: 16,
                ),
                title: Text(_label(entry.key)),
                trailing: Text(
                  rupees(entry.value),
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
          ],
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!, style: TextStyle(color: scheme.error)),
          ],
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _save,
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
            ),
            child: Text(isEdit ? 'Save changes' : 'Save bill'),
          ),
        ],
      ),
    );
  }

  Widget _summaryRow(String label, String value, {bool bold = false}) {
    final style = TextStyle(
      fontWeight: bold ? FontWeight.w700 : FontWeight.w400,
      fontSize: bold ? 16 : 14,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: style),
          Text(value, style: style),
        ],
      ),
    );
  }

  Widget _itemCard(int index, List<String> members) {
    final item = _items[index];
    final amount = _parse(item.amount);
    final sharers = item.sharedBy.where(members.contains).length;
    final scheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 6, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: item.name,
                      textCapitalization: TextCapitalization.words,
                      onChanged: (_) => setState(() {}),
                      decoration: const InputDecoration(
                        labelText: 'Item',
                        isDense: true,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  SizedBox(
                    width: 110,
                    child: TextField(
                      controller: item.amount,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                        signed: true,
                      ),
                      onChanged: (_) => setState(() {}),
                      decoration: const InputDecoration(
                        prefixText: '₹ ',
                        isDense: true,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Remove item',
                    icon: const Icon(Icons.close_rounded),
                    onPressed: _items.length == 1
                        ? null
                        : () => setState(() {
                            _items.removeAt(index).dispose();
                          }),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  for (final id in members)
                    FilterChip(
                      label: Text(_label(id)),
                      selected: item.sharedBy.contains(id),
                      visualDensity: VisualDensity.compact,
                      onSelected: (on) => setState(() {
                        if (on) {
                          item.sharedBy.add(id);
                        } else {
                          item.sharedBy.remove(id);
                        }
                      }),
                    ),
                ],
              ),
              if (sharers > 0 && amount != 0)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    '${rupees(amount / sharers)} each',
                    style: TextStyle(
                      fontSize: 12,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
