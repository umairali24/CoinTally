class AccountEntity {
  final int? id;
  final String bankName;
  final double balance;
  final String themeColor; // Hex Code
  final String? logoAssetPath;
  final String accountType; // 'BANK' or 'CREDIT_CARD'
  final double creditLimit;
  final bool isDefault;
  final String currencyCode;
  final int? billPaymentDate; // 1-31
  final bool enableReminder;

  const AccountEntity({
    this.id,
    required this.bankName,
    this.balance = 0.0,
    this.themeColor = '#FFFFFF',
    this.logoAssetPath,
    this.accountType = 'BANK',
    this.creditLimit = 0.0,
    this.isDefault = false,
    this.currencyCode = 'PKR',
    this.billPaymentDate,
    this.enableReminder = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'bank_name': bankName,
      'balance': balance,
      'theme_color': themeColor,
      'logo_asset_path': logoAssetPath,
      'account_type': accountType,
      'credit_limit': creditLimit,
      'is_default': isDefault ? 1 : 0,
      'currency_code': currencyCode,
      'bill_payment_date': billPaymentDate,
      'enable_reminder': enableReminder ? 1 : 0,
    };
  }

  factory AccountEntity.fromMap(Map<String, dynamic> map) {
    return AccountEntity(
      id: map['id'] as int?,
      bankName: map['bank_name'] as String,
      balance: (map['balance'] as num).toDouble(),
      themeColor: map['theme_color'] as String,
      logoAssetPath: map['logo_asset_path'] as String?,
      accountType: map['account_type'] as String? ?? 'BANK',
      creditLimit: (map['credit_limit'] as num?)?.toDouble() ?? 0.0,
      isDefault: (map['is_default'] as int? ?? 0) == 1,
      currencyCode: map['currency_code'] as String? ?? 'PKR',
      billPaymentDate: map['bill_payment_date'] as int?,
      enableReminder: (map['enable_reminder'] as int? ?? 0) == 1,
    );
  }
}
