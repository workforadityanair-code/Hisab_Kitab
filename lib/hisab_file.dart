import 'dart:convert';
import 'dart:io';

import 'media.dart';
import 'models.dart';
import 'store.dart';

const _format = 'hisab';
const _version = 1;

class HisabFormatException implements Exception {
  HisabFormatException(this.message);

  final String message;

  @override
  String toString() => message;
}

class HisabPackage {
  HisabPackage({
    required this.kind,
    required this.exportedAt,
    required this.senderName,
    required this.senderId,
    required this.people,
    required this.groups,
    required this.expenses,
    required this.recurring,
    required this.aliases,
  });

  final String kind;
  final DateTime exportedAt;
  final String senderName;
  final String senderId;
  final List<Map<String, dynamic>> people;
  final List<Map<String, dynamic>> groups;
  final List<Map<String, dynamic>> expenses;
  final List<Map<String, dynamic>> recurring;
  final Map<String, String> aliases;

  bool get isBackup => kind == 'backup';

  Map<String, dynamic> get group => groups.first;
  String get groupName => group['name'] as String;
  String get groupId => group['id'] as String;
}

class ImportSummary {
  const ImportSummary({
    required this.groupId,
    required this.added,
    required this.updated,
  });

  final String groupId;
  final int added;
  final int updated;
}

String _out(String id) => id == meId ? appStore.profileId : id;

Map<String, double> _outShares(Map<String, double> shares) => {
  for (final e in shares.entries) _out(e.key): e.value,
};

Map<String, dynamic> _personOut(Person p) => {
  'id': _out(p.id),
  'name': p.name,
  'phone': p.phone,
  'upi': p.upi,
  'isFriend': p.isFriend,
  'isMe': p.isMe,
  'photo': readBase64Image(p.photoPath),
};

Map<String, dynamic> _groupOut(ExpenseGroup g, {required String id}) => {
  'id': id,
  'name': g.name,
  'memberIds': g.memberIds.map(_out).toList(),
  'isDefault': id == g.id && g.isDefault,
  'photo': readBase64Image(g.photoPath),
};

Map<String, dynamic> _expenseOut(GroupExpense e, {required String groupId}) => {
  'id': e.id,
  'groupId': groupId,
  'title': e.title,
  'amount': e.amount,
  'paidBy': _out(e.paidBy),
  'splitShares': _outShares(e.splitShares),
  'createdAt': e.createdAt.toIso8601String(),
  'isSettlement': e.isSettlement,
  'subtotal': e.subtotal,
  'taxPercent': e.taxPercent,
  'items': [
    for (final i in e.items)
      {
        'name': i.name,
        'amount': i.amount,
        'sharedBy': i.sharedBy.map(_out).toList(),
      },
  ],
  'category': e.category,
  'receipt': readBase64Image(e.receiptPath),
};

Map<String, dynamic> _recurringOut(RecurringExpense r) => {
  'id': r.id,
  'groupId': r.groupId,
  'title': r.title,
  'amount': r.amount,
  'subtotal': r.subtotal,
  'taxPercent': r.taxPercent,
  'paidBy': _out(r.paidBy),
  'splitShares': _outShares(r.splitShares),
  'category': r.category,
  'frequency': r.frequency.name,
  'nextDue': r.nextDue.toIso8601String(),
};

String _encode({
  required String kind,
  required List<Map<String, dynamic>> people,
  required List<Map<String, dynamic>> groups,
  required List<Map<String, dynamic>> expenses,
  List<Map<String, dynamic>> recurring = const [],
  Map<String, String> aliases = const {},
}) {
  return jsonEncode({
    'format': _format,
    'version': _version,
    'kind': kind,
    'exportedAt': DateTime.now().toIso8601String(),
    'sender': {'id': appStore.profileId, 'name': appStore.meName},
    'people': people,
    'groups': groups,
    'expenses': expenses,
    'recurring': recurring,
    'aliases': {for (final e in aliases.entries) e.key: _out(e.value)},
  });
}

String buildGroupFile(ExpenseGroup group) {
  final groupId = group.isDefault
      ? '${appStore.profileId}-${group.id}'
      : group.id;
  final people = <Person>[
    for (final id in group.memberIds) ?appStore.personById(id),
  ];
  final expenses = appStore.expensesFor(group.id);

  return _encode(
    kind: 'group',
    people: people.map(_personOut).toList(),
    groups: [_groupOut(group, id: groupId)],
    expenses: [for (final e in expenses) _expenseOut(e, groupId: groupId)],
  );
}

String buildBackupFile() {
  return _encode(
    kind: 'backup',
    people: appStore.people.map(_personOut).toList(),
    groups: [for (final g in appStore.groups) _groupOut(g, id: g.id)],
    expenses: [
      for (final e in appStore.allExpenses) _expenseOut(e, groupId: e.groupId),
    ],
    recurring: appStore.recurring.map(_recurringOut).toList(),
    aliases: appStore.aliases,
  );
}

Future<File> writeHisabFile(String name, String content) async {
  final safe = name.replaceAll(RegExp(r'[^A-Za-z0-9 _-]'), '').trim();
  final file = File(
    '${Directory.systemTemp.path}/${safe.isEmpty ? 'HisabKitab' : safe}.hisab',
  );
  await file.writeAsString(content);
  return file;
}

List<Map<String, dynamic>> _list(dynamic value) =>
    ((value ?? const []) as List).cast<Map<String, dynamic>>();

HisabPackage parseHisabFile(String text) {
  final dynamic raw;
  try {
    raw = jsonDecode(text);
  } catch (_) {
    throw HisabFormatException('This is not a HisabKitab file.');
  }
  if (raw is! Map<String, dynamic> || raw['format'] != _format) {
    throw HisabFormatException('This is not a HisabKitab file.');
  }
  if (((raw['version'] ?? 0) as num) > _version) {
    throw HisabFormatException(
      'This file was made by a newer version of HisabKitab. Update the app.',
    );
  }

  final kind = raw['kind'] as String? ?? '';
  if (kind != 'group' && kind != 'backup') {
    throw HisabFormatException('This file type is not supported.');
  }

  final sender = (raw['sender'] ?? const {}) as Map<String, dynamic>;
  final package = HisabPackage(
    kind: kind,
    exportedAt:
        DateTime.tryParse(raw['exportedAt'] as String? ?? '') ??
        DateTime.fromMillisecondsSinceEpoch(0),
    senderName: (sender['name'] ?? 'Someone') as String,
    senderId: (sender['id'] ?? '') as String,
    people: _list(raw['people']),
    groups: _list(raw['groups']),
    expenses: _list(raw['expenses']),
    recurring: _list(raw['recurring']),
    aliases: Map<String, String>.from((raw['aliases'] ?? const {}) as Map),
  );

  if (kind == 'group' && package.groups.isEmpty) {
    throw HisabFormatException('This file has no group in it.');
  }
  return package;
}

Map<String, String> candidateNames(HisabPackage package) {
  final inGroup = <String>{
    ...List<String>.from(package.group['memberIds'] as List),
  };
  return {
    for (final p in package.people)
      if (inGroup.contains(p['id'])) p['id'] as String: p['name'] as String,
  };
}

String? detectMe(HisabPackage package) {
  final ids = candidateNames(package).keys;
  for (final id in ids) {
    if (id == appStore.profileId || appStore.aliases[id] == meId) return id;
  }
  return null;
}

int countExisting(HisabPackage package) {
  final existing = {for (final e in appStore.allExpenses) e.id};
  return package.expenses.where((e) => existing.contains(e['id'])).length;
}

Future<ImportSummary> importGroup(
  HisabPackage package, {
  String? chosenMeId,
}) async {
  String mapId(String id) {
    if (id == appStore.profileId) return meId;
    if (id == chosenMeId) return meId;
    return appStore.aliases[id] ?? id;
  }

  final newPeople = <Person>[];
  for (final p in package.people) {
    final id = mapId(p['id'] as String);
    if (id == meId || appStore.personById(id) != null) continue;
    final photo = p['photo'] as String?;
    newPeople.add(
      Person(
        id: id,
        name: p['name'] as String,
        phone: (p['phone'] ?? '') as String,
        upi: (p['upi'] ?? '') as String,
        photoPath: photo == null
            ? null
            : await saveBase64Image(photo, 'people'),
      ),
    );
  }

  final raw = package.group;
  final memberIds = <String>{
    for (final id in List<String>.from(raw['memberIds'] as List)) mapId(id),
    meId,
  }.toList();
  final groupPhoto = raw['photo'] as String?;
  final group = ExpenseGroup(
    id: raw['id'] as String,
    name: raw['name'] as String,
    memberIds: memberIds,
    photoPath: groupPhoto == null
        ? null
        : await saveBase64Image(groupPhoto, 'groups'),
  );

  final existing = {for (final e in appStore.allExpenses) e.id};
  var added = 0;
  var updated = 0;
  final expenses = <GroupExpense>[];
  for (final e in package.expenses) {
    final receipt = e['receipt'] as String?;
    final id = e['id'] as String;
    if (existing.contains(id)) {
      updated++;
    } else {
      added++;
    }
    expenses.add(
      GroupExpense(
        id: id,
        groupId: group.id,
        title: e['title'] as String,
        amount: (e['amount'] as num).toDouble(),
        paidBy: mapId(e['paidBy'] as String),
        splitShares: {
          for (final s in (e['splitShares'] as Map<String, dynamic>).entries)
            mapId(s.key): (s.value as num).toDouble(),
        },
        createdAt: DateTime.parse(e['createdAt'] as String),
        isSettlement: (e['isSettlement'] ?? false) as bool,
        subtotal: (e['subtotal'] as num?)?.toDouble(),
        taxPercent: ((e['taxPercent'] ?? 0) as num).toDouble(),
        items: [
          for (final i in _list(e['items']))
            ExpenseItem(
              name: i['name'] as String,
              amount: (i['amount'] as num).toDouble(),
              sharedBy: [
                for (final s in List<String>.from(i['sharedBy'] as List))
                  mapId(s),
              ],
            ),
        ],
        category: (e['category'] ?? '') as String,
        receiptPath: receipt == null
            ? null
            : await saveBase64Image(receipt, 'receipts'),
      ),
    );
  }

  appStore.applyImport(
    newPeople: newPeople,
    group: group,
    expenses: expenses,
    newAliases: chosenMeId == null ? const {} : {chosenMeId: meId},
  );

  return ImportSummary(groupId: group.id, added: added, updated: updated);
}

Future<void> restoreBackup(HisabPackage package) async {
  String mapId(String id) => id == package.senderId ? meId : id;

  final people = <Person>[];
  for (final p in package.people) {
    final photo = p['photo'] as String?;
    final isMe = (p['isMe'] ?? false) as bool;
    people.add(
      Person(
        id: mapId(p['id'] as String),
        name: p['name'] as String,
        phone: (p['phone'] ?? '') as String,
        upi: (p['upi'] ?? '') as String,
        isFriend: (p['isFriend'] ?? false) as bool,
        isMe: isMe,
        photoPath: photo == null
            ? null
            : await saveBase64Image(photo, 'people'),
      ),
    );
  }

  final groups = <ExpenseGroup>[];
  for (final g in package.groups) {
    final photo = g['photo'] as String?;
    groups.add(
      ExpenseGroup(
        id: g['id'] as String,
        name: g['name'] as String,
        memberIds: [
          for (final id in List<String>.from(g['memberIds'] as List)) mapId(id),
        ],
        isDefault: (g['isDefault'] ?? false) as bool,
        photoPath: photo == null
            ? null
            : await saveBase64Image(photo, 'groups'),
      ),
    );
  }

  final expenses = <GroupExpense>[];
  for (final e in package.expenses) {
    final receipt = e['receipt'] as String?;
    expenses.add(
      GroupExpense(
        id: e['id'] as String,
        groupId: e['groupId'] as String,
        title: e['title'] as String,
        amount: (e['amount'] as num).toDouble(),
        paidBy: mapId(e['paidBy'] as String),
        splitShares: {
          for (final s in (e['splitShares'] as Map<String, dynamic>).entries)
            mapId(s.key): (s.value as num).toDouble(),
        },
        createdAt: DateTime.parse(e['createdAt'] as String),
        isSettlement: (e['isSettlement'] ?? false) as bool,
        subtotal: (e['subtotal'] as num?)?.toDouble(),
        taxPercent: ((e['taxPercent'] ?? 0) as num).toDouble(),
        items: [
          for (final i in _list(e['items']))
            ExpenseItem(
              name: i['name'] as String,
              amount: (i['amount'] as num).toDouble(),
              sharedBy: [
                for (final s in List<String>.from(i['sharedBy'] as List))
                  mapId(s),
              ],
            ),
        ],
        category: (e['category'] ?? '') as String,
        receiptPath: receipt == null
            ? null
            : await saveBase64Image(receipt, 'receipts'),
      ),
    );
  }

  final recurring = <RecurringExpense>[
    for (final r in package.recurring)
      RecurringExpense(
        id: r['id'] as String,
        groupId: r['groupId'] as String,
        title: r['title'] as String,
        amount: (r['amount'] as num).toDouble(),
        subtotal: (r['subtotal'] as num).toDouble(),
        taxPercent: ((r['taxPercent'] ?? 0) as num).toDouble(),
        paidBy: mapId(r['paidBy'] as String),
        splitShares: {
          for (final s in (r['splitShares'] as Map<String, dynamic>).entries)
            mapId(s.key): (s.value as num).toDouble(),
        },
        category: (r['category'] ?? '') as String,
        frequency: Frequency.values.firstWhere(
          (f) => f.name == r['frequency'],
          orElse: () => Frequency.monthly,
        ),
        nextDue: DateTime.parse(r['nextDue'] as String),
      ),
  ];

  appStore.replaceAll(
    people: people,
    groups: groups,
    expenses: expenses,
    recurring: recurring,
    aliases: {for (final e in package.aliases.entries) e.key: mapId(e.value)},
    profileId: package.senderId.isEmpty ? appStore.profileId : package.senderId,
  );
}
