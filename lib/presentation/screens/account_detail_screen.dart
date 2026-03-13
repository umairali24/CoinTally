import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cointally/domain/entities/account_entity.dart';
import 'package:cointally/domain/entities/transaction_entity.dart';
import 'package:cointally/presentation/notifiers/account_detail_notifier.dart';
import 'package:cointally/presentation/notifiers/transaction_notifier.dart';
import 'package:cointally/presentation/notifiers/account_notifier.dart';
import 'package:cointally/presentation/widgets/sleek_components.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:cointally/presentation/screens/add_transaction_screen.dart';
import 'package:cointally/core/utils/bank_utils.dart';
import 'package:cointally/presentation/widgets/currency_selector.dart';
import 'package:cointally/presentation/screens/add_account_screen.dart';
import 'package:cointally/presentation/widgets/growth_chart_card.dart';

class AccountDetailScreen extends ConsumerStatefulWidget {
  final AccountEntity account;

  const AccountDetailScreen({super.key, required this.account});

  @override
  ConsumerState<AccountDetailScreen> createState() => _AccountDetailScreenState();
}

class _AccountDetailScreenState extends ConsumerState<AccountDetailScreen> {
  String _activeFilter = 'All'; // 'All', 'Income', 'Expense'

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(accountDetailProvider(widget.account.id!));
    final accounts = ref.watch(accountProvider).accounts;
    final currentAccount = accounts.firstWhere(
      (a) => a.id == widget.account.id,
      orElse: () => widget.account,
    );
    final isCreditCard = currentAccount.accountType == 'CREDIT_CARD';

    final filteredTransactions = state.transactions.where((tx) {
      if (_activeFilter == 'Income') {
        return tx.type == 'INCOME' || 
               (tx.type == 'TRANSFER' && tx.toAccountId == currentAccount.id) || 
               (tx.type == 'ADJUSTMENT' && tx.amount > 0);
      }
      if (_activeFilter == 'Expense') {
        return tx.type == 'EXPENSE' || 
               (tx.type == 'TRANSFER' && tx.accountId == currentAccount.id) || 
               (tx.type == 'ADJUSTMENT' && tx.amount < 0);
      }
      return true; // 'All'
    }).toList();

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leadingWidth: 70,
        leading: Padding(
          padding: const EdgeInsets.only(left: 16, top: 8, bottom: 8),
          child: BankUtils.getLogoWidget(
            currentAccount.logoAssetPath,
            size: 24,
            color: isCreditCard ? Colors.red : Theme.of(context).colorScheme.primary,
            bankName: currentAccount.bankName,
          ),
        ),
        title: Text(currentAccount.bankName, style: GoogleFonts.manrope(fontWeight: FontWeight.w700)),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_rounded, color: Colors.white70),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => AddAccountScreen(existingAccount: currentAccount)),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent),
            onPressed: () => _showDeleteConfirmation(context, ref),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: state.isLoading
          ? Center(child: CircularProgressIndicator(color: Theme.of(context).colorScheme.primary))
          : RefreshIndicator(
              color: Theme.of(context).colorScheme.primary,
              backgroundColor: Theme.of(context).cardTheme.color,
              onRefresh: () => ref.read(accountDetailProvider(currentAccount.id!).notifier).loadData(),
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Account Balance Card
                    PremiumCard(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${CurrencySelector.currencies.firstWhere((c) => c.code == currentAccount.currencyCode, orElse: () => CurrencySelector.currencies.first).symbol} ${state.balance.toStringAsFixed(2)}',
                            style: GoogleFonts.manrope(
                              fontSize: 32,
                              fontWeight: FontWeight.w800,
                              color: isCreditCard ? Colors.red : Theme.of(context).textTheme.displayLarge?.color,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: TextButton.icon(
                                  onPressed: () => _showAdjustBalanceDialog(context, ref, state.balance),
                                  icon: Icon(Icons.edit_note_rounded, size: 18, color: Theme.of(context).colorScheme.primary),
                                  label: Text('Adjust Balance', style: GoogleFonts.manrope(fontSize: 12, color: Theme.of(context).colorScheme.primary)),
                                  style: TextButton.styleFrom(
                                    backgroundColor: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                                    padding: const EdgeInsets.symmetric(vertical: 8),
                                  ),
                                ),
                              ),
                              Builder(
                                builder: (context) {
                                  if (!currentAccount.isDefault) {
                                    return Expanded(
                                      child: TextButton.icon(
                                        onPressed: () => ref.read(accountProvider.notifier).setDefaultAccount(currentAccount.id!),
                                        icon: const Icon(Icons.star_rounded, size: 18, color: Colors.orange),
                                        label: Text('Set Default', style: GoogleFonts.manrope(fontSize: 12, color: Colors.orange)),
                                        style: TextButton.styleFrom(
                                          backgroundColor: Colors.orange.withOpacity(0.1),
                                          padding: const EdgeInsets.symmetric(vertical: 8),
                                        ),
                                      ),
                                    );
                                  } else {
                                    return Expanded(
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(vertical: 10),
                                        decoration: BoxDecoration(
                                          color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(8),
                                          border: Border.all(color: Theme.of(context).colorScheme.primary.withOpacity(0.2)),
                                        ),
                                        child: Center(
                                          child: Row(
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            children: [
                                              Icon(Icons.star_rounded, size: 14, color: Theme.of(context).colorScheme.primary),
                                              const SizedBox(width: 4),
                                              Text(
                                                'Default Account',
                                                style: GoogleFonts.manrope(
                                                  fontSize: 11, 
                                                  color: Theme.of(context).colorScheme.primary, 
                                                  fontWeight: FontWeight.bold
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    );
                                  }
                                },
                              ),
                            ],
                          ),
                          if (isCreditCard && currentAccount.creditLimit > 0) ...[
                            const SizedBox(height: 24),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Limit: ${CurrencySelector.currencies.firstWhere((c) => c.code == currentAccount.currencyCode, orElse: () => CurrencySelector.currencies.first).symbol} ${currentAccount.creditLimit.toStringAsFixed(0)}',
                                  style: TextStyle(fontSize: 12, color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.4)),
                                ),
                                Text(
                                  'Available: ${CurrencySelector.currencies.firstWhere((c) => c.code == widget.account.currencyCode, orElse: () => CurrencySelector.currencies.first).symbol} ${(widget.account.creditLimit - state.balance).toStringAsFixed(0)}',
                                  style: TextStyle(fontSize: 12, color: const Color(0xFF13EC13)),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                value: state.balance / widget.account.creditLimit,
                                backgroundColor: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.05),
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  (state.balance / widget.account.creditLimit) > 0.8 ? Colors.red : Colors.red.withOpacity(0.5)
                                ),
                                minHeight: 6,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),
                    // Growth Chart
                    GrowthChartCard(
                      currentBalance: state.balance,
                      transactions: state.transactions,
                      isPortfolio: false,
                      accountId: widget.account.id,
                    ),

                    const SizedBox(height: 32),

                    // Filter controls and Title
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          'Transactions',
                          style: GoogleFonts.manrope(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                        // Segmented control style buttons
                        Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: Theme.of(context).cardTheme.color,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: Colors.white.withOpacity(0.05)),
                          ),
                          child: Row(
                            children: [
                              _buildFilterButton('All'),
                              _buildFilterButton('Income'),
                              _buildFilterButton('Expense'),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    if (filteredTransactions.isEmpty)
                      _buildEmptyState(context)
                    else
                      ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: filteredTransactions.length,
                        itemBuilder: (context, index) {
                          final tx = filteredTransactions[index];
                          
                          // Logic for signs and colors
                          bool isIncome = tx.type == 'INCOME';
                          bool isTransferIn = tx.type == 'TRANSFER' && tx.toAccountId == widget.account.id;
                          bool isTransferOut = tx.type == 'TRANSFER' && tx.accountId == widget.account.id;
                          bool isExpense = tx.type == 'EXPENSE';
                          bool isAdjustment = tx.type == 'ADJUSTMENT';

                          // For credit cards, Income reduces debt (Safe), Expense increases debt (Red)
                          Color amountColor = Colors.white;
                          String prefix = '';
                          IconData icon = Icons.receipt_long_rounded;
                          Color iconBg = Colors.white.withOpacity(0.05);

                          if (isIncome || isTransferIn || (isAdjustment && tx.amount > 0)) {
                            amountColor = Theme.of(context).colorScheme.primary;
                            prefix = '+';
                            icon = isIncome ? Icons.south_west_rounded : (isAdjustment ? Icons.tune_rounded : Icons.move_to_inbox_rounded);
                            iconBg = Theme.of(context).colorScheme.primary.withOpacity(0.1);
                          } else if (isExpense || isTransferOut || (isAdjustment && tx.amount < 0)) {
                            amountColor = (isExpense || isAdjustment) && isCreditCard ? Colors.red : (isExpense || isAdjustment ? Colors.white : Colors.white);
                            // Adjusting color logic for standard accounts
                            if (!isCreditCard) {
                              amountColor = isExpense || (isAdjustment && tx.amount < 0) ? Colors.white : Theme.of(context).colorScheme.primary;
                            }
                            prefix = '-';
                            icon = isExpense ? Icons.arrow_outward_rounded : (isAdjustment ? Icons.tune_rounded : Icons.outbox_rounded);
                            iconBg = (isExpense || isAdjustment ? (isCreditCard ? Colors.red : Colors.white) : Colors.white).withOpacity(0.1);
                          }

                          return InkWell(
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => AddTransactionScreen(transaction: tx),
                              ),
                            ),
                            child: Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Theme.of(context).cardTheme.color,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.05) ?? Colors.white.withOpacity(0.05)),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: iconBg,
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(icon, color: amountColor, size: 20),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          tx.type == 'TRANSFER' 
                                            ? (isTransferIn ? 'Transfer In' : 'Transfer Out')
                                            : (tx.merchantName ?? tx.category),
                                        style: GoogleFonts.manrope(
                                          fontWeight: FontWeight.bold,
                                          color: Theme.of(context).textTheme.titleMedium?.color,
                                        ),
                                      ),
                                      Text(
                                        '${tx.date.toString().split(' ')[0]} • ${tx.category}',
                                        style: GoogleFonts.manrope(
                                          fontSize: 12,
                                          color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.4),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Text(
                                  '$prefix ${CurrencySelector.currencies.firstWhere((c) => c.code == widget.account.currencyCode, orElse: () => CurrencySelector.currencies.first).symbol} ${tx.amount.abs().toStringAsFixed(0)}',
                                  style: GoogleFonts.manrope(
                                    fontWeight: FontWeight.w800,
                                    color: amountColor,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                        },
                      ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildFilterButton(String label) {
    bool isSelected = _activeFilter == label;
    return GestureDetector(
      onTap: () {
        setState(() {
          _activeFilter = label;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? Theme.of(context).colorScheme.primary.withOpacity(0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          label,
          style: GoogleFonts.manrope(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
            color: isSelected 
                ? Theme.of(context).colorScheme.primary 
                : Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.5),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 40),
        child: Column(
          children: [
            Icon(Icons.history_rounded, size: 48, color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.05)),
            const SizedBox(height: 16),
            Text(
              'No matching transactions found.',
              style: TextStyle(color: Colors.white.withOpacity(0.2)),
            ),
          ],
        ),
      ),
    );
  }

  void _showAdjustBalanceDialog(BuildContext context, WidgetRef ref, double currentBalance) {
    final controller = TextEditingController(text: currentBalance.toStringAsFixed(2));
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).cardTheme.color,
        title: Text('Adjust Balance', style: GoogleFonts.manrope()),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Enter the new balance. This will create a one-time adjustment entry.',
              style: GoogleFonts.manrope(color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.6), fontSize: 13),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color),
              decoration: InputDecoration(
                prefixText: '${CurrencySelector.currencies.firstWhere((c) => c.code == widget.account.currencyCode, orElse: () => CurrencySelector.currencies.first).symbol} ',
                prefixStyle: TextStyle(color: Theme.of(context).colorScheme.primary),
                enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.1) ?? Colors.white.withOpacity(0.1))),
                focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Theme.of(context).colorScheme.primary)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: GoogleFonts.manrope(color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.4))),
          ),
          TextButton(
            onPressed: () async {
              final newBalance = double.tryParse(controller.text);
              if (newBalance != null) {
                // Determine if this is a Credit Card
                final isCreditCard = widget.account.accountType == 'CREDIT_CARD';
                
                // For credit cards, balance is "owed debt". 
                // Repository math: final_owed = initial_balance - net_tx
                // To INCREASE owed balance (diff > 0 visually), we need to DECREASE net_tx.
                // Ergo, diff = currentBalance - newBalance for Credit Cards.
                final diff = isCreditCard 
                    ? currentBalance - newBalance 
                    : newBalance - currentBalance;

                if (diff != 0) {
                  await ref.read(transactionProvider.notifier).addTransaction(
                    TransactionEntity(
                      amount: diff, 
                      type: 'ADJUSTMENT',
                      category: 'Adjustment',
                      date: DateTime.now(),
                      merchantName: 'Manual Balance Correction',
                      accountId: widget.account.id,
                      isAutoDetected: false,
                    )
                  );
                }
                Navigator.pop(context);
              }
            },
            child: Text('Save', style: TextStyle(color: Theme.of(context).colorScheme.primary)),
          ),
        ],
      ),
    );
  }

  void _showDeleteConfirmation(BuildContext context, WidgetRef ref) {
    final accounts = ref.watch(accountProvider).accounts;
    final isLastAccount = accounts.length <= 1;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).cardTheme.color,
        title: Text(
          isLastAccount ? 'Cannot Delete' : 'Delete Account?',
          style: GoogleFonts.manrope(fontWeight: FontWeight.bold),
        ),
        content: Text(
          isLastAccount
              ? 'You must have at least one account. Please add another account before deleting this one.'
              : 'This will permanently delete this account and ALL its associated transaction history, debts, and records. This action cannot be undone.',
          style: GoogleFonts.manrope(fontSize: 14, color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.8)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: GoogleFonts.manrope(color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.4))),
          ),
          if (!isLastAccount)
            TextButton(
              onPressed: () async {
                Navigator.pop(context); // Close dialog
                // Show loading indicator or handle state
                await ref.read(accountProvider.notifier).deleteAccount(widget.account.id!);
                if (context.mounted) {
                  Navigator.pop(context); // Go back to account list
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Account deleted successfully')),
                  );
                }
              },
              child: const Text('Delete Permanently', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
            ),
        ],
      ),
    );
  }
}

