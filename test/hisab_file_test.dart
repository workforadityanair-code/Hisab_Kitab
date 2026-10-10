import 'package:flutter_test/flutter_test.dart';
import 'package:hisab_kitab/categories.dart';
import 'package:hisab_kitab/hisab_file.dart';
import 'package:hisab_kitab/models.dart';
import 'package:hisab_kitab/store.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> _freshPhone(String name, {String upi = ''}) async {
  SharedPreferences.setMockInitialValues({});
  await appStore.load();
  await appStore.saveProfile(name: name, upi: upi);
}

String _senderGroupFile() {
  final ravi = appStore.addPerson(
    name: 'Ravi',
    phone: '9999999999',
    isFriend: true,
  );
  final group = appStore.createGroup('Goa Trip', [ravi.id]);
  appStore.saveExpense(
    GroupExpense(
      id: 'e1',
      groupId: group.id,
      title: 'Dinner',
      amount: 1050,
      paidBy: meId,
      splitShares: {meId: 525, ravi.id: 525},
      createdAt: DateTime(2026, 10, 9),
      subtotal: 1000,
      taxPercent: 5,
      category: 'food',
    ),
  );
  return buildGroupFile(group);
}

void main() {
  test('a shared group loads on another phone with the right people', () async {
    await _freshPhone('Aditya', upi: 'aditya@bank');
    final file = _senderGroupFile();

    await _freshPhone('Ravi');
    final package = parseHisabFile(file);
    expect(package.isBackup, isFalse);
    expect(package.senderName, 'Aditya');

    final candidates = candidateNames(package);
    final raviId = candidates.entries.firstWhere((e) => e.value == 'Ravi').key;

    final summary = await importGroup(package, chosenMeId: raviId);
    expect(summary.added, 1);
    expect(summary.updated, 0);

    final group = appStore.groups.firstWhere((g) => g.id == summary.groupId);
    expect(group.name, 'Goa Trip');
    expect(group.memberIds, contains(meId));

    final dinner = appStore.expensesFor(group.id).single;
    expect(dinner.taxPercent, 5);
    expect(dinner.category, 'food');
    expect(dinner.splitShares[meId], closeTo(525, 0.001));
    expect(dinner.paidBy, isNot(meId));
    expect(appStore.nameOf(dinner.paidBy), 'Aditya');

    final owed = appStore.settlementsFor(group).single;
    expect(owed.debtor, meId);
    expect(appStore.nameOf(owed.creditor), 'Aditya');
    expect(owed.amount, closeTo(525, 0.001));
  });

  test('loading the same group again updates instead of duplicating', () async {
    await _freshPhone('Aditya');
    final file = _senderGroupFile();

    await _freshPhone('Ravi');
    final package = parseHisabFile(file);
    final raviId = candidateNames(package).entries
        .firstWhere((e) => e.value == 'Ravi')
        .key;

    await importGroup(package, chosenMeId: raviId);
    expect(detectMe(package), raviId);

    final again = await importGroup(package, chosenMeId: detectMe(package));
    expect(again.added, 0);
    expect(again.updated, 1);
    expect(appStore.expensesFor(again.groupId), hasLength(1));
    expect(appStore.groups.where((g) => g.id == again.groupId), hasLength(1));
  });

  test('sharing the Everyday group does not overwrite the receiver', () async {
    await _freshPhone('Aditya');
    appStore.saveExpense(
      GroupExpense(
        id: 'e2',
        groupId: defaultGroupId,
        title: 'Chai',
        amount: 40,
        paidBy: meId,
        splitShares: {meId: 40},
        createdAt: DateTime(2026, 10, 9),
      ),
    );
    final file = buildGroupFile(appStore.defaultGroup);

    await _freshPhone('Ravi');
    final package = parseHisabFile(file);
    await importGroup(package);

    expect(appStore.groups.where((g) => g.isDefault), hasLength(1));
    expect(appStore.expensesFor(defaultGroupId), isEmpty);
    expect(appStore.groups, hasLength(2));
  });

  test('a backup restores everything, including recurring rules', () async {
    await _freshPhone('Aditya', upi: 'aditya@bank');
    final file = _senderGroupFile();
    final group = appStore.groups.firstWhere((g) => g.name == 'Goa Trip');
    appStore.addRecurring(
      RecurringExpense(
        id: 'r1',
        groupId: group.id,
        title: 'Wifi',
        amount: 500,
        subtotal: 500,
        taxPercent: 0,
        paidBy: meId,
        splitShares: {meId: 250, appStore.friends.first.id: 250},
        category: 'bills',
        frequency: Frequency.monthly,
        nextDue: DateTime.now().add(const Duration(days: 20)),
      ),
    );
    expect(file, isNotEmpty);
    final backup = buildBackupFile();

    await _freshPhone('Someone Else');
    await restoreBackup(parseHisabFile(backup));

    expect(appStore.me.name, 'Aditya');
    expect(appStore.me.upi, 'aditya@bank');
    expect(appStore.friends.map((p) => p.name), contains('Ravi'));
    expect(appStore.recurring.single.title, 'Wifi');
    final restored = appStore.groups.firstWhere((g) => g.name == 'Goa Trip');
    expect(appStore.expensesFor(restored.id), hasLength(1));
    expect(appStore.expensesFor(restored.id).single.paidBy, meId);
  });

  test('files that are not HisabKitab files are rejected', () {
    expect(() => parseHisabFile('hello'), throwsA(isA<HisabFormatException>()));
    expect(
      () => parseHisabFile('{"format":"other"}'),
      throwsA(isA<HisabFormatException>()),
    );
  });

  test('due recurring expenses are created and rescheduled', () async {
    await _freshPhone('Aditya');
    final ravi = appStore.addPerson(name: 'Ravi', isFriend: true);
    final group = appStore.createGroup('Flat', [ravi.id]);
    final start = DateTime.now().subtract(const Duration(days: 70));
    appStore.addRecurring(
      RecurringExpense(
        id: 'rent',
        groupId: group.id,
        title: 'Rent',
        amount: 20000,
        subtotal: 20000,
        taxPercent: 0,
        paidBy: meId,
        splitShares: {meId: 10000, ravi.id: 10000},
        category: 'rent',
        frequency: Frequency.monthly,
        nextDue: start,
      ),
    );

    final created = appStore.applyDueRecurring();
    expect(created, greaterThanOrEqualTo(2));
    expect(appStore.expensesFor(group.id), hasLength(created));
    expect(appStore.recurring.single.nextDue.isAfter(DateTime.now()), isTrue);
    expect(appStore.applyDueRecurring(), 0);
  });

  test('the balance with a friend adds up across groups', () async {
    await _freshPhone('Aditya');
    final ravi = appStore.addPerson(name: 'Ravi', isFriend: true);
    final trip = appStore.createGroup('Trip', [ravi.id]);
    final flat = appStore.createGroup('Flat', [ravi.id]);

    appStore.saveExpense(
      GroupExpense(
        id: 'a',
        groupId: trip.id,
        title: 'Cab',
        amount: 200,
        paidBy: meId,
        splitShares: {meId: 100, ravi.id: 100},
        createdAt: DateTime(2026),
      ),
    );
    appStore.saveExpense(
      GroupExpense(
        id: 'b',
        groupId: flat.id,
        title: 'Gas',
        amount: 300,
        paidBy: ravi.id,
        splitShares: {meId: 150, ravi.id: 150},
        createdAt: DateTime(2026),
      ),
    );

    final balances = appStore.balancesWith(ravi.id);
    expect(balances, hasLength(2));
    final net = balances.fold(0.0, (s, b) => s + b.amount);
    expect(net, closeTo(100 - 150, 0.001));
  });

  test('categories are guessed from the description', () {
    expect(guessCategory('Dinner at Truffles'), 'food');
    expect(guessCategory('Uber to airport'), 'travel');
    expect(guessCategory('Flat rent'), 'rent');
    expect(guessCategory('Something random'), 'other');
  });
}
