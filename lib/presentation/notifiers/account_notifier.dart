import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cointally/domain/entities/account_entity.dart';
import 'package:cointally/domain/repository/account_repository.dart';
import 'package:cointally/data/repository/account_repository_impl.dart';
import 'package:cointally/core/services/notification_service.dart';

class AccountState {
  final List<AccountEntity> accounts;
  final bool isLoading;
  final String? errorMessage;

  AccountState({
    required this.accounts,
    this.isLoading = false,
    this.errorMessage,
  });

  AccountState copyWith({
    List<AccountEntity>? accounts,
    bool? isLoading,
    String? errorMessage,
  }) {
    return AccountState(
      accounts: accounts ?? this.accounts,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}

class AccountNotifier extends StateNotifier<AccountState> {
  final AccountRepository _repository;

  AccountNotifier(this._repository) : super(AccountState(accounts: [])) {
    loadAccounts();
  }

  Future<void> loadAccounts() async {
    state = state.copyWith(isLoading: true);
    try {
      final accounts = await _repository.getAllAccounts();
      state = state.copyWith(accounts: accounts, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
    }
  }

  Future<void> addAccount(AccountEntity account) async {
    try {
      final newId = await _repository.addAccount(account);
      
      if (account.accountType == 'CREDIT_CARD' && account.enableReminder && account.billPaymentDate != null) {
        await NotificationService().scheduleMonthlyNotification(
          id: 80000 + newId,
          title: 'Credit Card Bill Reminder',
          body: '${account.bankName} bill payment is coming up.',
          dayOfMonth: account.billPaymentDate!,
        );
      }
      
      await loadAccounts();
    } catch (e) {
      state = state.copyWith(errorMessage: e.toString());
    }
  }

  Future<void> updateAccount(AccountEntity account) async {
    try {
      await _repository.updateAccount(account);
      
      if (account.accountType == 'CREDIT_CARD' && account.enableReminder && account.billPaymentDate != null && account.id != null) {
        await NotificationService().scheduleMonthlyNotification(
          id: 80000 + account.id!,
          title: 'Credit Card Bill Reminder',
          body: '${account.bankName} bill payment is coming up.',
          dayOfMonth: account.billPaymentDate!,
        );
      } else if (account.id != null) {
        await NotificationService().cancelNotification(80000 + account.id!);
      }

      await loadAccounts();
    } catch (e) {
      state = state.copyWith(errorMessage: e.toString());
    }
  }

  Future<void> deleteAccount(int id) async {
    if (state.accounts.length <= 1) {
      state = state.copyWith(errorMessage: "Cannot delete the last remaining account.");
      return;
    }
    
    state = state.copyWith(isLoading: true);
    try {
      await _repository.deleteAccount(id);
      await NotificationService().cancelNotification(80000 + id);
      await loadAccounts();
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
    }
  }

  Future<void> setDefaultAccount(int id) async {
    state = state.copyWith(isLoading: true);
    try {
      await _repository.setDefaultAccount(id);
      await loadAccounts();
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
    }
  }
}

final accountRepositoryProvider = Provider<AccountRepository>((ref) {
  return AccountRepositoryImpl();
});

final accountProvider = StateNotifierProvider<AccountNotifier, AccountState>((ref) {
  final repository = ref.watch(accountRepositoryProvider);
  return AccountNotifier(repository);
});
