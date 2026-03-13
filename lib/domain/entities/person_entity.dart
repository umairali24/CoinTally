class PersonEntity {
  final int? id;
  final String name;
  final String? phoneNumber;
  final DateTime createdAt;

  PersonEntity({
    this.id,
    required this.name,
    this.phoneNumber,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'phone_number': phoneNumber,
      'created_at': createdAt.millisecondsSinceEpoch,
    };
  }

  factory PersonEntity.fromMap(Map<String, dynamic> map) {
    return PersonEntity(
      id: map['id'] as int?,
      name: map['name'] as String,
      phoneNumber: map['phone_number'] as String?,
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int),
    );
  }

  PersonEntity copyWith({
    int? id,
    String? name,
    String? phoneNumber,
    DateTime? createdAt,
  }) {
    return PersonEntity(
      id: id ?? this.id,
      name: name ?? this.name,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
