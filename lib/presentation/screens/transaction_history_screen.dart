import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cointally/presentation/notifiers/transaction_notifier.dart';
import 'package:cointally/presentation/screens/add_transaction_screen.dart';
import 'package:cointally/presentation/widgets/sleek_components.dart';
import 'package:cointally/presentation/notifiers/account_notifier.dart';
import 'package:cointally/domain/entities/account_entity.dart';
import 'package:cointally/domain/entities/transaction_entity.dart';
import 'package:cointally/domain/entities/category_entity.dart';
import 'package:cointally/presentation/notifiers/category_notifier.dart';
import 'package:cointally/presentation/notifiers/currency_notifier.dart';
import 'package:cointally/presentation/widgets/currency_selector.dart';
import 'package:cointally/presentation/notifiers/format_preferences_notifier.dart';
import 'package:cointally/core/utils/format_utils.dart';
import 'package:intl/intl.dart';

class TransactionHistoryScreen extends ConsumerWidget {
  const TransactionHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(transactionProvider);
    final notifier = ref.watch(transactionProvider.notifier);
    final transactions = notifier.filteredTransactions;
    
    // Simple grouping by date
    final Map<String, List<TransactionEntity>> groupedTransactions = {};
    for (var tx in transactions) {
       final dateStr = DateFormat('EEEE, MMM dd, yyyy').format(tx.date);
       if (!groupedTransactions.containsKey(dateStr)) {
         groupedTransactions[dateStr] = [];
       }
       groupedTransactions[dateStr]!.add(tx);
    }

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text('History', style: GoogleFonts.manrope(fontWeight: FontWeight.w700)),
      ),
      body: Column(
        children: [
          // Search & Filter Bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    onChanged: (value) => notifier.setSearchQuery(value),
                    style: GoogleFonts.manrope(
                      fontSize: 14,
                      color: Theme.of(context).textTheme.bodyLarge?.color,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Search transactions...',
                      hintStyle: TextStyle(
                        color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.3),
                        fontSize: 14,
                      ),
                      prefixIcon: Icon(
                        Icons.search_rounded,
                        color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.3),
                        size: 20,
                      ),
                      filled: true,
                      fillColor: Theme.of(context).cardTheme.color,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.05) ?? Colors.white.withOpacity(0.05),
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.05) ?? Colors.white.withOpacity(0.05),
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Theme.of(context).colorScheme.primary, width: 1.5),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                InkWell(
                  onTap: () async {
                    final DateTimeRange? picked = await showDateRangePicker(
                      context: context,
                      firstDate: DateTime(2000),
                      lastDate: DateTime.now(),
                      builder: (context, child) {
                        return Theme(
                          data: Theme.of(context).copyWith(
                            colorScheme: Theme.of(context).colorScheme.copyWith(
                              primary: Theme.of(context).colorScheme.primary,
                              onPrimary: Colors.black,
                              surface: Theme.of(context).scaffoldBackgroundColor,
                              onSurface: Theme.of(context).textTheme.bodyLarge?.color ?? Colors.white,
                            ),
                          ),
                          child: child!,
                        );
                      },
                    );
                    if (picked != null) {
                      notifier.setCustomDateRange(picked.start, picked.end);
                    }
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Theme.of(context).cardTheme.color,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.05) ?? Colors.white.withOpacity(0.05)),
                    ),
                    child: Icon(Icons.date_range_rounded, color: Theme.of(context).colorScheme.primary, size: 20),
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 24),

          // Horizontal Date Filter
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: ['All Time', 'Today', 'Yesterday', 'This Week', 'This Month', 'Custom'].map((filter) {
                final isSelected = filter == state.selectedFilter;
                
                String displayLabel = filter;
                if (filter == 'Custom' && state.customStartDate != null && state.customEndDate != null) {
                  final startStr = DateFormat('MMM d').format(state.customStartDate!);
                  final endStr = DateFormat('MMM d').format(state.customEndDate!);
                  displayLabel = '$startStr - $endStr';
                }

                return InkWell(
                  onTap: () async {
                    if (filter == 'Custom') {
                      final DateTimeRange? picked = await showDateRangePicker(
                        context: context,
                        firstDate: DateTime(2000),
                        lastDate: DateTime.now(),
                        builder: (context, child) {
                          return Theme(
                            data: Theme.of(context).copyWith(
                              colorScheme: Theme.of(context).colorScheme.copyWith(
                                primary: Theme.of(context).colorScheme.primary,
                                onPrimary: Colors.black,
                                surface: Theme.of(context).scaffoldBackgroundColor,
                                onSurface: Theme.of(context).textTheme.bodyLarge?.color ?? Colors.white,
                              ),
                            ),
                            child: child!,
                          );
                        },
                      );
                      if (picked != null) {
                        notifier.setCustomDateRange(picked.start, picked.end);
                      }
                    } else {
                      notifier.setFilter(filter);
                    }
                  },
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: isSelected ? Theme.of(context).colorScheme.primary : Theme.of(context).cardTheme.color,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: isSelected ? Colors.transparent : (Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.05) ?? Colors.white.withOpacity(0.05))),
                    ),
                    child: Text(
                      displayLabel,
                      style: GoogleFonts.manrope(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: isSelected ? Colors.black : Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.4),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),

          const SizedBox(height: 24),

          Expanded(
            child: transactions.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.history_rounded, size: 64, color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.1)),
                        const SizedBox(height: 16),
                        Text(
                          state.searchQuery.isEmpty ? 'No history found' : 'No matches found',
                          style: GoogleFonts.manrope(
                            color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.4),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    itemCount: groupedTransactions.keys.length,
                    itemBuilder: (context, dateIndex) {
                      final date = groupedTransactions.keys.elementAt(dateIndex);
                      final List<TransactionEntity> transactions = groupedTransactions[date]!;
                      
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 16.0),
                            child: Text(
                              date.toUpperCase(),
                              style: GoogleFonts.manrope(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1.2,
                                color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.4),
                              ),
                            ),
                          ),
                          ...transactions.map((tx) {
                            final isExpense = tx.type == 'EXPENSE';
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
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.05) ?? Colors.white.withOpacity(0.02)),
                                ),
                                child: Row(
                                  children: [
                                    (() {
                                      final category = ref.watch(categoryProvider).categories.firstWhere((c) => c.name == tx.category, orElse: () => CategoryEntity(name: 'Other', icon: Icons.receipt_long_rounded, color: Theme.of(context).colorScheme.primary));
                                      return Container(
                                        padding: const EdgeInsets.all(10),
                                        decoration: BoxDecoration(
                                          color: category.color.withOpacity(0.05),
                                          shape: BoxShape.circle,
                                          boxShadow: [
                                            BoxShadow(
                                              color: category.color.withOpacity(0.05),
                                              blurRadius: 10,
                                              spreadRadius: 2,
                                            ),
                                          ],
                                        ),
                                        child: Icon(
                                          category.icon,
                                          color: category.color,
                                          size: 20,
                                        ),
                                      );
                                    })(),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            tx.merchantName ?? tx.category,
                                            style: GoogleFonts.manrope(
                                              fontWeight: FontWeight.w700,
                                              color: Theme.of(context).textTheme.bodyLarge?.color,
                                            ),
                                          ),
                                          Text(
                                            (ref.watch(accountProvider).accounts.where((a) => a.id == tx.accountId).firstOrNull)?.bankName ?? 'Wallet',
                                            style: GoogleFonts.manrope(
                                              fontSize: 11,
                                              color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.3),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Builder(
                                      builder: (context) {
                                        final account = ref.watch(accountProvider).accounts.where((a) => a.id == tx.accountId).firstOrNull;
                                        final currencyCode = account?.currencyCode ?? 'PKR';
                                        final currencyData = CurrencySelector.currencies.firstWhere(
                                          (c) => c.code == currencyCode,
                                          orElse: () => CurrencySelector.currencies.first,
                                        );
                                        return Text(
                                          '${isExpense ? '-' : '+'}${FormatUtils.formatCurrency(tx.amount, prefs: ref.watch(formatPreferencesProvider), symbol: currencyData.symbol, forceDecimals: false)}',
                                          style: GoogleFonts.manrope(
                                            fontWeight: FontWeight.w800,
                                            color: isExpense ? Theme.of(context).textTheme.bodyLarge?.color : Theme.of(context).colorScheme.primary,
                                          ),
                                        );
                                      },
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }).toList(),
                        ],
                      );
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: null,
        onPressed: () {
          Navigator.push(context, MaterialPageRoute(builder: (context) => const AddTransactionScreen()));
        },
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.black,
        child: const Icon(Icons.add_rounded, size: 28),
      ),
    );
  }
}
