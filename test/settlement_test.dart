import 'package:flutter_test/flutter_test.dart';
import 'package:hisab_kitab/models.dart';
import 'package:hisab_kitab/settlement.dart';
import 'package:hisab_kitab/store.dart';
import 'package:shared_preferences/shared_preferences.dart';

GroupExpense _expense(
  String id,
  double amount,
  String paidBy,
  Map<String, double> shares, {
  String groupId = 'g',
}) => GroupExpense(
  id: id,
  groupId: groupId,
  title: 'Expense $id',
  amount: amount,
  paidBy: paidBy,
  splitShares: shares,
  createdAt: DateTime(2026),
);

Future<AppStore> _storeWithMe() async {
  SharedPreferences.setMockInitialValues({});
  final store = AppStore();
  await store.load();
  await store.saveProfile(name: 'Me', upi: 'me@bank');
  return store;
}

void main() {
  test('equal split creates one settlement per debtor', () {
    final balances = computeBalances(
      ['A', 'B', 'C'],
      [
        _expense('1', 300, 'A', {'A': 100, 'B': 100, 'C': 100}),
      ],
    );
    final settlements = computeSettlements(balances);

    expect(settlements.length, 2);
    expect(settlements.every((s) => s.creditor == 'A'), isTrue);
    expect(settlements.map((s) => s.amount), everyElement(closeTo(100, 0.001)));
  });

  test('balanced group has no settlements', () {
    final balances = computeBalances(
      ['A', 'B'],
      [
        _expense('1', 100, 'A', {'A': 50, 'B': 50}),
        _expense('2', 100, 'B', {'A': 50, 'B': 50}),
      ],
    );
    expect(computeSettlements(balances), isEmpty);
  });

  test('recording a settlement clears the debt', () async {
    final store = await _storeWithMe();
    final ravi = store.addPerson(name: 'Ravi', isFriend: true);
    final group = store.createGroup('Trip', [ravi.id]);
    store.saveExpense(
      _expense('1', 200, meId, {meId: 100, ravi.id: 100}, groupId: group.id),
    );

    expect(store.settlementsFor(group).single.amount, closeTo(100, 0.001));

    store.recordSettlement(
      group: group,
      debtor: ravi.id,
      creditor: meId,
      amount: 100,
    );
    expect(store.settlementsFor(group), isEmpty);
  });

  test('a friend keeps their details across every group', () async {
    final store = await _storeWithMe();
    final ravi = store.addPerson(name: 'Ravi', isFriend: true);
    final trip = store.createGroup('Trip', [ravi.id]);
    final flat = store.createGroup('Flat', [ravi.id]);

    store.updatePerson(ravi, name: 'Ravi K', phone: '9999999999', upi: 'r@x');

    expect(store.membersOf(trip).map((p) => p.name), contains('Ravi K'));
    expect(store.membersOf(flat).map((p) => p.upi), contains('r@x'));
  });

  test('unfriending keeps the person in their groups', () async {
    final store = await _storeWithMe();
    final ravi = store.addPerson(name: 'Ravi', isFriend: true);
    final group = store.createGroup('Trip', [ravi.id]);

    store.setFriend(ravi, false);

    expect(store.friends.map((p) => p.id), isNot(contains(ravi.id)));
    expect(store.membersOf(group).map((p) => p.id), contains(ravi.id));
  });

  test('the default group always exists and cannot be deleted', () async {
    final store = await _storeWithMe();
    expect(store.defaultGroup.isDefault, isTrue);
    store.deleteGroup(store.defaultGroup);
    expect(store.groups.where((g) => g.isDefault), hasLength(1));
  });

  test('members with expenses cannot be removed from a group', () async {
    final store = await _storeWithMe();
    final ravi = store.addPerson(name: 'Ravi');
    final group = store.createGroup('Trip', [ravi.id]);
    store.saveExpense(
      _expense('1', 60, meId, {meId: 30, ravi.id: 30}, groupId: group.id),
    );

    final blocked = store.setGroupMembers(group, {});
    expect(blocked, ['Ravi']);
    expect(group.memberIds, contains(ravi.id));
  });

  test('legacy name-based data migrates to people and ids', () async {
    SharedPreferences.setMockInitialValues({
      'hk_display_name': 'Akhil',
      'hk_upi': 'akhil@bank',
      'hk_groups':
          '[{"id":"g1","name":"Trip","emoji":"x",'
          '"members":[{"name":"Akhil","upiId":""},'
          '{"name":"Ravi","upiId":"r@x","phone":"9999999999"}]}]',
      'hk_expenses':
          '[{"groupId":"g1","title":"Cab","amount":90,"paidBy":"Akhil",'
          '"splitAmong":["Akhil","Ravi","Sam"],"categoryEmoji":"x"}]',
    });
    final store = AppStore();
    await store.load();

    expect(store.me.name, 'Akhil');
    expect(store.me.upi, 'akhil@bank');
    final trip = store.groups.firstWhere((g) => g.id == 'g1');
    expect(trip.memberIds, contains(meId));
    final ravi = store.membersOf(trip).firstWhere((p) => p.name == 'Ravi');
    expect(ravi.upi, 'r@x');
    expect(ravi.isFriend, isTrue);
    final cab = store.expensesFor('g1').single;
    expect(cab.paidBy, meId);
    expect(cab.splitShares.values, everyElement(closeTo(30, 0.001)));
    expect(store.nameOf(cab.splitShares.keys.last), isNotEmpty);
  });

  test('tax and items survive a save and reload', () async {
    SharedPreferences.setMockInitialValues({});
    final store = AppStore();
    await store.load();
    await store.saveProfile(name: 'Me');
    final ravi = store.addPerson(name: 'Ravi');
    final group = store.createGroup('Trip', [ravi.id]);

    store.saveExpense(
      GroupExpense(
        id: 'bill',
        groupId: group.id,
        title: 'Dinner',
        amount: 210,
        paidBy: meId,
        splitShares: {meId: 105, ravi.id: 105},
        createdAt: DateTime(2026),
        subtotal: 200,
        taxPercent: 5,
        items: [
          ExpenseItem(name: 'Paneer', amount: 120, sharedBy: [meId, ravi.id]),
          ExpenseItem(name: 'Naan', amount: 80, sharedBy: [meId, ravi.id]),
        ],
      ),
    );

    final raw = store.expensesFor(group.id).single.toJson();
    final loaded = GroupExpense.fromJson(raw);
    expect(loaded.taxPercent, 5);
    expect(loaded.subtotal, 200);
    expect(loaded.taxAmount, closeTo(10, 0.001));
    expect(loaded.items.map((i) => i.name), ['Paneer', 'Naan']);
  });

  test('expenses saved before tax existed load with no tax', () {
    final expense = GroupExpense.fromJson({
      'id': 'old',
      'groupId': 'g',
      'title': 'Cab',
      'amount': 90,
      'paidBy': 'me',
      'splitShares': {'me': 45, 'x': 45},
      'createdAt': '2026-01-01T00:00:00.000',
    });
    expect(expense.taxPercent, 0);
    expect(expense.subtotal, 90);
    expect(expense.taxAmount, 0);
    expect(expense.items, isEmpty);
  });
}
