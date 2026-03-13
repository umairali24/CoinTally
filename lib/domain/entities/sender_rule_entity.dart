class SenderRuleEntity {
  final String senderId; // SMS Short Code (e.g., '8080')
  final String bankName; // Display name of the bank
  final bool isBlocked; // If true, ignore SMS from this sender

  const SenderRuleEntity({
    required this.senderId,
    required this.bankName,
    this.isBlocked = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'sender_id': senderId,
      'bank_name': bankName,
      'is_blocked': isBlocked ? 1 : 0,
    };
  }

  factory SenderRuleEntity.fromMap(Map<String, dynamic> map) {
    return SenderRuleEntity(
      senderId: map['sender_id'] as String,
      bankName: map['bank_name'] as String,
      isBlocked: (map['is_blocked'] as int) == 1,
    );
  }
}
