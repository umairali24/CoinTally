import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cointally/presentation/notifiers/pending_transaction_notifier.dart';
import 'package:cointally/presentation/notifiers/account_notifier.dart';
import 'package:cointally/presentation/screens/add_transaction_screen.dart';
import 'package:cointally/domain/entities/transaction_entity.dart';
import 'package:cointally/domain/entities/account_entity.dart';
import 'package:cointally/core/utils/bank_utils.dart';
import 'package:intl/intl.dart';

class PendingTransactionsScreen extends ConsumerWidget {
  const PendingTransactionsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(pendingTransactionProvider);
    final accounts = ref.watch(accountProvider).accounts;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text('Review Captures', style: GoogleFonts.manrope(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: state.isLoading
          ? const Center(child: CircularProgressIndicator())
          : state.pendingTransactions.isEmpty
              ? _buildEmptyState(context)
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: state.pendingTransactions.length,
                  itemBuilder: (context, index) {
                    final pt = state.pendingTransactions[index];
                    return _buildPendingCard(context, ref, pt);
                  },
                ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.done_all_rounded, size: 64, color: Theme.of(context).colorScheme.primary.withOpacity(0.5)),
          const SizedBox(height: 16),
          Text(
            'All caught up!',
            style: GoogleFonts.manrope(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'No new transactions to review.',
            style: GoogleFonts.manrope(color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.5)),
          ),
        ],
      ),
    );
  }

  Widget _buildPendingCard(BuildContext context, WidgetRef ref, Map<String, dynamic> pt) {
    final isExpense = pt['type'] == 'EXPENSE';
    final isTransfer = pt['type'] == 'TRANSFER';
    final date = DateTime.fromMillisecondsSinceEpoch(pt['date']);
    
    final accounts = ref.watch(accountProvider).accounts;
    
    // Find suggested accounts
    final suggestedAccount = accounts.cast<AccountEntity?>().firstWhere(
      (acc) => acc?.id == pt['suggested_account_id'],
      orElse: () => null,
    );
    final toAccount = accounts.cast<AccountEntity?>().firstWhere(
      (acc) => acc?.id == pt['to_account_id'],
      orElse: () => null,
    );

    // Dynamic icon/color logic
    IconData typeIcon;
    Color typeColor;
    if (isTransfer) {
      typeIcon = Icons.swap_horiz_rounded;
      typeColor = Colors.blue;
    } else if (isExpense) {
      typeIcon = Icons.arrow_outward_rounded;
      typeColor = Colors.red;
    } else {
      typeIcon = Icons.south_west_rounded;
      typeColor = Colors.green;
    }

    String accountSubtitle = suggestedAccount?.bankName ?? 'Wallet';
    if (isTransfer && toAccount != null) {
      accountSubtitle = '${suggestedAccount?.bankName} → ${toAccount.bankName}';
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.white.withOpacity(0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Date and Raw Text
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      DateFormat('MMM dd, hh:mm a').format(date),
                      style: GoogleFonts.manrope(fontSize: 12, color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.bold),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline_rounded, color: Colors.red, size: 20),
                      onPressed: () => _showDeleteDialog(context, ref, pt),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  pt['raw_body'] ?? '',
                  style: GoogleFonts.manrope(fontSize: 13, height: 1.4),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          // Body: Suggested Values
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: typeColor.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    typeIcon,
                    color: typeColor,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isTransfer ? 'Transfer to ${toAccount?.bankName ?? 'Unknown'}' : (pt['merchant_name'] ?? 'Unknown'),
                        style: GoogleFonts.manrope(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      Text(
                        accountSubtitle,
                        style: GoogleFonts.manrope(fontSize: 12, color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.6)),
                      ),
                    ],
                  ),
                ),
                Text(
                  'Rs. ${pt['amount']}',
                  style: GoogleFonts.manrope(fontWeight: FontWeight.w800, fontSize: 18),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          // Actions
          Padding(
            padding: const EdgeInsets.all(8),
            child: Row(
              children: [
                Expanded(
                  child: TextButton.icon(
                    icon: const Icon(Icons.edit_rounded, size: 18),
                    label: const Text('Edit'),
                    onPressed: () => _openEdit(context, ref, pt),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.check_circle_outline_rounded, size: 18),
                    label: const Text('Confirm'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () => _reconcileQuick(context, ref, pt),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _reconcileQuick(BuildContext context, WidgetRef ref, Map<String, dynamic> pt) {
    final type = pt['type'];
    final tx = TransactionEntity(
      amount: pt['amount'],
      type: type,
      category: type == 'TRANSFER' ? 'Transfer' : (type == 'INCOME' ? 'Salary' : 'Other'),
      date: DateTime.fromMillisecondsSinceEpoch(pt['date']),
      merchantName: pt['merchant_name'],
      accountId: pt['suggested_account_id'],
      toAccountId: pt['to_account_id'],
      isAutoDetected: true,
    );

    ref.read(pendingTransactionProvider.notifier).reconcile(pt['id'], tx.toMap());
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Transaction confirmed!'), duration: Duration(seconds: 1)),
    );
  }

  void _openEdit(BuildContext context, WidgetRef ref, Map<String, dynamic> pt) {
    final type = pt['type'];
    final tx = TransactionEntity(
      amount: pt['amount'],
      type: type,
      category: type == 'TRANSFER' ? 'Transfer' : (type == 'INCOME' ? 'Salary' : 'Other'),
      date: DateTime.fromMillisecondsSinceEpoch(pt['date']),
      merchantName: pt['merchant_name'],
      accountId: pt['suggested_account_id'],
      toAccountId: pt['to_account_id'],
      isAutoDetected: true,
    );

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddTransactionScreen(
          transaction: tx,
          onSave: (confirmedTx) {
            // Determine if we should learn this
            final bool accountChanged = confirmedTx.accountId != pt['suggested_account_id'];
            final bool merchantChanged = confirmedTx.merchantName != pt['merchant_name'];
            
             Map<String, dynamic>? learnedRule;
            if (accountChanged || merchantChanged) {
               // Simple keyword detection: use the merchant name as keyword if it's in the body
               final body = (pt['raw_body'] as String).toLowerCase();
               final merchant = (confirmedTx.merchantName ?? '').toLowerCase();
               
               String keyword = merchant;
               if (!body.contains(merchant)) {
                  // Fallback: if merchant isn't in body, try to find another keyword or just use the whole body context?
                  // For now, let's keep it simple: if you edit it, we try to learn it using a significant word
                  final words = merchant.split(' ');
                  if (words.isNotEmpty) keyword = words.first;
               }

               // Verify Source to feed Telemetry Correctly
               String? passedPackageName;
               String? passedShortcode;
               final String rawPackage = pt['package_name'] ?? '';
               
               if (rawPackage.isNotEmpty &&
                   (rawPackage.contains('com.google.android.apps.messaging') || 
                    rawPackage.contains('com.samsung.android.messaging') || 
                    rawPackage.toLowerCase().contains('messaging') ||
                    rawPackage.toLowerCase().contains('sms'))) {
                 // It's an SMS App
                 passedShortcode = pt['raw_title'];
                 passedPackageName = null;
               } else {
                 // It's likely an official Banking App
                 passedShortcode = null;
                 passedPackageName = rawPackage; 
               }

                learnedRule = {
                  'package_name': passedPackageName,
                  'shortcode': passedShortcode, // Added for telemetry
                  'keyword': keyword,
                  'target_account_id': confirmedTx.accountId,
                  'target_merchant_name': confirmedTx.merchantName,
                };
             }

            ref.read(pendingTransactionProvider.notifier).reconcile(
              pt['id'], 
              confirmedTx.toMap(),
              learnedRule: learnedRule,
            );
            Navigator.pop(context); // Close edit screen
          },
        ),
      ),
    );
  }

  void _showDeleteDialog(BuildContext context, WidgetRef ref, Map<String, dynamic> pt) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Discard Transaction?', style: GoogleFonts.manrope(fontWeight: FontWeight.bold)),
        content: Text(
          'Do you want to discard this transaction once, or mark it as non-financial to ignore future messages from this sender?',
          style: GoogleFonts.manrope(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: GoogleFonts.manrope(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () {
              ref.read(pendingTransactionProvider.notifier).deletePending(pt['id']);
              Navigator.pop(context);
            },
            child: Text('Discard Once', style: GoogleFonts.manrope()),
          ),
          TextButton(
            onPressed: () {
              ref.read(pendingTransactionProvider.notifier).markAsSpam(
                pt['id'], 
                pt['raw_title'] ?? 'Unknown',
                packageName: pt['package_name'],
              );
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Sender blocked. Future messages will be ignored.')),
              );
            },
            child: Text('Mark Non-Financial', style: GoogleFonts.manrope(color: Colors.red, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}
