import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cointally/data/local/db_helper.dart';
import 'package:cointally/domain/entities/debt_entity.dart';
import 'package:cointally/domain/entities/transaction_entity.dart';
import 'package:cointally/presentation/notifiers/account_notifier.dart';
import 'package:cointally/presentation/notifiers/transaction_notifier.dart';

class DebtState {
  final List<DebtEntity> debts;
  final bool isLoading;

  DebtState({this.debts = const [], this.isLoading = false});

  DebtState copyWith({List<DebtEntity>? debts, bool? isLoading}) {
    return DebtState(
      debts: debts ?? this.debts,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

class DebtNotifier extends StateNotifier<DebtState> {
  final Ref _ref;
  DebtNotifier(this._ref) : super(DebtState()) {
    loadDebts();
  }

  Future<void> loadDebts() async {
    state = state.copyWith(isLoading: true);
    final db = await DatabaseHelper.instance.database;
    final List<Map<String, dynamic>> maps = await db.query('debts', orderBy: 'date DESC');
    final debts = maps.map((m) => DebtEntity.fromMap(m)).toList();
    state = state.copyWith(debts: debts, isLoading: false);
  }

  Future<void> addDebt(DebtEntity debt) async {
    final db = await DatabaseHelper.instance.database;
    final id = await db.insert('debts', debt.toMap());
    
    // Create corresponding transaction if an account is selected
    if (debt.accountId != null) {
      final transactionNotifier = _ref.read(transactionProvider.notifier);
      final transaction = TransactionEntity(
        amount: debt.amount,
        type: debt.type == 'LEND' ? 'EXPENSE' : 'INCOME',
        category: 'Debt: ${debt.type}',
        date: debt.date,
        accountId: debt.accountId,
        merchantName: debt.type == 'LEND' ? 'Lent Money' : 'Borrowed Money',
        debtId: id, // Link back to this debt
      );
      await transactionNotifier.addTransaction(transaction);
      // Refresh accounts
      _ref.read(accountProvider.notifier).loadAccounts();
    }

    await loadDebts();
  }

  Future<void> settleDebt(int debtId, {int? accountId}) async {
    final db = await DatabaseHelper.instance.database;
    final debt = state.debts.firstWhere((d) => d.id == debtId);
    
    await db.update(
      'debts',
      {'is_settled': 1},
      where: 'id = ?',
      whereArgs: [debtId],
    );

    // If settling via an account, create the opposite transaction
    // If we LENT (Expense originally), Settle is INCOME.
    // If we BORROWED (Income originally), Settle is EXPENSE.
    if (accountId != null) {
      final transactionNotifier = _ref.read(transactionProvider.notifier);
      final settleTransaction = TransactionEntity(
        amount: debt.amount,
        type: debt.type == 'LEND' ? 'INCOME' : 'EXPENSE',
        category: 'Debt Settlement',
        date: DateTime.now(),
        accountId: accountId,
        merchantName: debt.type == 'LEND' ? 'Debt Recovered' : 'Debt Repaid',
      );
      await transactionNotifier.addTransaction(settleTransaction);
      _ref.read(accountProvider.notifier).loadAccounts();
    }

    await loadDebts();
  }

  double getPersonBalance(int personId) {
    double balance = 0;
    for (var debt in state.debts.where((d) => d.personId == personId && !d.isSettled)) {
      if (debt.type == 'LEND') {
        balance += debt.amount; // They owe us
      } else {
        balance -= debt.amount; // We owe them
      }
    }
    return balance;
  }
}

final debtProvider = StateNotifierProvider<DebtNotifier, DebtState>((ref) {
  return DebtNotifier(ref);
});
