import 'package:cointally/data/local/db_helper.dart';
import 'package:cointally/domain/entities/account_entity.dart';
import 'package:cointally/domain/repository/account_repository.dart';

class AccountRepositoryImpl implements AccountRepository {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  @override
  Future<int> addAccount(AccountEntity account) async {
    final db = await _dbHelper.database;
    return await db.insert('accounts', account.toMap());
  }

  @override
  Future<List<AccountEntity>> getAllAccounts() async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query('accounts');
    return maps.map((map) => AccountEntity.fromMap(map)).toList();
  }

  @override
  Future<void> updateAccount(AccountEntity account) async {
    final db = await _dbHelper.database;
    await db.update(
      'accounts',
      account.toMap(),
      where: 'id = ?',
      whereArgs: [account.id],
    );
  }

  @override
  Future<void> deleteAccount(int id) async {
    final db = await _dbHelper.database;
    await db.transaction((txn) async {
      // 1. Check if the account being deleted is the default
      final List<Map<String, dynamic>> accounts = await txn.query(
        'accounts',
        where: 'id = ?',
        whereArgs: [id],
      );
      
      bool wasDefault = false;
      if (accounts.isNotEmpty && accounts.first['is_default'] == 1) {
        wasDefault = true;
      }

      // 2. Delete the account
      await txn.delete(
        'accounts',
        where: 'id = ?',
        whereArgs: [id],
      );

      // 3. Cascade Delete: Transactions
      // This includes Expenses, Income and Transfers involving this account
      await txn.delete(
        'transactions',
        where: 'account_id = ? OR to_account_id = ?',
        whereArgs: [id, id],
      );

      // 4. Cascade Delete: Debts
      await txn.delete(
        'debts',
        where: 'account_id = ?',
        whereArgs: [id],
      );

      // 5. Cascade Delete: Learned Rules associated with this account
      await txn.delete(
        'learned_rules',
        where: 'target_account_id = ?',
        whereArgs: [id],
      );

      // 6. Nullify: Goals (Keep the goal but remove the target account link)
      await txn.update(
        'goals',
        {'target_account_id': null},
        where: 'target_account_id = ?',
        whereArgs: [id],
      );

      // 7. Nullify: Pending Transactions
      await txn.update(
        'pending_transactions',
        {'suggested_account_id': null},
        where: 'suggested_account_id = ?',
        whereArgs: [id],
      );

      // 8. Reassign Default if necessary
      if (wasDefault) {
        final List<Map<String, dynamic>> remainingAccounts = await txn.query('accounts', limit: 1);
        if (remainingAccounts.isNotEmpty) {
          final nextId = remainingAccounts.first['id'];
          await txn.execute('UPDATE accounts SET is_default = 1 WHERE id = ?', [nextId]);
        }
      }
    });
  }

  @override
  Future<void> setDefaultAccount(int id) async {
    final db = await _dbHelper.database;
    await db.transaction((txn) async {
      // Clear all defaults
      await txn.execute('UPDATE accounts SET is_default = 0');
      // Set new default
      await txn.execute('UPDATE accounts SET is_default = 1 WHERE id = ?', [id]);
    });
  }
}
