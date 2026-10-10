import 'package:flutter/material.dart';

import 'categories.dart';
import 'media.dart';
import 'models.dart';
import 'people_picker.dart';
import 'scan_bill.dart';
import 'settings.dart';
import 'store.dart';
import 'widgets.dart';

bool _isEqualSplit(GroupExpense expense) {
  if (expense.splitShares.isEmpty) return true;
  final each = expense.amount / expense.splitShares.length;
  return expense.splitShares.values.every((v) => (v - each).abs() < 0.01);
}

String _formatAmount(double value) => value == value.roundToDouble()
    ? value.toStringAsFixed(0)
    : value.toStringAsFixed(2);

double _parse(TextEditingController controller) =>
    double.tryParse(controller.text.trim()) ?? 0;

double _round(double value) => (value * 100).round() / 100;

class AddExpenseScreen extends StatefulWidget {
  const AddExpenseScreen({super.key, required this.group, this.existing});

  final ExpenseGroup group;
  final GroupExpense? existing;

  @override
  State<AddExpenseScreen> createState() => _AddExpenseScreenState();
}

class _AddExpenseScreenState extends State<AddExpenseScreen> {
  late final TextEditingController _amount;
  late final TextEditingController _title;
  late final TextEditingController _tax;
  final Map<String, TextEditingController> _shareControllers = {};
  late String _payer;
  late final Set<String> _among;
  late bool _exact;
  late DateTime _date;
  late String _category;
  String? _receiptPick;
  Frequency? _repeat;
  String? _error;

  static const _taxChips = [0.0, 5.0, 12.0, 18.0, 28.0];

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    final taxPercent = existing?.taxPercent ?? appSettings.defaultTax;

    _amount = TextEditingController(
      text: existing == null ? '' : _formatAmount(existing.subtotal),
    );
    _title = TextEditingController(text: existing?.title ?? '');
    _tax = TextEditingController(
      text: taxPercent == 0 ? '' : _formatAmount(taxPercent),
    );
    _payer = existing?.paidBy ?? meId;
    _among = existing?.splitShares.keys.toSet() ?? {...widget.group.memberIds};
    _exact = existing != null
        ? !_isEqualSplit(existing)
        : appSettings.defaultExactSplit;
    _date = existing?.createdAt ?? DateTime.now();
    _category = existing?.category ?? '';

    if (existing != null) {
      final factor = 1 + existing.taxPercent / 100;
      existing.splitShares.forEach((id, value) {
        _controllerFor(id).text = _formatAmount(_round(value / factor));
      });
    }
  }

  @override
  void dispose() {
    _amount.dispose();
    _title.dispose();
    _tax.dispose();
    for (final c in _shareControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  TextEditingController _controllerFor(String id) =>
      _shareControllers.putIfAbsent(id, TextEditingController.new);

  List<String> get _memberIds => widget.group.memberIds;

  double get _base => double.tryParse(_amount.text.trim()) ?? 0;

  double get _taxPercent => _parse(_tax);

  double get _taxAmount => _round(_base * _taxPercent / 100);

  double get _grandTotal => _round(_base + _taxAmount);

  String _label(String id) => id == meId ? 'You' : appStore.nameOf(id);

  String? get _shownReceipt => _receiptPick == removePhoto
      ? null
      : (_receiptPick ?? widget.existing?.receiptPath);

  List<String> _suggestions() {
    final titles = <String>[];
    for (final e in appStore.expensesFor(widget.group.id)) {
      if (e.isSettlement || titles.contains(e.title)) continue;
      titles.add(e.title);
      if (titles.length == 6) break;
    }
    return titles;
  }

  Future<void> _addPeople() async {
    final before = {..._memberIds};
    final picked = await pickPeople(
      context,
      title: 'Add people to ${widget.group.name}',
      initial: before,
    );
    if (picked == null || !mounted) return;
    final blocked = appStore.setGroupMembers(widget.group, picked);
    setState(() {
      _among.addAll(picked.difference(before));
      _among.removeWhere((id) => !_memberIds.contains(id));
    });
    if (blocked.isNotEmpty) {
      showMessage(
        context,
        "Can't remove ${blocked.join(', ')} because they have expenses here",
      );
    }
  }

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

  void _viewReceipt() {
    final image = imageProviderFor(_shownReceipt);
    if (image == null) return;
    showDialog<void>(
      context: context,
      builder: (ctx) => Dialog(
        child: InteractiveViewer(child: Image(image: image)),
      ),
    );
  }

  void _fail(String message) => setState(() => _error = message);

  Future<void> _save() async {
    final base = _base;
    final title = _title.text.trim();
    if (base <= 0) {
      _fail('Enter an amount greater than zero');
      return;
    }
    if (title.isEmpty) {
      _fail('Add a description');
      return;
    }

    final selected = _memberIds.where(_among.contains).toList();
    if (selected.isEmpty) {
      _fail('Choose at least one person to split with');
      return;
    }

    final factor = 1 + _taxPercent / 100;
    final shares = <String, double>{};
    if (_exact) {
      var entered = 0.0;
      for (final id in selected) {
        final value = _parse(_controllerFor(id));
        if (value > 0) {
          shares[id] = _round(value * factor);
          entered += value;
        }
      }
      if (shares.isEmpty || (entered - base).abs() > 0.01) {
        _fail('Exact amounts must add up to ${rupees(base)}');
        return;
      }
    } else {
      final each = _grandTotal / selected.length;
      for (final id in selected) {
        shares[id] = each;
      }
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

    final expense = GroupExpense(
      id: existing?.id ?? newId(),
      groupId: widget.group.id,
      title: title,
      amount: _grandTotal,
      paidBy: _payer,
      splitShares: shares,
      createdAt: when,
      subtotal: base,
      taxPercent: _taxPercent,
      category: category,
      receiptPath: receipt,
    );
    appStore.saveExpense(expense);

    final repeat = _repeat;
    if (existing == null && repeat != null) {
      final rule = RecurringExpense(
        id: newId(),
        groupId: expense.groupId,
        title: expense.title,
        amount: expense.amount,
        subtotal: expense.subtotal,
        taxPercent: expense.taxPercent,
        paidBy: expense.paidBy,
        splitShares: expense.splitShares,
        category: expense.category,
        frequency: repeat,
        nextDue: when,
      );
      rule.nextDue = rule.advance(when);
      appStore.addRecurring(rule);
    }

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

  List<Widget> _exactRows(List<String> selected, double base) {
    final scheme = Theme.of(context).colorScheme;
    final entered = selected.fold(
      0.0,
      (sum, id) => sum + _parse(_controllerFor(id)),
    );
    final remaining = base - entered;
    final ok = remaining.abs() < 0.01;

    return [
      for (final id in selected)
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            children: [
              Expanded(child: Text(_label(id))),
              SizedBox(
                width: 140,
                child: TextField(
                  controller: _controllerFor(id),
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(
                    prefixText: '₹ ',
                    isDense: true,
                  ),
                ),
              ),
            ],
          ),
        ),
      Text(
        ok ? 'Adds up to the amount' : 'Remaining ${rupees(remaining)}',
        style: TextStyle(color: ok ? scheme.primary : scheme.error),
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final members = _memberIds;
    final selected = members.where(_among.contains).toList();
    final each = selected.isEmpty ? 0.0 : _grandTotal / selected.length;
    final suggestions = _suggestions();
    final isEdit = widget.existing != null;
    final allSelected = selected.length == members.length;
    final hasTax = _taxPercent > 0;
    final receipt = imageProviderFor(_shownReceipt);

    return Scaffold(
      appBar: AppBar(
        title: Text(isEdit ? 'Edit expense' : 'Add expense'),
        actions: [
          if (!isEdit)
            IconButton(
              tooltip: 'Scan a bill',
              icon: const Icon(Icons.document_scanner_outlined),
              onPressed: () =>
                  startBillScan(context, widget.group, replace: true),
            ),
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
          TextField(
            controller: _amount,
            autofocus: !isEdit,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: theme.textTheme.displaySmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
            decoration: InputDecoration(
              prefixText: '₹ ',
              hintText: '0',
              border: InputBorder.none,
              helperText: hasTax ? 'Amount before tax' : null,
            ),
            onChanged: (_) => setState(() {}),
          ),
          const Divider(),
          const SizedBox(height: 12),
          TextField(
            controller: _title,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: 'Description',
              prefixIcon: Icon(Icons.edit_note_rounded),
            ),
          ),
          if (suggestions.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final t in suggestions)
                  ActionChip(
                    label: Text(t),
                    onPressed: () => setState(() => _title.text = t),
                  ),
              ],
            ),
          ],
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
                child: receipt == null
                    ? OutlinedButton.icon(
                        onPressed: _pickReceipt,
                        icon: const Icon(Icons.receipt_rounded),
                        label: const Text('Receipt'),
                      )
                    : Row(
                        children: [
                          GestureDetector(
                            onTap: _viewReceipt,
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: Image(
                                image: receipt,
                                width: 48,
                                height: 48,
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          TextButton(
                            onPressed: _pickReceipt,
                            child: const Text('Change'),
                          ),
                        ],
                      ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          _SectionLabel('Category'),
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
          _SectionLabel('Tax'),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              for (final pct in _taxChips)
                ChoiceChip(
                  label: Text(pct == 0 ? 'No tax' : '${_formatAmount(pct)}%'),
                  selected: _taxPercent == pct,
                  onSelected: (_) => setState(
                    () => _tax.text = pct == 0 ? '' : _formatAmount(pct),
                  ),
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
          if (hasTax && _base > 0) ...[
            const SizedBox(height: 10),
            Text(
              'Tax ${rupees(_taxAmount)}  •  Total ${rupees(_grandTotal)}. '
              'The tax is split along with the amount.',
              style: TextStyle(color: scheme.onSurfaceVariant),
            ),
          ],
          const SizedBox(height: 24),
          _SectionLabel('Paid by'),
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
            ],
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(child: _SectionLabel('Split between')),
              TextButton(
                onPressed: () => setState(() {
                  if (allSelected) {
                    _among.clear();
                  } else {
                    _among.addAll(members);
                  }
                }),
                child: Text(allSelected ? 'Clear' : 'Everyone'),
              ),
            ],
          ),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final id in members)
                FilterChip(
                  label: Text(_label(id)),
                  selected: _among.contains(id),
                  onSelected: (on) => setState(() {
                    if (on) {
                      _among.add(id);
                    } else {
                      _among.remove(id);
                    }
                  }),
                ),
              ActionChip(
                avatar: const Icon(Icons.person_add_alt_1_rounded, size: 18),
                label: const Text('Add people'),
                onPressed: _addPeople,
              ),
            ],
          ),
          const SizedBox(height: 24),
          SegmentedButton<bool>(
            segments: const [
              ButtonSegment(value: false, label: Text('Equally')),
              ButtonSegment(value: true, label: Text('Exact amounts')),
            ],
            selected: {_exact},
            onSelectionChanged: (s) => setState(() => _exact = s.first),
          ),
          const SizedBox(height: 14),
          if (_exact)
            ..._exactRows(selected, _base)
          else
            Text(
              selected.isEmpty
                  ? 'Pick who to split with'
                  : '${rupees(each)} each for ${selected.length} '
                        '${selected.length == 1 ? 'person' : 'people'}',
              style: TextStyle(color: scheme.onSurfaceVariant),
            ),
          if (!isEdit) ...[
            const SizedBox(height: 24),
            _SectionLabel('Repeat'),
            SegmentedButton<Frequency?>(
              segments: const [
                ButtonSegment(value: null, label: Text('Never')),
                ButtonSegment(value: Frequency.weekly, label: Text('Weekly')),
                ButtonSegment(value: Frequency.monthly, label: Text('Monthly')),
              ],
              selected: {_repeat},
              emptySelectionAllowed: true,
              onSelectionChanged: (s) =>
                  setState(() => _repeat = s.isEmpty ? null : s.first),
            ),
          ],
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!, style: TextStyle(color: scheme.error)),
          ],
          const SizedBox(height: 28),
          FilledButton(
            onPressed: _save,
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
            ),
            child: Text(isEdit ? 'Save changes' : 'Save expense'),
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(text, style: Theme.of(context).textTheme.titleSmall),
    );
  }
}
