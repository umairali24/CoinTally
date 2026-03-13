import 'package:cointally/data/local/db_helper.dart';
import 'package:cointally/domain/entities/budget_entity.dart';
import 'package:cointally/domain/repository/budget_repository.dart';

class BudgetRepositoryImpl implements BudgetRepository {
  final DatabaseHelper _dbHelper;

  BudgetRepositoryImpl(this._dbHelper);

  @override
  Future<List<BudgetEntity>> getBudgets() async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query('budgets');
    return List.generate(maps.length, (i) {
      return BudgetEntity.fromMap(maps[i]);
    });
  }

  @override
  Future<int> addBudget(BudgetEntity budget) async {
    final db = await _dbHelper.database;
    return await db.insert('budgets', budget.toMap());
  }

  @override
  Future<void> updateBudget(BudgetEntity budget) async {
    final db = await _dbHelper.database;
    await db.update(
      'budgets',
      budget.toMap(),
      where: 'id = ?',
      whereArgs: [budget.id],
    );
  }

  @override
  Future<void> deleteBudget(int id) async {
    final db = await _dbHelper.database;
    await db.delete(
      'budgets',
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}
