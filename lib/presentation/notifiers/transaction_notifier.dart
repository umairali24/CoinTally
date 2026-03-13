import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cointally/presentation/notifiers/streak_notifier.dart';
import 'package:cointally/domain/entities/transaction_entity.dart';
import 'package:cointally/domain/repository/transaction_repository.dart';
import 'package:cointally/data/repository/transaction_repository_impl.dart';
import 'package:cointally/data/local/db_helper.dart';
import 'package:cointally/presentation/notifiers/currency_notifier.dart';
import 'package:cointally/presentation/notifiers/account_notifier.dart';
import 'package:cointally/presentation/notifiers/debt_notifier.dart';

// State Class
class TransactionState {
  final bool isLoading;
  final List<TransactionEntity> transactions;
  final double totalBalance;
  final double dailyAverage;
  final double growthPercentage;
  final String searchQuery;
  final String selectedFilter;
  final DateTime? customStartDate;
  final DateTime? customEndDate;
  final String? errorMessage;

  const TransactionState({
    this.isLoading = false,
    this.transactions = const [],
    this.totalBalance = 0.0,
    this.dailyAverage = 0.0,
    this.growthPercentage = 0.0,
    this.searchQuery = '',
    this.selectedFilter = 'All Time',
    this.customStartDate,
    this.customEndDate,
    this.errorMessage,
  });

  TransactionState copyWith({
    bool? isLoading,
    List<TransactionEntity>? transactions,
    double? totalBalance,
    double? dailyAverage,
    double? growthPercentage,
    String? searchQuery,
    String? selectedFilter,
    DateTime? customStartDate,
    DateTime? customEndDate,
    String? errorMessage,
  }) {
    return TransactionState(
      isLoading: isLoading ?? this.isLoading,
      transactions: transactions ?? this.transactions,
      totalBalance: totalBalance ?? this.totalBalance,
      dailyAverage: dailyAverage ?? this.dailyAverage,
      growthPercentage: growthPercentage ?? this.growthPercentage,
      searchQuery: searchQuery ?? this.searchQuery,
      selectedFilter: selectedFilter ?? this.selectedFilter,
      customStartDate: customStartDate ?? this.customStartDate,
      customEndDate: customEndDate ?? this.customEndDate,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}

// Notifier Class
class TransactionNotifier extends StateNotifier<TransactionState> {
  final TransactionRepository _repository;
  final Ref ref;

  TransactionNotifier(this._repository, this.ref) : super(const TransactionState());

  Future<void> loadData() async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final transactions = await _repository.getTransactions();
      final balance = await _repository.getBalance();
      final dailyAvg = await _repository.getDailyAverageSpending();
      final growth = await _repository.getNetWorthGrowthPercentage();

      state = state.copyWith(
        isLoading: false,
        transactions: transactions,
        totalBalance: balance,
        dailyAverage: dailyAvg,
        growthPercentage: growth,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Failed to load data: $e',
      );
    }
  }

  Future<void> addTransaction(TransactionEntity transaction) async {
    // Optimistic update could be done here, but safe approach is reload
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      await _repository.addTransaction(transaction);
      // Increment streak on successful transaction
      ref.read(streakNotifierProvider.notifier).incrementStreakSafely();
      await loadData(); // Refresh list and balance
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Failed to add transaction: $e',
      );
    }
  }

  Future<void> updateTransaction(TransactionEntity transaction) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      await _repository.updateTransaction(transaction);
      await loadData();
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Failed to update transaction: $e',
      );
    }
  }

  Future<void> deleteTransaction(int id) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      await _repository.deleteTransaction(id);
      await loadData();
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Failed to delete transaction: $e',
      );
    }
  }

  void setSearchQuery(String query) {
    state = state.copyWith(searchQuery: query);
  }

  void setFilter(String filter) {
    state = state.copyWith(selectedFilter: filter, customStartDate: null, customEndDate: null);
  }

  void setCustomDateRange(DateTime start, DateTime end) {
    state = state.copyWith(
      selectedFilter: 'Custom',
      customStartDate: start,
      customEndDate: end,
    );
  }

  List<TransactionEntity> get filteredTransactions {
    final now = DateTime.now();
    List<TransactionEntity> filtered = state.transactions;

    // Apply Filter
    if (state.selectedFilter == 'Today') {
      filtered = filtered.where((tx) => tx.date.year == now.year && tx.date.month == now.month && tx.date.day == now.day).toList();
    } else if (state.selectedFilter == 'Yesterday') {
      final yesterday = now.subtract(const Duration(days: 1));
      filtered = filtered.where((tx) => tx.date.year == yesterday.year && tx.date.month == yesterday.month && tx.date.day == yesterday.day).toList();
    } else if (state.selectedFilter == 'This Month') {
      filtered = filtered.where((tx) => tx.date.month == now.month && tx.date.year == now.year).toList();
    } else if (state.selectedFilter == 'This Week') {
      final weekStart = now.subtract(Duration(days: now.weekday - 1));
      final startOfDay = DateTime(weekStart.year, weekStart.month, weekStart.day);
      filtered = filtered.where((tx) => tx.date.isAfter(startOfDay.subtract(const Duration(seconds: 1)))).toList();
    } else if (state.selectedFilter == 'Custom' && state.customStartDate != null && state.customEndDate != null) {
      final start = DateTime(state.customStartDate!.year, state.customStartDate!.month, state.customStartDate!.day);
      final end = DateTime(state.customEndDate!.year, state.customEndDate!.month, state.customEndDate!.day, 23, 59, 59);
      filtered = filtered.where((tx) => tx.date.isAfter(start.subtract(const Duration(seconds: 1))) && tx.date.isBefore(end.add(const Duration(seconds: 1)))).toList();
    }

    // Apply Search
    if (state.searchQuery.isNotEmpty) {
      final query = state.searchQuery.toLowerCase();
      filtered = filtered.where((tx) {
        final merchant = (tx.merchantName ?? '').toLowerCase();
        final category = tx.category.toLowerCase();
        return merchant.contains(query) || category.contains(query);
      }).toList();
    }

    return filtered;
  }

  Future<List<TransactionEntity>> getTransactionsByAccount(int accountId) async {
    return await _repository.getTransactionsByAccount(accountId);
  }

  Future<double> getAccountBalance(int accountId) async {
    return await _repository.getAccountBalance(accountId);
  }
}

// Providers

// 1. Repository Provider
// Dependency Injection for the Repository
final transactionRepositoryProvider = Provider<TransactionRepository>((ref) {
  return TransactionRepositoryImpl(DatabaseHelper.instance);
});

// 2. Notifier Provider
// The global provider for the Transaction Notifier
final transactionProvider = StateNotifierProvider<TransactionNotifier, TransactionState>((ref) {
  final repository = ref.watch(transactionRepositoryProvider);
  final notifier = TransactionNotifier(repository, ref);
  
  // Listen to debt changes to refresh total balance (Net Worth)
  ref.listen(debtProvider, (previous, next) {
    if (!next.isLoading) {
      notifier.loadData();
    }
  });

  // Listen to currency changes to refresh total balance
  ref.listen(currencyNotifierProvider, (previous, next) {
    if (previous?.primaryCurrency != next.primaryCurrency) {
      notifier.loadData();
    }
  });

  // Listen to account changes (add/delete) to refresh total balance
  ref.listen<AccountState>(accountProvider, (previous, next) {
    if (previous?.accounts.length != next.accounts.length) {
      notifier.loadData();
    }
  });

  return notifier;
});

final currentMonthTotalExpenseProvider = Provider<double>((ref) {
  final transactions = ref.watch(transactionProvider).transactions;
  final now = DateTime.now();
  
  return transactions
      .where((t) => t.type == 'EXPENSE' && t.date.month == now.month && t.date.year == now.year)
      .fold(0.0, (sum, t) => sum + t.amount);
});
