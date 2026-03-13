import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cointally/domain/entities/budget_entity.dart';
import 'package:cointally/domain/entities/budget_progress.dart';
import 'package:cointally/presentation/notifiers/transaction_notifier.dart';
import 'package:cointally/domain/repository/budget_repository.dart';
import 'package:cointally/data/repository/budget_repository_impl.dart';
import 'package:cointally/data/local/db_helper.dart';

// State Class
class BudgetState {
  final bool isLoading;
  final List<BudgetEntity> budgets;
  final String? errorMessage;

  const BudgetState({
    this.isLoading = false,
    this.budgets = const [],
    this.errorMessage,
  });

  BudgetState copyWith({
    bool? isLoading,
    List<BudgetEntity>? budgets,
    String? errorMessage,
  }) {
    return BudgetState(
      isLoading: isLoading ?? this.isLoading,
      budgets: budgets ?? this.budgets,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}

// Notifier Class
class BudgetNotifier extends StateNotifier<BudgetState> {
  final BudgetRepository _repository;

  BudgetNotifier(this._repository) : super(const BudgetState());

  Future<void> loadBudgets() async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final budgets = await _repository.getBudgets();
      state = state.copyWith(isLoading: false, budgets: budgets);
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: 'Failed to load budgets: $e');
    }
  }

  Future<void> addBudget(BudgetEntity budget) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      await _repository.addBudget(budget);
      await loadBudgets();
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: 'Failed to add budget: $e');
    }
  }

  Future<void> updateBudget(BudgetEntity budget) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      await _repository.updateBudget(budget);
      await loadBudgets();
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: 'Failed to update budget: $e');
    }
  }

  Future<void> deleteBudget(int id) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      await _repository.deleteBudget(id);
      await loadBudgets();
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: 'Failed to delete budget: $e');
    }
  }
}

// Providers
final budgetRepositoryProvider = Provider<BudgetRepository>((ref) {
  return BudgetRepositoryImpl(DatabaseHelper.instance);
});

final budgetProvider = StateNotifierProvider<BudgetNotifier, BudgetState>((ref) {
  final repository = ref.watch(budgetRepositoryProvider);
  return BudgetNotifier(repository)..loadBudgets();
});

final budgetProgressProvider = Provider<List<BudgetProgress>>((ref) {
  final budgets = ref.watch(budgetProvider).budgets;
  final transactions = ref.watch(transactionProvider).transactions;

  final now = DateTime.now();
  final currentMonthTransactions = transactions.where((t) =>
      t.type == 'EXPENSE' &&
      t.date.month == now.month &&
      t.date.year == now.year).toList();

  return budgets.map((budget) {
    final spent = budget.isOverall 
        ? currentMonthTransactions.fold(0.0, (sum, t) => sum + t.amount)
        : currentMonthTransactions
            .where((t) => t.category.toLowerCase() == budget.category.toLowerCase())
            .fold(0.0, (sum, t) => sum + t.amount);
    
    return BudgetProgress(budget: budget, amountSpent: spent);
  }).toList();
});

final totalRemainingBudgetProvider = Provider<double>((ref) {
  final progress = ref.watch(budgetProgressProvider);
  
  if (progress.isEmpty) return 0.0;

  // Prefer "Overall" budgets if they exist
  final overallBudgets = progress.where((p) => p.budget.isOverall).toList();
  
  if (overallBudgets.isNotEmpty) {
    // Sum limits of overall budgets (usually just one)
    final totalLimit = overallBudgets.fold(0.0, (sum, p) => sum + p.budget.monthlyLimit);
    // Since overall projects track total expenses, we take the max spent or any spent
    // if there are multiple, they all track same thing.
    final totalSpent = overallBudgets.isNotEmpty ? overallBudgets.first.amountSpent : 0.0;
    return totalLimit - totalSpent;
  }

  // If no overall budget, sum category limits and their spendings
  double totalLimit = 0.0;
  double totalSpent = 0.0;
  for (var p in progress) {
    totalLimit += p.budget.monthlyLimit;
    totalSpent += p.amountSpent;
  }
  
  return (totalLimit - totalSpent).clamp(0.0, double.infinity);
});

final totalBudgetProvider = Provider<double>((ref) {
  final progress = ref.watch(budgetProgressProvider);
  if (progress.isEmpty) return 0.0;
  
  final overallBudgets = progress.where((p) => p.budget.isOverall).toList();
  if (overallBudgets.isNotEmpty) {
    return overallBudgets.fold(0.0, (sum, p) => sum + p.budget.monthlyLimit);
  }
  
  return progress.fold(0.0, (sum, p) => sum + p.budget.monthlyLimit);
});
