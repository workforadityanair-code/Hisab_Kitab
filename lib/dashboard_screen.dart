import 'package:flutter/material.dart';
import 'package:printing/printing.dart';

import 'add_expense_screen.dart';
import 'bill.dart';
import 'bill_review_screen.dart';
import 'categories.dart';
import 'friends_screen.dart';
import 'import_flow.dart';
import 'insights_screen.dart';
import 'media.dart';
import 'message_sheet.dart';
import 'messaging.dart';
import 'models.dart';
import 'new_group_screen.dart';
import 'open_file.dart';
import 'payment_qr.dart';
import 'people_picker.dart';
import 'recurring_screen.dart';
import 'scan_bill.dart';
import 'settings.dart';
import 'settings_screen.dart';
import 'settlement.dart';
import 'store.dart';
import 'upi.dart';
import 'upi_qr_screen.dart';
import 'widgets.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  String? _selectedId;
  String _query = '';
  bool _building = false;

  @override
  void initState() {
    super.initState();
    listenForOpenedFiles(_handleOpenedFile);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final text = await takeOpenedFile();
      if (text != null) _handleOpenedFile(text);
    });
  }

  Future<void> _handleOpenedFile(String text) async {
    if (!mounted) return;
    final groupId = await importHisabText(context, text);
    if (groupId != null && mounted) setState(() => _selectedId = groupId);
  }

  ExpenseGroup _currentGroup(List<ExpenseGroup> groups) {
    for (final g in groups) {
      if (g.id == _selectedId) return g;
    }
    return appStore.defaultGroup;
  }

  Future<void> _openSettings() async {
    final groupId = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => const SettingsScreen()),
    );
    if (groupId != null && mounted) setState(() => _selectedId = groupId);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: appStore,
      builder: (context, _) {
        final group = _currentGroup(appStore.groups);

        return Scaffold(
          appBar: AppBar(
            title: Text(group.name),
            actions: [
              IconButton(
                tooltip: 'Friends',
                icon: const Icon(Icons.people_alt_outlined),
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const FriendsScreen()),
                ),
              ),
              IconButton(
                tooltip: 'Settings',
                icon: const Icon(Icons.settings_outlined),
                onPressed: _openSettings,
              ),
              _moreMenu(group),
            ],
          ),
          body: _groupBody(group),
          floatingActionButton: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              FloatingActionButton.small(
                heroTag: null,
                tooltip: 'Scan a bill',
                onPressed: () => startBillScan(context, group),
                child: const Icon(Icons.document_scanner_outlined),
              ),
              const SizedBox(height: 12),
              FloatingActionButton.extended(
                heroTag: null,
                onPressed: () => _openExpense(group),
                icon: const Icon(Icons.add_rounded),
                label: const Text('Add expense'),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _moreMenu(ExpenseGroup group) {
    return PopupMenuButton<String>(
      onSelected: (value) {
        switch (value) {
          case 'members':
            _editMembers(group);
          case 'photo':
            _changePhoto(group);
          case 'share':
            shareGroupFile(context, group);
          case 'insights':
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => InsightsScreen(groupId: group.id),
              ),
            );
          case 'recurring':
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const RecurringScreen()),
            );
          case 'import':
            _importFile();
          case 'rename':
            _rename(group);
          case 'delete':
            _deleteGroup(group);
        }
      },
      itemBuilder: (_) => [
        const PopupMenuItem(value: 'members', child: Text('Members')),
        const PopupMenuItem(value: 'photo', child: Text('Change group photo')),
        const PopupMenuItem(
          value: 'share',
          child: Text('Share group (.hisab)'),
        ),
        const PopupMenuItem(value: 'insights', child: Text('Insights')),
        const PopupMenuItem(value: 'recurring', child: Text('Recurring')),
        const PopupMenuItem(value: 'import', child: Text('Load a .hisab file')),
        if (!group.isDefault)
          const PopupMenuItem(value: 'rename', child: Text('Rename group')),
        if (!group.isDefault)
          const PopupMenuItem(value: 'delete', child: Text('Delete group')),
      ],
    );
  }

  Future<void> _importFile() async {
    final groupId = await pickAndImportHisab(context);
    if (groupId != null && mounted) setState(() => _selectedId = groupId);
  }

  Future<void> _changePhoto(ExpenseGroup group) async {
    final picked = await choosePhoto(
      context,
      canRemove: group.photoPath != null,
    );
    if (picked == null) return;
    final photo = await commitPhoto(picked, group.photoPath, 'groups');
    appStore.setGroupPhoto(group, photo);
  }

  Widget _groupBody(ExpenseGroup group) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: 52,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            children: [
              for (final g in appStore.groups)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    avatar: g.photoPath == null
                        ? null
                        : NameAvatar(
                            name: g.name,
                            radius: 12,
                            photoPath: g.photoPath,
                          ),
                    label: Text(g.name),
                    selected: g.id == group.id,
                    onSelected: (_) => setState(() => _selectedId = g.id),
                  ),
                ),
              ActionChip(
                avatar: const Icon(Icons.add_rounded, size: 18),
                label: const Text('New group'),
                onPressed: _newGroup,
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: _balanceCard(group),
        ),
        Expanded(
          child: DefaultTabController(
            length: 2,
            child: Column(
              children: [
                const TabBar(
                  tabs: [
                    Tab(text: 'Balances'),
                    Tab(text: 'Activity'),
                  ],
                ),
                Expanded(
                  child: TabBarView(
                    children: [_balancesTab(group), _activityTab(group)],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _balanceCard(ExpenseGroup group) {
    final scheme = Theme.of(context).colorScheme;
    final balance = appStore.balancesFor(group)[meId] ?? 0;
    final settled = balance.abs() < 0.005;
    final owed = balance > 0;

    final label = settled
        ? 'Settled up'
        : owed
        ? 'You are owed'
        : 'You owe';
    final color = settled
        ? scheme.onSurface
        : owed
        ? scheme.primary
        : scheme.error;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (group.photoPath != null) ...[
                  NameAvatar(
                    name: group.name,
                    photoPath: group.photoPath,
                    radius: 24,
                  ),
                  const SizedBox(width: 14),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style: TextStyle(color: scheme.onSurfaceVariant),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        settled ? 'All clear' : rupees(balance.abs()),
                        style: Theme.of(context).textTheme.headlineMedium
                            ?.copyWith(
                              color: color,
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  settled
                      ? Icons.check_circle_rounded
                      : Icons.account_balance_wallet_outlined,
                  color: color,
                ),
              ],
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: FilledButton.tonalIcon(
                onPressed: _building ? null : () => _generateBill(group),
                icon: _building
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.picture_as_pdf_outlined),
                label: const Text('Generate bill'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _balancesTab(ExpenseGroup group) {
    final settlements = appStore.settlementsFor(group);
    if (settlements.isEmpty) {
      return const EmptyState(
        icon: Icons.check_circle_outline_rounded,
        title: 'Everyone is settled up',
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.only(top: 8, bottom: 140),
      itemCount: settlements.length,
      itemBuilder: (context, i) => _settlementTile(group, settlements[i]),
    );
  }

  Widget _activityTab(ExpenseGroup group) {
    final all = appStore.expensesFor(group.id);
    if (all.isEmpty) {
      return const EmptyState(
        icon: Icons.receipt_long_outlined,
        title: 'No expenses yet',
        message: 'Tap Add expense, or scan a bill to split it by item.',
      );
    }

    final expenses = all
        .where(
          (e) => matchesQuery(_query, [
            e.title,
            appStore.nameOf(e.paidBy),
            categoryOf(e.category).label,
            ...e.items.map((i) => i.name),
          ]),
        )
        .toList();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: SearchField(
            hint: 'Search expenses',
            onChanged: (v) => setState(() => _query = v),
          ),
        ),
        Expanded(
          child: expenses.isEmpty
              ? EmptyState(
                  icon: Icons.search_off_rounded,
                  title: 'No matches',
                  message: 'Nothing matches "$_query".',
                )
              : ListView.builder(
                  padding: const EdgeInsets.only(top: 8, bottom: 140),
                  itemCount: expenses.length,
                  itemBuilder: (_, i) => _dismissible(group, expenses[i]),
                ),
        ),
      ],
    );
  }

  Widget _dismissible(ExpenseGroup group, GroupExpense expense) {
    final scheme = Theme.of(context).colorScheme;
    return Dismissible(
      key: ValueKey(expense.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        color: scheme.errorContainer,
        child: Icon(
          Icons.delete_outline_rounded,
          color: scheme.onErrorContainer,
        ),
      ),
      onDismissed: (_) {
        appStore.deleteExpense(expense);
        showMessage(
          context,
          'Deleted ${expense.isSettlement ? 'settlement' : expense.title}',
          SnackBarAction(
            label: 'Undo',
            onPressed: () => appStore.saveExpense(expense),
          ),
        );
      },
      child: _activityTile(group, expense),
    );
  }

  Widget _activityTile(ExpenseGroup group, GroupExpense expense) {
    final scheme = Theme.of(context).colorScheme;
    final receiver = expense.splitShares.keys.isEmpty
        ? ''
        : expense.splitShares.keys.first;
    final hasTax = !expense.isSettlement && expense.taxPercent > 0;
    final kind = expense.isSettlement
        ? 'Settlement'
        : expense.items.isNotEmpty
        ? '${expense.items.length} items'
        : 'Paid by ${_who(expense.paidBy)}';

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      onTap: expense.isSettlement
          ? null
          : () => _openExpense(group, existing: expense),
      leading: CircleAvatar(
        backgroundColor: scheme.secondaryContainer,
        foregroundColor: scheme.onSecondaryContainer,
        child: Icon(
          expense.isSettlement
              ? Icons.swap_horiz_rounded
              : categoryOf(expense.category).icon,
        ),
      ),
      title: Text(
        expense.isSettlement
            ? '${_who(expense.paidBy)} paid ${_who(receiver)}'
            : expense.title,
      ),
      subtitle: Text(
        '$kind • ${formatDate(expense.createdAt)}'
        '${hasTax ? ' • incl. tax' : ''}'
        '${expense.receiptPath != null ? ' • receipt' : ''}',
      ),
      trailing: Text(
        rupees(expense.amount),
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
    );
  }

  Widget _settlementTile(ExpenseGroup group, Settlement settlement) {
    final scheme = Theme.of(context).colorScheme;
    final iOwe = settlement.debtor == meId;
    final involved = iOwe || settlement.creditor == meId;
    final debtor = appStore.personById(settlement.debtor);

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      leading: NameAvatar(
        name: appStore.nameOf(settlement.debtor),
        photoPath: debtor?.photoPath,
      ),
      title: Text(_owesText(settlement)),
      subtitle: Text(group.name),
      trailing: Text(
        rupees(settlement.amount),
        style: TextStyle(
          fontWeight: FontWeight.w700,
          color: iOwe ? scheme.error : (involved ? scheme.primary : null),
        ),
      ),
      onTap: involved ? () => _showSettlementSheet(group, settlement) : null,
    );
  }

  String _owesText(Settlement s) {
    if (s.debtor == meId) return 'You owe ${appStore.nameOf(s.creditor)}';
    if (s.creditor == meId) return '${appStore.nameOf(s.debtor)} owes you';
    return '${appStore.nameOf(s.debtor)} owes ${appStore.nameOf(s.creditor)}';
  }

  String _who(String id) => id == meId ? 'You' : appStore.nameOf(id);

  void _showSettlementSheet(ExpenseGroup group, Settlement settlement) {
    final iOwe = settlement.debtor == meId;
    final other = appStore.personById(
      iOwe ? settlement.creditor : settlement.debtor,
    );
    final creditor = appStore.personById(settlement.creditor);
    final hasUpi = creditor != null && creditor.upi.isNotEmpty;
    final myUpi = appStore.hasProfile ? appStore.me.upi : '';

    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _owesText(settlement),
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      rupees(settlement.amount),
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                  ],
                ),
              ),
            ),
            if (iOwe) ...[
              ListTile(
                leading: const Icon(Icons.bolt_rounded),
                title: const Text('Pay with UPI'),
                subtitle: Text(
                  hasUpi ? creditor.upi : 'Add their UPI ID first',
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  _payUpi(settlement);
                },
              ),
              ListTile(
                leading: const Icon(Icons.qr_code_2_rounded),
                title: const Text('Show their QR for this amount'),
                subtitle: Text(
                  hasUpi ? creditor.name : 'Add their UPI ID first',
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  _showQr(
                    name: creditor?.name ?? '',
                    upi: creditor?.upi ?? '',
                    amount: settlement.amount,
                  );
                },
              ),
            ] else
              ListTile(
                leading: const Icon(Icons.qr_code_2_rounded),
                title: const Text('Show my QR for this amount'),
                subtitle: Text(
                  myUpi.isEmpty
                      ? 'Add your UPI ID in your profile first'
                      : 'Paying ${appStore.meName} ${rupees(settlement.amount)}',
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  _showQr(
                    name: appStore.meName,
                    upi: myUpi,
                    amount: settlement.amount,
                  );
                },
              ),
            ListTile(
              leading: const Icon(Icons.chat_outlined),
              title: Text(iOwe ? 'Tell them I paid' : 'Send a reminder'),
              subtitle: Text(
                other == null || other.phone.isEmpty
                    ? 'No phone number saved'
                    : 'SMS or WhatsApp, with optional QR',
              ),
              onTap: () {
                Navigator.pop(ctx);
                _sendMessage(group, settlement);
              },
            ),
            ListTile(
              leading: const Icon(Icons.check_circle_outline_rounded),
              title: const Text('Record a payment'),
              subtitle: const Text('Full or partial amount'),
              onTap: () {
                Navigator.pop(ctx);
                _recordPayment(group, settlement);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _sendMessage(ExpenseGroup group, Settlement settlement) {
    final iOwe = settlement.debtor == meId;
    final otherId = iOwe ? settlement.creditor : settlement.debtor;
    final other = appStore.personById(otherId);
    final otherName = appStore.nameOf(otherId);

    if (other == null || other.phone.isEmpty) {
      showMessage(context, 'Add a phone number for $otherName first');
      return;
    }

    final myUpi = appStore.hasProfile ? appStore.me.upi : '';
    var text = iOwe
        ? paidMessage(
            to: otherName,
            amount: settlement.amount,
            group: group.name,
          )
        : reminderMessage(
            to: otherName,
            from: appStore.meName,
            amount: settlement.amount,
            group: group.name,
            upi: myUpi,
          );
    if (appSettings.signature.isNotEmpty) {
      text = '$text ${appSettings.signature}';
    }

    showSendMessageSheet(
      context,
      toName: otherName,
      phone: other.phone,
      initialText: text,
      qr: !iOwe && myUpi.isNotEmpty
          ? PaymentQr(
              name: appStore.meName,
              upi: myUpi,
              amount: settlement.amount,
            )
          : null,
    );
  }

  void _showQr({
    required String name,
    required String upi,
    required double amount,
  }) {
    if (upi.isEmpty) {
      showMessage(context, 'No UPI ID saved for $name yet');
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => UpiQrScreen(name: name, upi: upi, amount: amount),
      ),
    );
  }

  void _openExpense(ExpenseGroup group, {GroupExpense? existing}) {
    final Widget screen = existing != null && existing.items.isNotEmpty
        ? BillReviewScreen(group: group, existing: existing)
        : AddExpenseScreen(group: group, existing: existing);
    Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
  }

  Future<void> _newGroup() async {
    final group = await Navigator.push<ExpenseGroup>(
      context,
      MaterialPageRoute(builder: (_) => const NewGroupScreen()),
    );
    if (group != null && mounted) {
      setState(() => _selectedId = group.id);
    }
  }

  Future<void> _editMembers(ExpenseGroup group) async {
    final picked = await pickPeople(
      context,
      title: 'Members of ${group.name}',
      initial: {...group.memberIds},
    );
    if (picked == null || !mounted) return;
    final blocked = appStore.setGroupMembers(group, picked);
    if (blocked.isNotEmpty) {
      showMessage(
        context,
        "Can't remove ${blocked.join(', ')} because they have expenses here",
      );
    }
  }

  Future<void> _generateBill(ExpenseGroup group) async {
    setState(() => _building = true);
    try {
      final bytes = await buildGroupBill(group);
      await Printing.sharePdf(
        bytes: bytes,
        filename: 'HisabKitab-${group.name}.pdf',
      );
    } catch (_) {
      if (mounted) showMessage(context, 'Could not create the bill');
    } finally {
      if (mounted) setState(() => _building = false);
    }
  }

  Future<void> _recordPayment(ExpenseGroup group, Settlement settlement) async {
    final controller = TextEditingController(
      text: settlement.amount.toStringAsFixed(2),
    );
    final amount = await showDialog<double>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Record a payment'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_owesText(settlement)),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: InputDecoration(
                labelText: 'Amount paid',
                prefixText: '₹ ',
                helperText: 'Up to ${rupees(settlement.amount)}',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final value = double.tryParse(controller.text.trim()) ?? 0;
              if (value <= 0) return;
              Navigator.pop(
                ctx,
                value > settlement.amount ? settlement.amount : value,
              );
            },
            child: const Text('Record'),
          ),
        ],
      ),
    );
    if (amount == null || !mounted) return;

    final recorded = appStore.recordSettlement(
      group: group,
      debtor: settlement.debtor,
      creditor: settlement.creditor,
      amount: amount,
    );
    showMessage(
      context,
      'Recorded ${rupees(amount)} as paid',
      SnackBarAction(
        label: 'Undo',
        onPressed: () => appStore.deleteExpense(recorded),
      ),
    );
  }

  Future<void> _payUpi(Settlement settlement) async {
    final creditor = appStore.personById(settlement.creditor);
    if (creditor == null) return;

    if (creditor.upi.isEmpty) {
      final details = await showPersonDialog(
        context,
        title: 'UPI ID for ${creditor.name}',
        name: creditor.name,
        upi: creditor.upi,
        phone: creditor.phone,
        photoPath: creditor.photoPath,
        editName: false,
      );
      if (details == null || !mounted) return;
      appStore.updatePerson(
        creditor,
        name: creditor.name,
        phone: details.phone,
        upi: details.upi,
      );
      if (creditor.upi.isEmpty) return;
    }

    final opened = await launchUpiPayment(
      upi: creditor.upi,
      name: creditor.name,
      amount: settlement.amount,
    );
    if (!opened && mounted) {
      showMessage(context, 'No UPI app opened. Pay ${creditor.upi} manually.');
    }
  }

  Future<void> _rename(ExpenseGroup group) async {
    final name = await _promptGroupName(group.name);
    if (name == null || name.isEmpty) return;
    appStore.renameGroup(group, name);
  }

  Future<String?> _promptGroupName(String initial) {
    final controller = TextEditingController(text: initial);
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Rename group'),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(labelText: 'Group name'),
          onSubmitted: (_) => Navigator.pop(ctx, controller.text.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteGroup(ExpenseGroup group) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete ${group.name}?'),
        content: const Text('All expenses in this group will be removed.'),
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
    appStore.deleteGroup(group);
    setState(() => _selectedId = null);
  }
}
