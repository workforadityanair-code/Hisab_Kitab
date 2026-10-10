import 'dart:math';

class Person {
  Person({
    required this.id,
    required this.name,
    this.phone = '',
    this.upi = '',
    this.isFriend = false,
    this.isMe = false,
    this.photoPath,
  });

  final String id;
  String name;
  String phone;
  String upi;
  bool isFriend;
  final bool isMe;
  String? photoPath;

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'phone': phone,
    'upi': upi,
    'isFriend': isFriend,
    'isMe': isMe,
    'photoPath': photoPath,
  };

  factory Person.fromJson(Map<String, dynamic> json) => Person(
    id: json['id'] as String,
    name: json['name'] as String,
    phone: (json['phone'] ?? '') as String,
    upi: (json['upi'] ?? '') as String,
    isFriend: (json['isFriend'] ?? false) as bool,
    isMe: (json['isMe'] ?? false) as bool,
    photoPath: json['photoPath'] as String?,
  );
}

class ExpenseGroup {
  ExpenseGroup({
    required this.id,
    required this.name,
    required this.memberIds,
    this.isDefault = false,
    this.photoPath,
  });

  final String id;
  String name;
  final List<String> memberIds;
  final bool isDefault;
  String? photoPath;

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'memberIds': memberIds,
    'isDefault': isDefault,
    'photoPath': photoPath,
  };

  factory ExpenseGroup.fromJson(Map<String, dynamic> json) => ExpenseGroup(
    id: json['id'] as String,
    name: json['name'] as String,
    memberIds: List<String>.from(json['memberIds'] as List),
    isDefault: (json['isDefault'] ?? false) as bool,
    photoPath: json['photoPath'] as String?,
  );
}

class ExpenseItem {
  ExpenseItem({
    required this.name,
    required this.amount,
    required this.sharedBy,
  });

  final String name;
  final double amount;
  final List<String> sharedBy;

  Map<String, dynamic> toJson() => {
    'name': name,
    'amount': amount,
    'sharedBy': sharedBy,
  };

  factory ExpenseItem.fromJson(Map<String, dynamic> json) => ExpenseItem(
    name: json['name'] as String,
    amount: (json['amount'] as num).toDouble(),
    sharedBy: List<String>.from(json['sharedBy'] as List),
  );
}

class GroupExpense {
  GroupExpense({
    required this.id,
    required this.groupId,
    required this.title,
    required this.amount,
    required this.paidBy,
    required this.splitShares,
    required this.createdAt,
    this.isSettlement = false,
    double? subtotal,
    this.taxPercent = 0,
    this.items = const [],
    this.category = '',
    this.receiptPath,
  }) : subtotal = subtotal ?? amount;

  final String id;
  final String groupId;
  final String title;
  final double amount;
  final String paidBy;
  final Map<String, double> splitShares;
  final DateTime createdAt;
  final bool isSettlement;
  final double subtotal;
  final double taxPercent;
  final List<ExpenseItem> items;
  final String category;
  final String? receiptPath;

  double get taxAmount => amount - subtotal;

  Map<String, dynamic> toJson() => {
    'id': id,
    'groupId': groupId,
    'title': title,
    'amount': amount,
    'paidBy': paidBy,
    'splitShares': splitShares,
    'createdAt': createdAt.toIso8601String(),
    'isSettlement': isSettlement,
    'subtotal': subtotal,
    'taxPercent': taxPercent,
    'items': items.map((i) => i.toJson()).toList(),
    'category': category,
    'receiptPath': receiptPath,
  };

  factory GroupExpense.fromJson(Map<String, dynamic> json) => GroupExpense(
    id: json['id'] as String,
    groupId: json['groupId'] as String,
    title: json['title'] as String,
    amount: (json['amount'] as num).toDouble(),
    paidBy: json['paidBy'] as String,
    splitShares: (json['splitShares'] as Map<String, dynamic>).map(
      (k, v) => MapEntry(k, (v as num).toDouble()),
    ),
    createdAt: DateTime.parse(json['createdAt'] as String),
    isSettlement: (json['isSettlement'] ?? false) as bool,
    subtotal: (json['subtotal'] as num?)?.toDouble(),
    taxPercent: ((json['taxPercent'] ?? 0) as num).toDouble(),
    items: ((json['items'] ?? const []) as List)
        .map((i) => ExpenseItem.fromJson(i as Map<String, dynamic>))
        .toList(),
    category: (json['category'] ?? '') as String,
    receiptPath: json['receiptPath'] as String?,
  );
}

enum Frequency { weekly, monthly }

class RecurringExpense {
  RecurringExpense({
    required this.id,
    required this.groupId,
    required this.title,
    required this.amount,
    required this.subtotal,
    required this.taxPercent,
    required this.paidBy,
    required this.splitShares,
    required this.category,
    required this.frequency,
    required this.nextDue,
  });

  final String id;
  final String groupId;
  final String title;
  final double amount;
  final double subtotal;
  final double taxPercent;
  final String paidBy;
  final Map<String, double> splitShares;
  final String category;
  final Frequency frequency;
  DateTime nextDue;

  DateTime advance(DateTime from) {
    if (frequency == Frequency.weekly) return from.add(const Duration(days: 7));
    final first = DateTime(from.year, from.month + 1, 1);
    final lastDay = DateTime(first.year, first.month + 1, 0).day;
    return DateTime(
      first.year,
      first.month,
      min(from.day, lastDay),
      from.hour,
      from.minute,
    );
  }

  GroupExpense occurrence(String id, DateTime when) => GroupExpense(
    id: id,
    groupId: groupId,
    title: title,
    amount: amount,
    paidBy: paidBy,
    splitShares: splitShares,
    createdAt: when,
    subtotal: subtotal,
    taxPercent: taxPercent,
    category: category,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'groupId': groupId,
    'title': title,
    'amount': amount,
    'subtotal': subtotal,
    'taxPercent': taxPercent,
    'paidBy': paidBy,
    'splitShares': splitShares,
    'category': category,
    'frequency': frequency.name,
    'nextDue': nextDue.toIso8601String(),
  };

  factory RecurringExpense.fromJson(Map<String, dynamic> json) =>
      RecurringExpense(
        id: json['id'] as String,
        groupId: json['groupId'] as String,
        title: json['title'] as String,
        amount: (json['amount'] as num).toDouble(),
        subtotal: (json['subtotal'] as num).toDouble(),
        taxPercent: ((json['taxPercent'] ?? 0) as num).toDouble(),
        paidBy: json['paidBy'] as String,
        splitShares: (json['splitShares'] as Map<String, dynamic>).map(
          (k, v) => MapEntry(k, (v as num).toDouble()),
        ),
        category: (json['category'] ?? '') as String,
        frequency: Frequency.values.firstWhere(
          (f) => f.name == json['frequency'],
          orElse: () => Frequency.monthly,
        ),
        nextDue: DateTime.parse(json['nextDue'] as String),
      );
}
