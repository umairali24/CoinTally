import 'package:cointally/data/local/db_helper.dart';
import 'package:cointally/domain/entities/goal_entity.dart';
import 'package:cointally/domain/repository/goal_repository.dart';

class GoalRepositoryImpl implements GoalRepository {
  final DatabaseHelper _dbHelper;

  GoalRepositoryImpl(this._dbHelper);

  @override
  Future<List<GoalEntity>> getGoals() async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query('goals');
    return maps.map((map) => GoalEntity.fromMap(map)).toList();
  }

  @override
  Future<int> addGoal(GoalEntity goal) async {
    final db = await _dbHelper.database;
    return await db.insert('goals', goal.toMap());
  }

  @override
  Future<void> updateGoal(GoalEntity goal) async {
    final db = await _dbHelper.database;
    await db.update(
      'goals',
      goal.toMap(),
      where: 'id = ?',
      whereArgs: [goal.id],
    );
  }

  @override
  Future<void> deleteGoal(int id) async {
    final db = await _dbHelper.database;
    await db.delete('goals', where: 'id = ?', whereArgs: [id]);
  }
}
