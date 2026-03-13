class DebtEntity {
  final int? id;
  final int personId;
  final double amount;
  final String type; // 'LEND' or 'BORROW'
  final String? description;
  final DateTime date;
  final DateTime? dueDate;
  final bool remindMe;
  final bool isSettled;
  final int? accountId;

  DebtEntity({
    this.id,
    required this.personId,
    required this.amount,
    required this.type,
    this.description,
    required this.date,
    this.dueDate,
    this.remindMe = false,
    this.isSettled = false,
    this.accountId,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'person_id': personId,
      'amount': amount,
      'type': type,
      'description': description,
      'date': date.millisecondsSinceEpoch,
      'due_date': dueDate?.millisecondsSinceEpoch,
      'remind_me': remindMe ? 1 : 0,
      'is_settled': isSettled ? 1 : 0,
      'account_id': accountId,
    };
  }

  factory DebtEntity.fromMap(Map<String, dynamic> map) {
    return DebtEntity(
      id: map['id'] as int?,
      personId: map['person_id'] as int,
      amount: (map['amount'] as num).toDouble(),
      type: map['type'] as String,
      description: map['description'] as String?,
      date: DateTime.fromMillisecondsSinceEpoch(map['date'] as int),
      dueDate: map['due_date'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['due_date'] as int)
          : null,
      remindMe: (map['remind_me'] as int) == 1,
      isSettled: (map['is_settled'] as int) == 1,
      accountId: map['account_id'] as int?,
    );
  }

  DebtEntity copyWith({
    int? id,
    int? personId,
    double? amount,
    String? type,
    String? description,
    DateTime? date,
    DateTime? dueDate,
    bool? remindMe,
    bool? isSettled,
    int? accountId,
  }) {
    return DebtEntity(
      id: id ?? this.id,
      personId: personId ?? this.personId,
      amount: amount ?? this.amount,
      type: type ?? this.type,
      description: description ?? this.description,
      date: date ?? this.date,
      dueDate: dueDate ?? this.dueDate,
      remindMe: remindMe ?? this.remindMe,
      isSettled: isSettled ?? this.isSettled,
      accountId: accountId ?? this.accountId,
    );
  }
}
