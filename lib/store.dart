import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'models.dart';
import 'settlement.dart';

const meId = 'me';
const defaultGroupId = 'everyday';

const _peopleKey = 'hk3_people';
const _groupsKey = 'hk3_groups';
const _expensesKey = 'hk3_expenses';
const _recurringKey = 'hk3_recurring';
const _aliasesKey = 'hk3_aliases';
const _profileIdKey = 'hk3_profile_id';

int _lastId = 0;

String newId() {
  final now = DateTime.now().microsecondsSinceEpoch;
  _lastId = now > _lastId ? now : _lastId + 1;
  return _lastId.toString();
}

class PairBalance {
  const PairBalance(this.group, this.amount);

  final ExpenseGroup group;
  final double amount;
}

List<Map<String, dynamic>> _decodeList(String? raw) {
  if (raw == null) return [];
  try {
    return (jsonDecode(raw) as List).cast<Map<String, dynamic>>();
  } catch (_) {
    return [];
  }
}

int _byName(Person a, Person b) =>
    a.name.toLowerCase().compareTo(b.name.toLowerCase());

class AppStore extends ChangeNotifier {
  List<Person> _people = [];
  List<ExpenseGroup> _groups = [];
  List<GroupExpense> _expenses = [];
  List<RecurringExpense> _recurring = [];
  Map<String, String> _aliases = {};
  String _profileId = '';
  bool _loaded = false;

  bool get loaded => _loaded;
  bool get hasProfile => _people.any((p) => p.isMe);
  Person get me => _people.firstWhere((p) => p.isMe);
  String get meName => hasProfile ? me.name : 'You';
  List<ExpenseGroup> get groups => List.unmodifiable(_groups);
  List<Person> get people => List.unmodifiable(_people);
  List<GroupExpense> get allExpenses => List.unmodifiable(_expenses);
  List<RecurringExpense> get recurring => List.unmodifiable(_recurring);
  Map<String, String> get aliases => Map.unmodifiable(_aliases);
  String get profileId => _profileId;
  ExpenseGroup get defaultGroup => _groups.firstWhere((g) => g.isDefault);

  List<Person> get friends =>
      _people.where((p) => p.isFriend && !p.isMe).toList()..sort(_byName);

  List<Person> get selectablePeople =>
      _people.where((p) => !p.isMe).toList()..sort((a, b) {
        if (a.isFriend != b.isFriend) return a.isFriend ? -1 : 1;
        return _byName(a, b);
      });

  Person? personById(String id) {
    for (final p in _people) {
      if (p.id == id) return p;
    }
    return null;
  }

  String nameOf(String id) =>
      id == meId && hasProfile ? me.name : personById(id)?.name ?? 'Unknown';

  List<Person> membersOf(ExpenseGroup group) =>
      group.memberIds.map(personById).whereType<Person>().toList();

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _people = [];
    _groups = [];
    _expenses = [];
    _recurring = [];
    _aliases = {};
    if (prefs.containsKey(_peopleKey)) {
      _people = _decodeList(prefs.getString(_peopleKey))
          .map(Person.fromJson)
          .toList();
      _groups = _decodeList(prefs.getString(_groupsKey))
          .map(ExpenseGroup.fromJson)
          .toList();
      _expenses = _decodeList(prefs.getString(_expensesKey))
          .map(GroupExpense.fromJson)
          .toList();
      _recurring = _decodeList(prefs.getString(_recurringKey))
          .map(RecurringExpense.fromJson)
          .toList();
      final rawAliases = prefs.getString(_aliasesKey);
      if (rawAliases != null) {
        try {
          _aliases = Map<String, String>.from(jsonDecode(rawAliases) as Map);
        } catch (_) {
          _aliases = {};
        }
      }
    } else {
      _migrateLegacy(prefs);
    }
    _profileId = prefs.getString(_profileIdKey) ?? 'u${newId()}';
    await prefs.setString(_profileIdKey, _profileId);
    _ensureDefaultGroup();
    _applyDueRecurring();
    _loaded = true;
    await _save();
    notifyListeners();
  }

  int applyDueRecurring() {
    final created = _applyDueRecurring();
    if (created > 0) _changed();
    return created;
  }

  int _applyDueRecurring() {
    final now = DateTime.now();
    var created = 0;
    for (final rule in _recurring) {
      var guard = 0;
      while (!rule.nextDue.isAfter(now) && guard < 36) {
        if (_groups.any((g) => g.id == rule.groupId)) {
          _expenses.add(rule.occurrence(newId(), rule.nextDue));
          created++;
        }
        rule.nextDue = rule.advance(rule.nextDue);
        guard++;
      }
    }
    return created;
  }

  void _migrateLegacy(SharedPreferences prefs) {
    final meName =
        prefs.getString('hk_me') ?? prefs.getString('hk_display_name');
    if (meName != null) {
      _people.add(
        Person(
          id: meId,
          name: meName,
          upi: prefs.getString('hk_upi') ?? '',
          phone: prefs.getString('hk_phone') ?? '',
          isMe: true,
        ),
      );
    }

    String idFor(String name, {String upi = '', String phone = ''}) {
      if (meName != null && name == meName) return meId;
      for (final p in _people) {
        if (p.name == name) return p.id;
      }
      final person = Person(
        id: newId(),
        name: name,
        upi: upi,
        phone: phone,
        isFriend: true,
      );
      _people.add(person);
      return person.id;
    }

    for (final raw in _decodeList(prefs.getString('hk_groups'))) {
      final memberIds = <String>[];
      for (final m in raw['members'] as List) {
        if (m is String) {
          memberIds.add(idFor(m));
        } else {
          final map = m as Map<String, dynamic>;
          memberIds.add(
            idFor(
              map['name'] as String,
              upi: (map['upiId'] ?? '') as String,
              phone: (map['phone'] ?? '') as String,
            ),
          );
        }
      }
      _groups.add(
        ExpenseGroup(
          id: raw['id'] as String? ?? newId(),
          name: raw['name'] as String,
          memberIds: memberIds.toSet().toList(),
        ),
      );
    }

    for (final raw in _decodeList(prefs.getString('hk_expenses'))) {
      final amount = (raw['amount'] as num).toDouble();
      final shares = <String, double>{};
      if (raw['splitShares'] is Map) {
        (raw['splitShares'] as Map).forEach((k, v) {
          shares[idFor(k as String)] = (v as num).toDouble();
        });
      } else if (raw['splitAmong'] is List) {
        final names = List<String>.from(raw['splitAmong'] as List);
        for (final n in names) {
          shares[idFor(n)] = amount / names.length;
        }
      }
      _expenses.add(
        GroupExpense(
          id: raw['id'] as String? ?? newId(),
          groupId: raw['groupId'] as String,
          title: raw['title'] as String,
          amount: amount,
          paidBy: idFor(raw['paidBy'] as String),
          splitShares: shares,
          createdAt: raw['createdAt'] != null
              ? DateTime.parse(raw['createdAt'] as String)
              : DateTime.fromMillisecondsSinceEpoch(0),
          isSettlement: (raw['isSettlement'] ?? false) as bool,
        ),
      );
    }
  }

  void _ensureDefaultGroup() {
    if (!_groups.any((g) => g.isDefault)) {
      _groups.insert(
        0,
        ExpenseGroup(
          id: defaultGroupId,
          name: 'Everyday',
          memberIds: [meId],
          isDefault: true,
        ),
      );
    }
    for (final group in _groups) {
      if (!group.memberIds.contains(meId)) group.memberIds.insert(0, meId);
    }
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _peopleKey,
      jsonEncode(_people.map((p) => p.toJson()).toList()),
    );
    await prefs.setString(
      _groupsKey,
      jsonEncode(_groups.map((g) => g.toJson()).toList()),
    );
    await prefs.setString(
      _expensesKey,
      jsonEncode(_expenses.map((e) => e.toJson()).toList()),
    );
    await prefs.setString(
      _recurringKey,
      jsonEncode(_recurring.map((r) => r.toJson()).toList()),
    );
    await prefs.setString(_aliasesKey, jsonEncode(_aliases));
    await prefs.setString(_profileIdKey, _profileId);
  }

  void _changed() {
    notifyListeners();
    _save();
  }

  Future<void> saveProfile({
    required String name,
    String phone = '',
    String upi = '',
  }) async {
    final index = _people.indexWhere((p) => p.isMe);
    if (index == -1) {
      _people.insert(
        0,
        Person(id: meId, name: name, phone: phone, upi: upi, isMe: true),
      );
    } else {
      final p = _people[index];
      p.name = name;
      p.phone = phone;
      p.upi = upi;
    }
    _ensureDefaultGroup();
    _changed();
  }

  Person addPerson({
    required String name,
    String phone = '',
    String upi = '',
    bool isFriend = false,
    String? photoPath,
  }) {
    final person = Person(
      id: newId(),
      name: name,
      phone: phone,
      upi: upi,
      isFriend: isFriend,
      photoPath: photoPath,
    );
    _people.add(person);
    _changed();
    return person;
  }

  void updatePerson(
    Person person, {
    required String name,
    required String phone,
    required String upi,
  }) {
    person.name = name;
    person.phone = phone;
    person.upi = upi;
    _changed();
  }

  void setFriend(Person person, bool value) {
    person.isFriend = value;
    _changed();
  }

  void setPersonPhoto(Person person, String? path) {
    person.photoPath = path;
    _changed();
  }

  void setGroupPhoto(ExpenseGroup group, String? path) {
    group.photoPath = path;
    _changed();
  }

  void addRecurring(RecurringExpense rule) {
    _recurring.add(rule);
    _changed();
  }

  void deleteRecurring(RecurringExpense rule) {
    _recurring.removeWhere((r) => r.id == rule.id);
    _changed();
  }

  List<PairBalance> balancesWith(String personId) {
    final result = <PairBalance>[];
    for (final group in _groups) {
      if (!group.memberIds.contains(personId)) continue;
      var net = 0.0;
      for (final s in settlementsFor(group)) {
        if (s.debtor == personId && s.creditor == meId) net += s.amount;
        if (s.debtor == meId && s.creditor == personId) net -= s.amount;
      }
      if (net.abs() > 0.005) result.add(PairBalance(group, net));
    }
    return result;
  }

  ExpenseGroup createGroup(
    String name,
    Iterable<String> memberIds, {
    String? photoPath,
  }) {
    final group = ExpenseGroup(
      id: newId(),
      name: name,
      memberIds: {meId, ...memberIds}.toList(),
      photoPath: photoPath,
    );
    _groups.add(group);
    _changed();
    return group;
  }

  void renameGroup(ExpenseGroup group, String name) {
    group.name = name;
    _changed();
  }

  void deleteGroup(ExpenseGroup group) {
    if (group.isDefault) return;
    _groups.remove(group);
    _expenses.removeWhere((e) => e.groupId == group.id);
    _changed();
  }

  bool canRemoveFromGroup(ExpenseGroup group, String personId) =>
      personId != meId &&
      expensesFor(group.id).every(
        (e) => e.paidBy != personId && !e.splitShares.containsKey(personId),
      );

  List<String> setGroupMembers(ExpenseGroup group, Set<String> selected) {
    final blocked = <String>[];
    final keep = {meId, ...selected};
    for (final id in List<String>.from(group.memberIds)) {
      if (keep.contains(id)) continue;
      if (canRemoveFromGroup(group, id)) {
        group.memberIds.remove(id);
      } else {
        blocked.add(nameOf(id));
      }
    }
    for (final id in keep) {
      if (!group.memberIds.contains(id)) group.memberIds.add(id);
    }
    _changed();
    return blocked;
  }

  List<GroupExpense> expensesFor(String groupId) =>
      _expenses.where((e) => e.groupId == groupId).toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

  Map<String, double> balancesFor(ExpenseGroup group) =>
      computeBalances(group.memberIds, expensesFor(group.id));

  List<Settlement> settlementsFor(ExpenseGroup group) =>
      computeSettlements(balancesFor(group));

  void saveExpense(GroupExpense expense) {
    final index = _expenses.indexWhere((e) => e.id == expense.id);
    if (index == -1) {
      _expenses.add(expense);
    } else {
      _expenses[index] = expense;
    }
    _changed();
  }

  void deleteExpense(GroupExpense expense) {
    _expenses.removeWhere((e) => e.id == expense.id);
    _changed();
  }

  void applyImport({
    required List<Person> newPeople,
    required ExpenseGroup group,
    required List<GroupExpense> expenses,
    required Map<String, String> newAliases,
  }) {
    for (final person in newPeople) {
      if (personById(person.id) == null) _people.add(person);
    }
    _aliases.addAll(newAliases);

    final index = _groups.indexWhere((g) => g.id == group.id);
    if (index == -1) {
      _groups.add(group);
    } else {
      final local = _groups[index];
      if (!local.isDefault) local.name = group.name;
      local.photoPath = group.photoPath ?? local.photoPath;
      for (final id in group.memberIds) {
        if (!local.memberIds.contains(id)) local.memberIds.add(id);
      }
    }
    for (final expense in expenses) {
      final i = _expenses.indexWhere((e) => e.id == expense.id);
      if (i == -1) {
        _expenses.add(expense);
      } else {
        _expenses[i] = expense;
      }
    }
    _ensureDefaultGroup();
    _changed();
  }

  void replaceAll({
    required List<Person> people,
    required List<ExpenseGroup> groups,
    required List<GroupExpense> expenses,
    required List<RecurringExpense> recurring,
    required Map<String, String> aliases,
    required String profileId,
  }) {
    _people = people;
    _groups = groups;
    _expenses = expenses;
    _recurring = recurring;
    _aliases = aliases;
    _profileId = profileId;
    _ensureDefaultGroup();
    _changed();
  }

  void clearAll() {
    _people = [];
    _groups = [];
    _expenses = [];
    _recurring = [];
    _aliases = {};
    _ensureDefaultGroup();
    _changed();
  }

  GroupExpense recordSettlement({
    required ExpenseGroup group,
    required String debtor,
    required String creditor,
    required double amount,
  }) {
    final settlement = GroupExpense(
      id: newId(),
      groupId: group.id,
      title: 'Settlement',
      amount: amount,
      paidBy: debtor,
      splitShares: {creditor: amount},
      createdAt: DateTime.now(),
      isSettlement: true,
    );
    _expenses.add(settlement);
    _changed();
    return settlement;
  }
}

final appStore = AppStore();
