import 'dart:developer';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cointally/data/local/db_helper.dart';
import 'package:cointally/presentation/notifiers/transaction_notifier.dart';
import 'package:cointally/presentation/notifiers/account_notifier.dart';
import 'package:cointally/core/services/telemetry_service.dart';
import 'package:cointally/core/services/notification_service.dart';
import 'package:cointally/presentation/notifiers/streak_notifier.dart';

class PendingTransactionState {
  final List<Map<String, dynamic>> pendingTransactions;
  final bool isLoading;

  PendingTransactionState({
    required this.pendingTransactions,
    this.isLoading = false,
  });

  PendingTransactionState copyWith({
    List<Map<String, dynamic>>? pendingTransactions,
    bool? isLoading,
  }) {
    return PendingTransactionState(
      pendingTransactions: pendingTransactions ?? this.pendingTransactions,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

class PendingTransactionNotifier extends StateNotifier<PendingTransactionState> {
  final Ref ref;
  PendingTransactionNotifier(this.ref) : super(PendingTransactionState(pendingTransactions: [])) {
    // Setup real-time listener for instant updates
    NotificationService().setupRealTimeListener(() {
      loadPendingTransactions();
    });
  }

  Future<void> loadPendingTransactions() async {
    state = state.copyWith(isLoading: true);
    final pts = await DatabaseHelper.instance.getPendingTransactions();
    state = state.copyWith(pendingTransactions: pts, isLoading: false);
    
    // Also update badge count when loading/refreshing
    NotificationService.updateBadgeCount();
  }

  Future<void> deletePending(int id) async {
    await DatabaseHelper.instance.deletePendingTransaction(id);
    await loadPendingTransactions();
  }

  Future<void> markAsSpam(int id, String senderId, {String? packageName}) async {
    await DatabaseHelper.instance.deletePendingTransaction(id);
    await DatabaseHelper.instance.blockSender(senderId, packageName: packageName);
    await loadPendingTransactions();
  }

  Future<void> reconcile(int id, Map<String, dynamic> transactionData, {Map<String, dynamic>? learnedRule}) async {
    try {
      // Skip adding a regular transaction if this is a debt reconcile placeholder.
      // In that case, the debt was already saved by AddTransactionScreen.
      final bool isDebtReconcile = transactionData['is_debt_reconcile'] == true;

      if (!isDebtReconcile) {
        // 1. Add to real transactions
        final int newTxId = await DatabaseHelper.instance.addTransaction(transactionData);
        
        // 1.5 Auto-Merge if it's a transfer pair
        if (transactionData['type'] == 'INCOME' || transactionData['type'] == 'EXPENSE') {
          final mergeMap = Map<String, dynamic>.from(transactionData);
          mergeMap['id'] = newTxId;
          await DatabaseHelper.instance.checkAndMergeTransfer(newTxId, mergeMap);
        }
      }
      
      // 2. Mark as reconciled
      await DatabaseHelper.instance.markPendingAsReconciled(id);

      
      // 2.1 Increment streak
      ref.read(streakNotifierProvider.notifier).incrementStreakSafely();
      
      // 3. Save learned rule if provided
      if (learnedRule != null) {
        print("PendingTransactionNotifier: learnedRule detected, processing for telemetry...");
        try {
          await DatabaseHelper.instance.saveLearnedRule(learnedRule);
          
          // 3.1 Crowdsourced Learning Trigger (Privacy-Safe Telemetry)
          final String? shortcode = learnedRule['shortcode']; 
          final String? packageName = learnedRule['package_name'];
          
          String? bankName;
          final int? accountId = learnedRule['target_account_id'] ?? transactionData['account_id'];
          if (accountId != null) {
            try {
              final accounts = ref.read(accountProvider).accounts;
              final account = accounts.firstWhere((a) => a.id == accountId);
              bankName = account.bankName;
            } catch (e) {
              print("PendingTransactionNotifier: Could not find account name for ID $accountId");
            }
          }
          
          print("PendingTransactionNotifier: Prepared telemetry data - Bank: $bankName, Shortcode: $shortcode, Package: $packageName");

          if (bankName != null && ((shortcode != null && shortcode.isNotEmpty) || (packageName != null && packageName.isNotEmpty))) {
            print("PendingTransactionNotifier: Triggering TelemetryService.logRuleLearned...");
            TelemetryService().logRuleLearned(
              shortcode: shortcode,
              packageName: packageName,
              bankName: bankName,
            );
          } else {
            print("PendingTransactionNotifier: Telemetry skipped - Missing fields (Bank: $bankName, ID presence: ${shortcode ?? packageName})");
          }
        } catch (e) {
          log("Reconcile: Optional learning step failed: $e");
          print("PendingTransactionNotifier: ERROR in learning step: $e");
        }
      } else {
        print("PendingTransactionNotifier: No learnedRule provided for this reconciliation.");
      }
    } catch (e) {
      log("Reconcile: Main reconciliation step failed: $e");
      // Re-throw if the core transaction add failed
      rethrow;
    } finally {
      // 4. Always Refresh global transaction state
      ref.read(transactionProvider.notifier).loadData();
      ref.read(accountProvider.notifier).loadAccounts();
      
      // 5. Always Refresh pending list (which also updates badge and removes the item from view)
      await loadPendingTransactions();
    }
  }
}

final pendingTransactionProvider = StateNotifierProvider<PendingTransactionNotifier, PendingTransactionState>((ref) {
  return PendingTransactionNotifier(ref)..loadPendingTransactions();
});
