import 'package:cointally/domain/entities/goal_entity.dart';

abstract class GoalRepository {
  Future<List<GoalEntity>> getGoals();
  Future<int> addGoal(GoalEntity goal);
  Future<void> updateGoal(GoalEntity goal);
  Future<void> deleteGoal(int id);
}
