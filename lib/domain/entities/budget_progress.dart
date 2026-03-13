import 'package:cointally/domain/entities/budget_entity.dart';

class BudgetProgress {
  final BudgetEntity budget;
  final double amountSpent;
  
  BudgetProgress({
    required this.budget,
    required this.amountSpent,
  });

  double get percentage => budget.monthlyLimit > 0 
      ? (amountSpent / budget.monthlyLimit).clamp(0.0, 1.0) 
      : 0.0;

  bool get isOverBudget => amountSpent > budget.monthlyLimit;
}
