import 'package:flutter/material.dart';

import 'message_sheet.dart';
import 'messaging.dart';
import 'media.dart';
import 'payment_qr.dart';
import 'store.dart';
import 'upi_qr_screen.dart';
import 'widgets.dart';

class PersonScreen extends StatelessWidget {
  const PersonScreen({super.key, required this.personId});

  final String personId;

  Future<void> _edit(BuildContext context) async {
    final person = appStore.personById(personId);
    if (person == null) return;
    final details = await showPersonDialog(
      context,
      title: 'Edit ${person.name}',
      name: person.name,
      phone: person.phone,
      upi: person.upi,
      photoPath: person.photoPath,
    );
    if (details == null) return;
    final photo = await commitPhoto(details.photo, person.photoPath, 'people');
    appStore.updatePerson(
      person,
      name: details.name,
      phone: details.phone,
      upi: details.upi,
    );
    if (photo != person.photoPath) appStore.setPersonPhoto(person, photo);
  }

  void _settleAll(BuildContext context, List<PairBalance> balances) {
    final recorded = <String>[];
    for (final b in balances) {
      final iOwe = b.amount < 0;
      final entry = appStore.recordSettlement(
        group: b.group,
        debtor: iOwe ? meId : personId,
        creditor: iOwe ? personId : meId,
        amount: b.amount.abs(),
      );
      recorded.add(entry.id);
    }
    showMessage(
      context,
      'Marked ${balances.length} balance${balances.length == 1 ? '' : 's'} as paid',
      SnackBarAction(
        label: 'Undo',
        onPressed: () {
          for (final e in appStore.allExpenses.where(
            (e) => recorded.contains(e.id),
          )) {
            appStore.deleteExpense(e);
          }
        },
      ),
    );
  }

  void _remind(BuildContext context, double total) {
    final person = appStore.personById(personId);
    if (person == null) return;
    if (person.phone.isEmpty) {
      showMessage(context, 'Add a phone number for ${person.name} first');
      return;
    }
    final myUpi = appStore.hasProfile ? appStore.me.upi : '';
    showSendMessageSheet(
      context,
      toName: person.name,
      phone: person.phone,
      initialText: reminderMessage(
        to: person.name,
        from: appStore.meName,
        amount: total,
        group: 'all our groups',
        upi: myUpi,
      ),
      qr: myUpi.isNotEmpty
          ? PaymentQr(name: appStore.meName, upi: myUpi, amount: total)
          : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: appStore,
      builder: (context, _) {
        final person = appStore.personById(personId);
        if (person == null) {
          return Scaffold(
            appBar: AppBar(),
            body: const EmptyState(
              icon: Icons.person_off_outlined,
              title: 'This person is no longer here',
            ),
          );
        }

        final theme = Theme.of(context);
        final scheme = theme.colorScheme;
        final balances = appStore.balancesWith(personId);
        final total = balances.fold(0.0, (sum, b) => sum + b.amount);
        final settled = total.abs() < 0.005;
        final owesMe = total > 0;

        return Scaffold(
          appBar: AppBar(
            title: Text(person.name),
            actions: [
              IconButton(
                tooltip: 'Edit',
                icon: const Icon(Icons.edit_outlined),
                onPressed: () => _edit(context),
              ),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Center(
                child: NameAvatar(
                  name: person.name,
                  photoPath: person.photoPath,
                  radius: 44,
                ),
              ),
              const SizedBox(height: 12),
              Center(
                child: Text(
                  [
                    if (person.phone.isNotEmpty) person.phone,
                    if (person.upi.isNotEmpty) person.upi,
                  ].join(' • '),
                  style: TextStyle(color: scheme.onSurfaceVariant),
                ),
              ),
              const SizedBox(height: 20),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        settled
                            ? 'Settled up'
                            : owesMe
                            ? '${person.name} owes you'
                            : 'You owe ${person.name}',
                        style: TextStyle(color: scheme.onSurfaceVariant),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        settled ? 'All clear' : rupees(total.abs()),
                        style: theme.textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: settled
                              ? scheme.onSurface
                              : owesMe
                              ? scheme.primary
                              : scheme.error,
                        ),
                      ),
                      if (!settled)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            'Across ${balances.length} '
                            '${balances.length == 1 ? 'group' : 'groups'}',
                            style: TextStyle(color: scheme.onSurfaceVariant),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (!settled)
                    FilledButton.icon(
                      onPressed: () => _settleAll(context, balances),
                      icon: const Icon(Icons.check_circle_outline_rounded),
                      label: const Text('Mark all paid'),
                    ),
                  if (!settled && owesMe)
                    FilledButton.tonalIcon(
                      onPressed: () => _remind(context, total),
                      icon: const Icon(Icons.chat_outlined),
                      label: const Text('Remind'),
                    ),
                  if (person.upi.isNotEmpty)
                    OutlinedButton.icon(
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => UpiQrScreen(
                            name: person.name,
                            upi: person.upi,
                            amount: !settled && !owesMe ? total.abs() : null,
                          ),
                        ),
                      ),
                      icon: const Icon(Icons.qr_code_2_rounded),
                      label: const Text('Their QR'),
                    ),
                ],
              ),
              const SizedBox(height: 24),
              Text('By group', style: theme.textTheme.titleSmall),
              const SizedBox(height: 8),
              if (balances.isEmpty)
                Text(
                  'Nothing pending in any group.',
                  style: TextStyle(color: scheme.onSurfaceVariant),
                ),
              for (final b in balances)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: NameAvatar(
                    name: b.group.name,
                    photoPath: b.group.photoPath,
                  ),
                  title: Text(b.group.name),
                  subtitle: Text(
                    b.amount > 0
                        ? '${person.name} owes you'
                        : 'You owe ${person.name}',
                  ),
                  trailing: Text(
                    rupees(b.amount.abs()),
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: b.amount > 0 ? scheme.primary : scheme.error,
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
