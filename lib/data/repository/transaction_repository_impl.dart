import 'package:cointally/data/local/db_helper.dart';import 'package:cointally/domain/entities/transaction_entity.dart';
import 'package:cointally/domain/repository/transaction_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

class TransactionRepositoryImpl implements TransactionRepository {
  final DatabaseHelper dbHelper;

  TransactionRepositoryImpl(this.dbHelper);

  @override
  Future<void> addTransaction(TransactionEntity transaction) async {
    final db = await dbHelper.database;
    final int id = await db.insert('transactions', transaction.toMap());
    
    // Automatically attempt to merge into a Transfer if it matches a recent pair
    if (transaction.type == 'INCOME' || transaction.type == 'EXPENSE') {
      final mapToMerge = transaction.toMap();
      mapToMerge['id'] = id; // Ensure ID is present for the query exclusion
      await dbHelper.checkAndMergeTransfer(id, mapToMerge);
    }
  }

  @override
  Future<List<TransactionEntity>> getTransactions() async {
    final db = await dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'transactions',
      orderBy: 'date DESC',
    );
    return List.generate(maps.length, (i) {
      return TransactionEntity.fromMap(maps[i]);
    });
  }

  @override
  Future<void> deleteTransaction(int id) async {
    final db = await dbHelper.database;
    await db.delete(
      'transactions',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  @override
  Future<void> updateTransaction(TransactionEntity transaction) async {
    final db = await dbHelper.database;
    await db.update(
      'transactions',
      transaction.toMap(),
      where: 'id = ?',
      whereArgs: [transaction.id],
    );
  }

  @override
  Future<double> getBalance() async {
    final db = await dbHelper.database;
    
    // 1. Get Primary Currency
    final prefs = await SharedPreferences.getInstance();
    final primaryCurrency = prefs.getString('primary_currency') ?? 'PKR';

    // 2. Fetch Exchange Rates for Primary Currency
    final ratesResult = await db.query(
      'exchange_rates',
      where: 'to_currency = ?',
      whereArgs: [primaryCurrency],
    );
    
    final rates = <String, double>{};
    for (var row in ratesResult) {
      rates[row['from_currency'] as String] = (row['rate'] as num).toDouble();
    }
    // Rate for primary currency itself is always 1.0
    rates[primaryCurrency] = 1.0;

    double _convert(double amount, String from) {
      final rate = rates[from.toUpperCase()];
      return amount * (rate ?? 1.0);
    }

    // 3. Calculate Account Balances Consolidated
    final accounts = await db.query('accounts');
    double totalInitial = 0.0;
    
    for (var account in accounts) {
      final balance = (account['balance'] as num).toDouble();
      final type = account['account_type'] as String;
      final currency = account['currency_code'] as String? ?? 'PKR';
      
      final convertedBalance = _convert(balance, currency);
      
      if (type == 'BANK') {
        totalInitial += convertedBalance;
      } else if (type == 'CREDIT_CARD') {
        totalInitial -= convertedBalance;
      }
    }

    // 4. Calculate Net from Transactions
    // Transactions need to be linked to their account's currency
    // For simplicity and per requirement, we'll assume transaction amount is in the account's currency
    final txResult = await db.rawQuery('''
      SELECT t.amount, t.type, a.currency_code
      FROM transactions t
      JOIN accounts a ON t.account_id = a.id
      WHERE t.type IN ('INCOME', 'EXPENSE', 'ADJUSTMENT')
    ''');
    
    double transactionNet = 0.0;
    for (var tx in txResult) {
      final amount = (tx['amount'] as num).toDouble();
      final type = tx['type'] as String;
      final currency = tx['currency_code'] as String? ?? 'PKR';
      
      final convertedAmount = _convert(amount, currency);
      
      if (type == 'INCOME' || type == 'ADJUSTMENT') {
        transactionNet += convertedAmount;
      } else if (type == 'EXPENSE') {
        transactionNet -= convertedAmount;
      }
    }

    // 5. Calculate Net from Debts
    // Assuming debts are in primary currency unless linked to an account
    final debtResult = await db.rawQuery('''
      SELECT d.amount, d.type, a.currency_code
      FROM debts d
      LEFT JOIN accounts a ON d.account_id = a.id
      WHERE d.is_settled = 0
    ''');

    double debtNet = 0.0;
    for (var debt in debtResult) {
      final amount = (debt['amount'] as num).toDouble();
      final type = debt['type'] as String;
      final currency = debt['currency_code'] as String? ?? primaryCurrency; // Default to primary if no account
      
      final convertedAmount = _convert(amount, currency);
      
      if (type == 'LEND') {
        debtNet += convertedAmount;
      } else if (type == 'BORROW') {
        debtNet -= convertedAmount;
      }
    }
    
    return totalInitial + transactionNet + debtNet;
  }

  @override
  Future<List<TransactionEntity>> getTransactionsByAccount(int accountId) async {
    final db = await dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'transactions',
      where: 'account_id = ? OR to_account_id = ?',
      whereArgs: [accountId, accountId],
      orderBy: 'date DESC',
    );
    return List.generate(maps.length, (i) {
      return TransactionEntity.fromMap(maps[i]);
    });
  }

  @override
  Future<double> getAccountBalance(int accountId) async {
    final db = await dbHelper.database;

    // 1. Get initial balance
    final accountResult = await db.query(
      'accounts',
      columns: ['balance', 'account_type'],
      where: 'id = ?',
      whereArgs: [accountId],
    );

    if (accountResult.isEmpty) return 0.0;

    final initialBalance = (accountResult.first['balance'] as num).toDouble();
    final isCreditCard = accountResult.first['account_type'] == 'CREDIT_CARD';

    // 2. Get transaction net
    final txResult = await db.rawQuery('''
      SELECT SUM(
        CASE 
          WHEN account_id = ? AND type = 'INCOME' THEN amount
          WHEN account_id = ? AND type = 'EXPENSE' THEN -amount
          WHEN account_id = ? AND type = 'TRANSFER' THEN -amount
          WHEN to_account_id = ? AND type = 'TRANSFER' THEN amount
          WHEN account_id = ? AND type = 'ADJUSTMENT' THEN amount
          ELSE 0
        END
      ) as net_tx
      FROM transactions
      WHERE account_id = ? OR to_account_id = ?
    ''', [accountId, accountId, accountId, accountId, accountId, accountId, accountId]);

    double netTx = 0.0;
    if (txResult.isNotEmpty && txResult.first['net_tx'] != null) {
      netTx = (txResult.first['net_tx'] as num).toDouble();
    }

    if (isCreditCard) {
      return initialBalance - netTx; 
    }

    return initialBalance + netTx;
  }

  @override
  Future<double> getDailyAverageSpending() async {
    final db = await dbHelper.database;
    final now = DateTime.now();
    final startOfMonth = DateTime(now.year, now.month, 1).millisecondsSinceEpoch;
    
    // Get Primary Currency
    final prefs = await SharedPreferences.getInstance();
    final primaryCurrency = prefs.getString('primary_currency') ?? 'PKR';

    // Fetch Exchange Rates
    final ratesResult = await db.query(
      'exchange_rates',
      where: 'to_currency = ?',
      whereArgs: [primaryCurrency],
    );
    final rates = <String, double>{'${primaryCurrency.toUpperCase()}': 1.0};
    for (var row in ratesResult) {
      rates[(row['from_currency'] as String).toUpperCase()] = (row['rate'] as num).toDouble();
    }

    final txResult = await db.rawQuery('''
      SELECT t.amount, a.currency_code
      FROM transactions t
      JOIN accounts a ON t.account_id = a.id
      WHERE t.type = 'EXPENSE' AND t.date >= ?
    ''', [startOfMonth]);

    double totalExpense = 0.0;
    for (var tx in txResult) {
      final amount = (tx['amount'] as num).toDouble();
      final currency = tx['currency_code'] as String? ?? 'PKR';
      final rate = rates[currency.toUpperCase()] ?? 1.0;
      totalExpense += amount * rate;
    }

    final daysPassed = now.day;
    return totalExpense / daysPassed;
  }

  @override
  Future<double> getNetWorthGrowthPercentage() async {
    final db = await dbHelper.database;
    final now = DateTime.now();
    final startOfThisMonth = DateTime(now.year, now.month, 1).millisecondsSinceEpoch;

    // 1. Current Net Worth (already uses conversion)
    final currentWorth = await getBalance();

    // 2. Last Month's Net Worth
    // Need to fetch primary currency and rates again
    final prefs = await SharedPreferences.getInstance();
    final primaryCurrency = prefs.getString('primary_currency') ?? 'PKR';

    final ratesResult = await db.query(
      'exchange_rates',
      where: 'to_currency = ?',
      whereArgs: [primaryCurrency],
    );
    final rates = <String, double>{'${primaryCurrency.toUpperCase()}': 1.0};
    for (var row in ratesResult) {
      rates[(row['from_currency'] as String).toUpperCase()] = (row['rate'] as num).toDouble();
    }

    double _convert(double amount, String from) => amount * (rates[from.toUpperCase()] ?? 1.0);

    // Initial balances
    final accounts = await db.query('accounts');
    double initialBalanceConverted = 0.0;
    for (var account in accounts) {
      final balance = (account['balance'] as num).toDouble();
      final type = account['account_type'] as String;
      final currency = account['currency_code'] as String? ?? 'PKR';
      final converted = _convert(balance, currency);
      if (type == 'BANK') initialBalanceConverted += converted;
      else if (type == 'CREDIT_CARD') initialBalanceConverted -= converted;
    }

    // Transactions until end of last month
    final txResult = await db.rawQuery('''
      SELECT t.amount, t.type, a.currency_code
      FROM transactions t
      JOIN accounts a ON t.account_id = a.id
      WHERE t.date < ?
    ''', [startOfThisMonth]);

    double txUntilLastMonth = 0.0;
    for (var tx in txResult) {
      final amount = (tx['amount'] as num).toDouble();
      final type = tx['type'] as String;
      final currency = tx['currency_code'] as String? ?? 'PKR';
      final converted = _convert(amount, currency);
      if (type == 'INCOME' || type == 'ADJUSTMENT') txUntilLastMonth += converted;
      else if (type == 'EXPENSE') txUntilLastMonth -= converted;
    }

    // Debts until end of last month
    final debtResult = await db.rawQuery('''
      SELECT d.amount, d.type, a.currency_code
      FROM debts d
      LEFT JOIN accounts a ON d.account_id = a.id
      WHERE d.is_settled = 0 AND d.date < ?
    ''', [startOfThisMonth]);

    double debtUntilLastMonth = 0.0;
    for (var debt in debtResult) {
      final amount = (debt['amount'] as num).toDouble();
      final type = debt['type'] as String;
      final currency = debt['currency_code'] as String? ?? primaryCurrency;
      final converted = _convert(amount, currency);
      if (type == 'LEND') debtUntilLastMonth += converted;
      else if (type == 'BORROW') debtUntilLastMonth -= converted;
    }

    final lastMonthWorth = initialBalanceConverted + txUntilLastMonth + debtUntilLastMonth;

    if (lastMonthWorth == 0) return 0.0;

    return ((currentWorth - lastMonthWorth) / lastMonthWorth) * 100;
  }

  @override
  Future<String?> getBankName(String senderId) async {
    final db = await dbHelper.database;
    final List<Map<String, dynamic>> res = await db.query(
      'sender_rules',
      where: 'sender_id = ? AND is_blocked = 0',
      whereArgs: [senderId],
    );
    if (res.isNotEmpty) {
      return res.first['bank_name'] as String;
    }
    return null;
  }

  @override
  Future<double> getPaidZakatForCurrentYear() async {
    final db = await dbHelper.database;
    final now = DateTime.now();
    // 354 days is approximately one Islamic (Hijri) year
    final thresholdDate = now.subtract(const Duration(days: 354)).millisecondsSinceEpoch;

    final result = await db.rawQuery('''
      SELECT SUM(amount) as total
      FROM transactions
      WHERE type = 'EXPENSE' 
        AND category = 'Zakat' 
        AND date >= ?
    ''', [thresholdDate]);

    if (result.isNotEmpty && result.first['total'] != null) {
      return (result.first['total'] as num).toDouble();
    }
    
    return 0.0;
  }

  @override
  Future<List<TransactionEntity>> getTransactionsByCategoryAndDateRange(
    String categoryName,
    DateTime startDate,
    DateTime endDate,
  ) async {
    final db = await dbHelper.database;
    final startMs = startDate.millisecondsSinceEpoch;
    // Ensure end covers the full last day (23:59:59.999)
    final endMs = DateTime(
      endDate.year, endDate.month, endDate.day, 23, 59, 59, 999,
    ).millisecondsSinceEpoch;

    List<Map<String, dynamic>> maps;

    // The chart merges all "Debt:*" category names into one virtual 'Debt' bucket.
    // We reverse that here by matching any category that starts with 'Debt'.
    if (categoryName == 'Debt') {
      maps = await db.rawQuery(
        '''
        SELECT * FROM transactions
        WHERE category LIKE 'Debt%'
          AND date >= ? AND date <= ?
        ORDER BY date DESC
        ''',
        [startMs, endMs],
      );
    } else {
      maps = await db.rawQuery(
        '''
        SELECT * FROM transactions
        WHERE category = ?
          AND date >= ? AND date <= ?
        ORDER BY date DESC
        ''',
        [categoryName, startMs, endMs],
      );
    }

    return List.generate(maps.length, (i) => TransactionEntity.fromMap(maps[i]));
  }
}

