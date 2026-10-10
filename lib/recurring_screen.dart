import 'package:flutter/material.dart';

import 'categories.dart';
import 'models.dart';
import 'store.dart';
import 'widgets.dart';

class RecurringScreen extends StatelessWidget {
  const RecurringScreen({super.key});

  String _groupName(String id) {
    for (final g in appStore.groups) {
      if (g.id == id) return g.name;
    }
    return 'Deleted group';
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: appStore,
      builder: (context, _) {
        final rules = appStore.recurring;
        final scheme = Theme.of(context).colorScheme;

        return Scaffold(
          appBar: AppBar(title: const Text('Recurring expenses')),
          body: rules.isEmpty
              ? const EmptyState(
                  icon: Icons.event_repeat_rounded,
                  title: 'Nothing repeats yet',
                  message:
                      'When adding an expense, choose Weekly or Monthly under '
                      'Repeat. Rent and subscriptions then add themselves.',
                )
              : ListView.builder(
                  padding: const EdgeInsets.only(top: 8, bottom: 24),
                  itemCount: rules.length,
                  itemBuilder: (context, i) {
                    final rule = rules[i];
                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 4,
                      ),
                      leading: CircleAvatar(
                        backgroundColor: scheme.secondaryContainer,
                        foregroundColor: scheme.onSecondaryContainer,
                        child: Icon(categoryOf(rule.category).icon),
                      ),
                      title: Text(rule.title),
                      subtitle: Text(
                        '${rule.frequency == Frequency.weekly ? 'Weekly' : 'Monthly'}'
                        ' • next ${formatDate(rule.nextDue)}'
                        ' • ${_groupName(rule.groupId)}',
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            rupees(rule.amount),
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          IconButton(
                            tooltip: 'Stop repeating',
                            icon: const Icon(Icons.close_rounded),
                            onPressed: () {
                              appStore.deleteRecurring(rule);
                              showMessage(
                                context,
                                '${rule.title} will not repeat',
                                SnackBarAction(
                                  label: 'Undo',
                                  onPressed: () => appStore.addRecurring(rule),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    );
                  },
                ),
        );
      },
    );
  }
}
