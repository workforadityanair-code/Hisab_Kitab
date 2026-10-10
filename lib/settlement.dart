import 'dart:math';

import 'models.dart';

const _tolerance = 0.005;

class Settlement {
  const Settlement({
    required this.debtor,
    required this.creditor,
    required this.amount,
  });

  final String debtor;
  final String creditor;
  final double amount;
}

Map<String, double> computeBalances(
  List<String> memberIds,
  List<GroupExpense> expenses,
) {
  final balances = {for (final id in memberIds) id: 0.0};
  for (final expense in expenses) {
    balances[expense.paidBy] = (balances[expense.paidBy] ?? 0) + expense.amount;
    expense.splitShares.forEach((id, share) {
      balances[id] = (balances[id] ?? 0) - share;
    });
  }
  return balances;
}

List<Settlement> computeSettlements(Map<String, double> balances) {
  final debtors = <MapEntry<String, double>>[];
  final creditors = <MapEntry<String, double>>[];
  balances.forEach((id, balance) {
    if (balance < -_tolerance) debtors.add(MapEntry(id, -balance));
    if (balance > _tolerance) creditors.add(MapEntry(id, balance));
  });

  final settlements = <Settlement>[];
  var d = 0;
  var c = 0;
  while (d < debtors.length && c < creditors.length) {
    final amount = min(debtors[d].value, creditors[c].value);
    settlements.add(
      Settlement(
        debtor: debtors[d].key,
        creditor: creditors[c].key,
        amount: amount,
      ),
    );
    debtors[d] = MapEntry(debtors[d].key, debtors[d].value - amount);
    creditors[c] = MapEntry(creditors[c].key, creditors[c].value - amount);
    if (debtors[d].value <= _tolerance) d++;
    if (creditors[c].value <= _tolerance) c++;
  }
  return settlements;
}
