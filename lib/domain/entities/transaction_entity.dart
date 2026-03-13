class TransactionEntity {
  final int? id;
  final double amount;
  final String type; // 'INCOME' or 'EXPENSE'
  final String category; // e.g., 'Food', 'Fuel', 'Salary'
  final DateTime date; // Stored as INTEGER (Unix Timestamp)
  final String? merchantName;
  final int? accountId;
  final int? toAccountId;
  final int? debtId;
  final bool isAutoDetected; // Stored as INTEGER (0 or 1)
  final bool isPromotional; // Stored as INTEGER (0 or 1)
  /// Transient marker: not stored to DB. True when this entity is a placeholder
  /// passed to reconcile() after saving a debt, to clear the pending queue entry.
  final bool isDebtReconcile;

  const TransactionEntity({
    this.id,
    required this.amount,
    required this.type,
    required this.category,
    required this.date,
    this.merchantName,
    this.accountId,
    this.toAccountId,
    this.debtId,
    this.isAutoDetected = false,
    this.isPromotional = false,
    this.isDebtReconcile = false,
  });

  // Convert a Transaction into a Map. The keys must correspond to the names of the
  // columns in the database.
  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'amount': amount,
      'type': type,
      'category': category,
      'date': date.millisecondsSinceEpoch,
      'merchant_name': merchantName,
      'account_id': accountId,
      'to_account_id': toAccountId,
      'debt_id': debtId,
      'is_auto_detected': isAutoDetected ? 1 : 0,
      'is_promotional': isPromotional ? 1 : 0,
      // Transient runtime marker — not persisted to DB, only used during reconcile flow
      if (isDebtReconcile) 'is_debt_reconcile': true,
    };
  }

  // Implement fromMap to convert database Map to Transaction object
  factory TransactionEntity.fromMap(Map<String, dynamic> map) {
    return TransactionEntity(
      id: map['id'] as int?,
      amount: (map['amount'] as num).toDouble(),
      type: map['type'] as String,
      category: map['category'] as String,
      date: DateTime.fromMillisecondsSinceEpoch(map['date'] as int),
      merchantName: map['merchant_name'] as String?,
      accountId: map['account_id'] as int?,
      toAccountId: map['to_account_id'] as int?,
      debtId: map['debt_id'] as int?,
      isAutoDetected: (map['is_auto_detected'] as int) == 1,
      isPromotional: (map['is_promotional'] ?? 0) == 1,
    );
  }

  TransactionEntity copyWith({
    int? id,
    double? amount,
    String? type,
    String? category,
    DateTime? date,
    String? merchantName,
    int? accountId,
    int? toAccountId,
    int? debtId,
    bool? isAutoDetected,
    bool? isPromotional,
    bool? isDebtReconcile,
  }) {
    return TransactionEntity(
      id: id ?? this.id,
      amount: amount ?? this.amount,
      type: type ?? this.type,
      category: category ?? this.category,
      date: date ?? this.date,
      merchantName: merchantName ?? this.merchantName,
      accountId: accountId ?? this.accountId,
      toAccountId: toAccountId ?? this.toAccountId,
      debtId: debtId ?? this.debtId,
      isAutoDetected: isAutoDetected ?? this.isAutoDetected,
      isPromotional: isPromotional ?? this.isPromotional,
      isDebtReconcile: isDebtReconcile ?? this.isDebtReconcile,
    );
  }
}
