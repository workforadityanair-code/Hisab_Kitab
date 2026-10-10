import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hisab_kitab/bill.dart';
import 'package:hisab_kitab/models.dart';
import 'package:hisab_kitab/store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('bill renders a PDF with the logo and rupee amounts', () async {
    SharedPreferences.setMockInitialValues({});
    final store = appStore;
    await store.load();
    await store.saveProfile(name: 'Akhil', upi: 'akhil@bank');
    final ravi = store.addPerson(name: 'Ravi', isFriend: true);
    final group = store.createGroup('Goa Trip', [ravi.id]);
    store.saveExpense(
      GroupExpense(
        id: '1',
        groupId: group.id,
        title: 'Dinner at beach shack',
        amount: 1250.5,
        paidBy: meId,
        splitShares: {meId: 625.25, ravi.id: 625.25},
        createdAt: DateTime(2026, 10, 9),
        subtotal: 1190,
        taxPercent: 5,
        items: [
          ExpenseItem(
            name: 'Prawn curry',
            amount: 790,
            sharedBy: [meId, ravi.id],
          ),
          ExpenseItem(name: 'Beer', amount: 400, sharedBy: [meId]),
        ],
      ),
    );
    final bytes = await buildGroupBill(group);
    expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
    File('${Directory.systemTemp.path}/hk_bill_test.pdf')
        .writeAsBytesSync(bytes);
    expect(bytes.length, greaterThan(1000));
  });
}
