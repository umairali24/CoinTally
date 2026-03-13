import 'package:cointally/domain/entities/budget_entity.dart';

abstract class BudgetRepository {
  Future<List<BudgetEntity>> getBudgets();
  Future<int> addBudget(BudgetEntity budget);
  Future<void> updateBudget(BudgetEntity budget);
  Future<void> deleteBudget(int id);
}
