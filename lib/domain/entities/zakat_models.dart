import 'package:uuid/uuid.dart';

enum ZakatStabilityType {
  gold,
  silver,
  cash,
  other,
}

class ZakatAsset {
  final String id;
  final ZakatStabilityType type;
  final String name;
  final double amount; // Tolas for Gold/Silver, Currency for Cash/Other
  final bool isPersonalJewelryExempt;
  final int? linkedAccountId;

  ZakatAsset({
    String? id,
    required this.type,
    required this.name,
    required this.amount,
    this.isPersonalJewelryExempt = false,
    this.linkedAccountId,
  }) : id = id ?? const Uuid().v4();

  ZakatAsset copyWith({
    ZakatStabilityType? type,
    String? name,
    double? amount,
    bool? isPersonalJewelryExempt,
    int? linkedAccountId,
  }) {
    return ZakatAsset(
      id: id,
      type: type ?? this.type,
      name: name ?? this.name,
      amount: amount ?? this.amount,
      isPersonalJewelryExempt: isPersonalJewelryExempt ?? this.isPersonalJewelryExempt,
      linkedAccountId: linkedAccountId ?? this.linkedAccountId,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type.name,
      'name': name,
      'amount': amount,
      'isPersonalJewelryExempt': isPersonalJewelryExempt,
      'linkedAccountId': linkedAccountId,
    };
  }

  factory ZakatAsset.fromJson(Map<String, dynamic> json) {
    return ZakatAsset(
      id: json['id'] as String?,
      type: ZakatStabilityType.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () => ZakatStabilityType.cash,
      ),
      name: json['name'] as String,
      amount: (json['amount'] as num).toDouble(),
      isPersonalJewelryExempt: json['isPersonalJewelryExempt'] as bool? ?? false,
      linkedAccountId: json['linkedAccountId'] as int?,
    );
  }
}

enum ZakatLiabilityType {
  borrowedCash,
  pendingBills,
  businessDebt,
  installmentDue,
}

class ZakatLiability {
  final String id;
  final ZakatLiabilityType type;
  final double amount;
  final String? name; // For identifying auto-added or custom liabilities
  final int? linkedAccountId;
  final int? linkedDebtId;

  ZakatLiability({
    String? id,
    required this.type,
    required this.amount,
    this.name,
    this.linkedAccountId,
    this.linkedDebtId,
  }) : id = id ?? const Uuid().v4();

  ZakatLiability copyWith({
    ZakatLiabilityType? type,
    double? amount,
    String? name,
    int? linkedAccountId,
    int? linkedDebtId,
  }) {
    return ZakatLiability(
      id: id,
      type: type ?? this.type,
      amount: amount ?? this.amount,
      name: name ?? this.name,
      linkedAccountId: linkedAccountId ?? this.linkedAccountId,
      linkedDebtId: linkedDebtId ?? this.linkedDebtId,
    );
  }

  String get typeName {
    switch (type) {
      case ZakatLiabilityType.borrowedCash:
        return 'Borrowed Cash';
      case ZakatLiabilityType.pendingBills:
        return 'Pending Bills';
      case ZakatLiabilityType.businessDebt:
        return 'Business Debt';
      case ZakatLiabilityType.installmentDue:
        return 'Installment Due';
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type.name,
      'amount': amount,
      'name': name,
      'linkedAccountId': linkedAccountId,
      'linkedDebtId': linkedDebtId,
    };
  }

  factory ZakatLiability.fromJson(Map<String, dynamic> json) {
    return ZakatLiability(
      id: json['id'] as String?,
      type: ZakatLiabilityType.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () => ZakatLiabilityType.borrowedCash,
      ),
      amount: (json['amount'] as num).toDouble(),
      name: json['name'] as String?,
      linkedAccountId: json['linkedAccountId'] as int?,
      linkedDebtId: json['linkedDebtId'] as int?,
    );
  }
}

enum NisabStandard {
  gold,
  silver,
}

enum FiqhSchool {
  hanafi,
  shafii,
  maliki,
  hanbali,
}

