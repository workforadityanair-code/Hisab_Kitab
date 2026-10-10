import 'package:flutter/material.dart';

import 'categories.dart';
import 'store.dart';
import 'widgets.dart';

const _months = [
  'January',
  'February',
  'March',
  'April',
  'May',
  'June',
  'July',
  'August',
  'September',
  'October',
  'November',
  'December',
];

class InsightsScreen extends StatefulWidget {
  const InsightsScreen({super.key, this.groupId});

  final String? groupId;

  @override
  State<InsightsScreen> createState() => _InsightsScreenState();
}

class _InsightsScreenState extends State<InsightsScreen> {
  late DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);
  late String? _groupId = widget.groupId;

  void _shift(int delta) =>
      setState(() => _month = DateTime(_month.year, _month.month + delta));

  bool _inMonth(DateTime d) => d.year == _month.year && d.month == _month.month;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return ListenableBuilder(
      listenable: appStore,
      builder: (context, _) {
        final expenses = appStore.allExpenses
            .where(
              (e) =>
                  !e.isSettlement &&
                  _inMonth(e.createdAt) &&
                  (_groupId == null || e.groupId == _groupId),
            )
            .toList();

        final total = expenses.fold(0.0, (s, e) => s + e.amount);
        final myShare = expenses.fold(
          0.0,
          (s, e) => s + (e.splitShares[meId] ?? 0),
        );
        final iPaid = expenses
            .where((e) => e.paidBy == meId)
            .fold(0.0, (s, e) => s + e.amount);
        final tax = expenses.fold(0.0, (s, e) => s + e.taxAmount);

        final byCategory = <String, double>{};
        for (final e in expenses) {
          final id = e.category.isEmpty ? 'other' : e.category;
          byCategory[id] = (byCategory[id] ?? 0) + e.amount;
        }
        final sorted = byCategory.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value));
        final biggest = [...expenses]
          ..sort((a, b) => b.amount.compareTo(a.amount));

        return Scaffold(
          appBar: AppBar(title: const Text('Insights')),
          body: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Row(
                children: [
                  IconButton(
                    tooltip: 'Previous month',
                    icon: const Icon(Icons.chevron_left_rounded),
                    onPressed: () => _shift(-1),
                  ),
                  Expanded(
                    child: Text(
                      '${_months[_month.month - 1]} ${_month.year}',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.titleLarge,
                    ),
                  ),
                  IconButton(
                    tooltip: 'Next month',
                    icon: const Icon(Icons.chevron_right_rounded),
                    onPressed: () => _shift(1),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 44,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: const Text('All groups'),
                        selected: _groupId == null,
                        onSelected: (_) => setState(() => _groupId = null),
                      ),
                    ),
                    for (final g in appStore.groups)
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(g.name),
                          selected: _groupId == g.id,
                          onSelected: (_) => setState(() => _groupId = g.id),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(child: _stat('Total spent', rupees(total))),
                  const SizedBox(width: 12),
                  Expanded(child: _stat('Your share', rupees(myShare))),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(child: _stat('You paid', rupees(iPaid))),
                  const SizedBox(width: 12),
                  Expanded(child: _stat('Tax included', rupees(tax))),
                ],
              ),
              const SizedBox(height: 24),
              Text('By category', style: theme.textTheme.titleSmall),
              const SizedBox(height: 12),
              if (sorted.isEmpty)
                Text(
                  'No expenses in this month.',
                  style: TextStyle(color: scheme.onSurfaceVariant),
                ),
              for (final entry in sorted) _categoryRow(entry, total),
              if (biggest.isNotEmpty) ...[
                const SizedBox(height: 24),
                Text('Biggest expenses', style: theme.textTheme.titleSmall),
                const SizedBox(height: 4),
                for (final e in biggest.take(3))
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: CircleAvatar(
                      backgroundColor: scheme.secondaryContainer,
                      foregroundColor: scheme.onSecondaryContainer,
                      child: Icon(categoryOf(e.category).icon),
                    ),
                    title: Text(e.title),
                    subtitle: Text(formatDate(e.createdAt)),
                    trailing: Text(
                      rupees(e.amount),
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _stat(String label, String value) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: TextStyle(color: scheme.onSurfaceVariant)),
            const SizedBox(height: 4),
            Text(
              value,
              style: Theme.of(context).textTheme.titleLarge
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    );
  }

  Widget _categoryRow(MapEntry<String, double> entry, double total) {
    final category = categoryOf(entry.key);
    final fraction = total <= 0 ? 0.0 : entry.value / total;

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        children: [
          Row(
            children: [
              Icon(category.icon, size: 20),
              const SizedBox(width: 10),
              Expanded(child: Text(category.label)),
              Text(
                rupees(entry.value),
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(value: fraction, minHeight: 8),
          ),
        ],
      ),
    );
  }
}
