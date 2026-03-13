import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cointally/domain/entities/goal_entity.dart';
import 'package:cointally/domain/repository/goal_repository.dart';
import 'package:cointally/data/repository/goal_repository_impl.dart';
import 'package:cointally/data/local/db_helper.dart';
import 'package:cointally/presentation/notifiers/account_notifier.dart';
import 'package:cointally/presentation/notifiers/transaction_notifier.dart';
import 'package:cointally/domain/entities/transaction_entity.dart';

class GoalState {
  final bool isLoading;
  final List<GoalEntity> goals;
  final String? errorMessage;

  const GoalState({
    this.isLoading = false,
    this.goals = const [],
    this.errorMessage,
  });

  GoalState copyWith({
    bool? isLoading,
    List<GoalEntity>? goals,
    String? errorMessage,
  }) {
    return GoalState(
      isLoading: isLoading ?? this.isLoading,
      goals: goals ?? this.goals,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}

class GoalNotifier extends StateNotifier<GoalState> {
  final GoalRepository _repository;
  final Ref _ref;

  GoalNotifier(this._repository, this._ref) : super(const GoalState()) {
    loadGoals();
  }

  Future<void> loadGoals() async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final goals = await _repository.getGoals();
      state = state.copyWith(isLoading: false, goals: goals);
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: 'Failed to load goals: $e');
    }
  }

  Future<void> addGoal(GoalEntity goal) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      await _repository.addGoal(goal);
      await loadGoals();
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: 'Failed to add goal: $e');
    }
  }

  Future<void> updateGoal(GoalEntity goal) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      await _repository.updateGoal(goal);
      await loadGoals();
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: 'Failed to update goal: $e');
    }
  }

  Future<void> deleteGoal(int id) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      await _repository.deleteGoal(id);
      await loadGoals();
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: 'Failed to delete goal: $e');
    }
  }

  Future<void> contributeToGoal({
    required int goalId,
    required double amount,
    int? sourceAccountId,
    String? category,
  }) async {
    final goal = state.goals.firstWhere((g) => g.id == goalId);
    
    // 1. Update goal amount
    final updatedGoal = goal.copyWith(currentAmount: goal.currentAmount + amount);
    await updateGoal(updatedGoal);

    // 2. Perform accounting
    final transactionNotifier = _ref.read(transactionProvider.notifier);

    if (sourceAccountId != null) {
      // Contribution from an existing Account
      if (goal.targetAccountId != null && goal.targetAccountId != sourceAccountId) {
        // Goal has a target account: Treat as TRANSFER
        final transfer = TransactionEntity(
          amount: amount,
          type: 'TRANSFER',
          category: 'Goal: ${goal.title}',
          date: DateTime.now(),
          accountId: sourceAccountId,
          toAccountId: goal.targetAccountId,
          merchantName: 'Goal Contribution',
        );
        await transactionNotifier.addTransaction(transfer);
      } else {
        // No target account or same as source: Treat as virtual EXPENSE from the account
        final expense = TransactionEntity(
          amount: amount,
          type: 'EXPENSE',
          category: 'Goal: ${goal.title}',
          date: DateTime.now(),
          accountId: sourceAccountId,
          merchantName: 'Goal Saving',
        );
        await transactionNotifier.addTransaction(expense);
      }
    } else {
      // Contribution from new INCOME
      final income = TransactionEntity(
        amount: amount,
        type: 'INCOME',
        category: category ?? 'Goal: ${goal.title}',
        date: DateTime.now(),
        toAccountId: goal.targetAccountId, // Deposit income directly into target account if specified
        merchantName: 'Goal Contribution (Income)',
      );
      await transactionNotifier.addTransaction(income);
    }
    
    // Refresh accounts as well
    _ref.read(accountProvider.notifier).loadAccounts();
  }
}

final goalRepositoryProvider = Provider<GoalRepository>((ref) {
  return GoalRepositoryImpl(DatabaseHelper.instance);
});

final goalProvider = StateNotifierProvider<GoalNotifier, GoalState>((ref) {
  final repository = ref.watch(goalRepositoryProvider);
  return GoalNotifier(repository, ref);
});
