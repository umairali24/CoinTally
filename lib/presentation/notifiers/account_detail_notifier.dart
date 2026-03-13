import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cointally/domain/entities/transaction_entity.dart';
import 'package:cointally/presentation/notifiers/transaction_notifier.dart';

class AccountDetailState {
  final List<TransactionEntity> transactions;
  final double balance;
  final bool isLoading;

  AccountDetailState({
    this.transactions = const [],
    this.balance = 0.0,
    this.isLoading = false,
  });

  AccountDetailState copyWith({
    List<TransactionEntity>? transactions,
    double? balance,
    bool? isLoading,
  }) {
    return AccountDetailState(
      transactions: transactions ?? this.transactions,
      balance: balance ?? this.balance,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

class AccountDetailNotifier extends StateNotifier<AccountDetailState> {
  final Ref ref;
  final int accountId;

  AccountDetailNotifier(this.ref, this.accountId) : super(AccountDetailState()) {
    // Initial load
    loadData();
    
    // Listen to changes in the global transaction state
    // When transactions are added/deleted, we refresh this account's specific data
    ref.listen(transactionProvider, (previous, next) {
      if (!next.isLoading && previous?.isLoading == true) {
        loadData();
      }
    });
  }

  Future<void> loadData() async {
    // If already loading manually, avoid duplicate
    if (state.isLoading) return;
    
    state = state.copyWith(isLoading: true);
    final txNotifier = ref.read(transactionProvider.notifier);
    
    final transactions = await txNotifier.getTransactionsByAccount(accountId);
    final balance = await txNotifier.getAccountBalance(accountId);
    
    state = state.copyWith(
      transactions: transactions,
      balance: balance,
      isLoading: false,
    );
  }
}

final accountDetailProvider = StateNotifierProvider.family<AccountDetailNotifier, AccountDetailState, int>((ref, accountId) {
  return AccountDetailNotifier(ref, accountId);
});
