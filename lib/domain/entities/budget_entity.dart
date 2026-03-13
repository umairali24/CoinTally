class BudgetEntity {
  final int? id;
  final String category;
  final double monthlyLimit;
  final String period;
  final bool isOverall;

  BudgetEntity({
    this.id,
    required this.category,
    required this.monthlyLimit,
    this.period = 'MONTHLY',
    this.isOverall = false,
  });

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'category': category,
      'monthly_limit': monthlyLimit,
      'period': period,
      'is_overall': isOverall ? 1 : 0,
    };
  }

  factory BudgetEntity.fromMap(Map<String, dynamic> map) {
    return BudgetEntity(
      id: map['id'] as int?,
      category: map['category'] as String,
      monthlyLimit: (map['monthly_limit'] as num).toDouble(),
      period: map['period'] as String? ?? 'MONTHLY',
      isOverall: (map['is_overall'] as int? ?? 0) == 1,
    );
  }

  BudgetEntity copyWith({
    int? id,
    String? category,
    double? monthlyLimit,
    String? period,
    bool? isOverall,
  }) {
    return BudgetEntity(
      id: id ?? this.id,
      category: category ?? this.category,
      monthlyLimit: monthlyLimit ?? this.monthlyLimit,
      period: period ?? this.period,
      isOverall: isOverall ?? this.isOverall,
    );
  }
}
