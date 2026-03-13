class GoalEntity {
  final int? id;
  final String title;
  final double targetAmount;
  final double currentAmount;
  final bool isLocked; // Stored as INTEGER (0 or 1)
  final String type; // 'SAVING' or 'DEBT'
  final String? category;
  final DateTime createdAt;
  final String? imagePath;
  final int? targetAccountId;

  GoalEntity({
    this.id,
    required this.title,
    required this.targetAmount,
    this.currentAmount = 0.0,
    this.isLocked = true,
    this.type = 'SAVING',
    this.category,
    this.imagePath,
    this.targetAccountId,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'title': title,
      'target_amount': targetAmount,
      'current_amount': currentAmount,
      'is_locked': isLocked ? 1 : 0,
      'type': type,
      'category': category,
      'image_path': imagePath,
      'target_account_id': targetAccountId,
      'created_at': createdAt.millisecondsSinceEpoch,
    };
  }

  factory GoalEntity.fromMap(Map<String, dynamic> map) {
    return GoalEntity(
      id: map['id'] as int?,
      title: map['title'] as String,
      targetAmount: map['target_amount'] as double,
      currentAmount: (map['current_amount'] as num).toDouble(),
      isLocked: (map['is_locked'] as int) == 1,
      type: map['type'] as String? ?? 'SAVING',
      category: map['category'] as String?,
      imagePath: map['image_path'] as String?,
      targetAccountId: map['target_account_id'] as int?,
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int? ?? DateTime.now().millisecondsSinceEpoch),
    );
  }

  GoalEntity copyWith({
    int? id,
    String? title,
    double? targetAmount,
    double? currentAmount,
    bool? isLocked,
    String? type,
    String? category,
    String? imagePath,
    int? targetAccountId,
    DateTime? createdAt,
  }) {
    return GoalEntity(
      id: id ?? this.id,
      title: title ?? this.title,
      targetAmount: targetAmount ?? this.targetAmount,
      currentAmount: currentAmount ?? this.currentAmount,
      isLocked: isLocked ?? this.isLocked,
      type: type ?? this.type,
      category: category ?? this.category,
      imagePath: imagePath ?? this.imagePath,
      targetAccountId: targetAccountId ?? this.targetAccountId,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
