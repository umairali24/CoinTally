import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cointally/presentation/notifiers/transaction_notifier.dart';
import 'package:cointally/presentation/screens/add_transaction_screen.dart';
import 'package:cointally/presentation/screens/zakat_screen.dart';
import 'package:cointally/presentation/screens/budget_list_screen.dart';
import 'package:cointally/presentation/screens/account_list_screen.dart';
import 'package:cointally/presentation/notifiers/locale_notifier.dart';
import 'package:cointally/presentation/notifiers/budget_notifier.dart';
import 'package:cointally/presentation/screens/transaction_history_screen.dart';
import 'package:cointally/presentation/screens/settings_screen.dart';
import 'package:cointally/presentation/screens/goal_list_screen.dart';
import 'package:cointally/presentation/widgets/sleek_components.dart';
import 'package:cointally/presentation/notifiers/goal_notifier.dart';
import 'package:cointally/presentation/notifiers/account_notifier.dart';
import 'package:cointally/presentation/notifiers/account_detail_notifier.dart';
import 'package:cointally/presentation/screens/account_detail_screen.dart';
import 'package:cointally/domain/entities/account_entity.dart';
import 'package:cointally/core/utils/bank_utils.dart';
import 'package:cointally/presentation/notifiers/pending_transaction_notifier.dart';
import 'package:cointally/presentation/screens/pending_transactions_screen.dart';
import 'package:cointally/presentation/screens/add_account_screen.dart';
import 'package:cointally/presentation/notifiers/currency_notifier.dart';
import 'package:cointally/presentation/widgets/currency_selector.dart';
import 'package:cointally/presentation/notifiers/feature_notifier.dart';
import 'package:cointally/presentation/notifiers/streak_notifier.dart';
import 'package:cointally/presentation/notifiers/format_preferences_notifier.dart';
import 'package:cointally/core/utils/format_utils.dart';
import 'package:cointally/presentation/widgets/streak_calendar_row.dart';
import 'package:cointally/presentation/widgets/net_liquidity_card.dart';
import 'package:cointally/presentation/widgets/monthly_budget_card.dart';
import 'package:cointally/presentation/widgets/cashflow_overview_card.dart';
import 'package:cointally/presentation/notifiers/dashboard_order_notifier.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  String? _userName;

  @override
  void initState() {
    super.initState();
    _loadUserName();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(transactionProvider.notifier).loadData();
    });
  }

  Future<void> _loadUserName() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _userName = prefs.getString('user_name');
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(transactionProvider);
    final localeNotifier = ref.read(localeProvider.notifier);
    final currencyState = ref.watch(currencyNotifierProvider);
    final formatPrefs = ref.watch(formatPreferencesProvider);
    final primaryCurrencyData = CurrencySelector.currencies.firstWhere(
      (c) => c.code == currencyState.primaryCurrency,
      orElse: () => CurrencySelector.currencies.first,
    );
    final symbol = primaryCurrencyData.symbol;
    final dashboardWidgets = ref.watch(dashboardOrderProvider);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          _userName != null ? 'Welcome, $_userName' : 'Welcome',
          style: GoogleFonts.manrope(fontWeight: FontWeight.w800),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await Future.wait([
            ref.read(transactionProvider.notifier).loadData(),
            ref.read(accountProvider.notifier).loadAccounts(),
            ref.read(pendingTransactionProvider.notifier).loadPendingTransactions(),
            ref.read(budgetProvider.notifier).loadBudgets(),
          ]);
        },
        child: state.isLoading
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Streak Status Widget
                  _buildStreakStatus(context, ref),
                  const SizedBox(height: 20),
                  // Review Badge
                  if (ref.watch(pendingTransactionProvider).pendingTransactions.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 20),
                      child: InkWell(
                        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const PendingTransactionsScreen())),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [Theme.of(context).colorScheme.primary, Theme.of(context).colorScheme.primary.withOpacity(0.8)],
                            ),
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: Theme.of(context).colorScheme.primary.withOpacity(0.3),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 20),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  '${ref.watch(pendingTransactionProvider).pendingTransactions.length} transaction captures to review',
                                  style: GoogleFonts.manrope(color: Colors.white, fontWeight: FontWeight.bold),
                                ),
                              ),
                              const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white, size: 14),
                            ],
                          ),
                        ),
                      ),
                    ),
                  
                  // Render dynamic widgets
                  ...dashboardWidgets.where((w) => w.isVisible).map((config) {
                    switch (config.id) {
                      case 'net_liquidity':
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: NetLiquidityCard(
                            formattedTotal: FormatUtils.formatCurrency(state.totalBalance, prefs: formatPrefs, symbol: symbol, forceDecimals: false),
                            totalLiquidity: state.totalBalance,
                            accounts: ref.watch(accountProvider).accounts,
                            convertedFromText: ref.watch(accountProvider).accounts.any((acc) => acc.currencyCode != currencyState.primaryCurrency) 
                                ? '${ref.read(localeProvider.notifier).translate('converted_from')} ($symbol)' 
                                : null,
                          ),
                        );
                      case 'monthly_budget':
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: MonthlyBudgetCard(
                            totalBudget: ref.watch(totalBudgetProvider),
                            totalSpent: ref.watch(currentMonthTotalExpenseProvider),
                            currencySymbol: symbol,
                            formatPrefs: formatPrefs,
                          ),
                        );
                      case 'cashflow':
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 32),
                          child: CashflowOverviewCard(transactions: state.transactions),
                        );
                      case 'accounts':
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 32),
                          child: _buildAccountsGrid(context, ref),
                        );
                      case 'goals':
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 32),
                          child: _buildGoalsPreview(context, ref),
                        );
                      case 'recent_activity':
                        return _buildRecentActivity(context, ref, state);
                      default:
                        return const SizedBox.shrink();
                    }
                  }).toList(),

                  // Quick Actions (keep below widgets or as a fixed element, let's put it below dynamic widgets that are important or maybe before recent activity)
                  // Wait, looking at the layout, let's keep Quick Actions at the end or below accounts.
                  // For simplicity, we'll keep Quick Actions fixed at the bottom for now.
                  const SizedBox(height: 16),
                  Text(
                    ref.read(localeProvider.notifier).translate('quick_actions'),
                    style: GoogleFonts.manrope(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: Theme.of(context).textTheme.titleLarge?.color,
                    ),
                  ),
                  const SizedBox(height: 16),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        if (ref.watch(featureProvider).isZakatEnabled) ...[
                          _buildActionCard(
                            context,
                            'Zakaat',
                            'Calculate & Pay',
                            Icons.calculate_rounded,
                            () => Navigator.push(context, MaterialPageRoute(builder: (context) => const ZakatScreen())),
                          ),
                          const SizedBox(width: 12),
                        ],
                        _buildActionCard(
                          context,
                          'Goals',
                          'Saving & Debt',
                          Icons.flag_rounded,
                          () => Navigator.push(context, MaterialPageRoute(builder: (context) => const GoalListScreen())),
                        ),
                        const SizedBox(width: 12),
                        _buildActionCard(
                          context,
                          ref.read(localeProvider.notifier).translate('assets'),
                          ref.read(localeProvider.notifier).translate('manage_portfolio'),
                          Icons.pie_chart_rounded,
                          () => Navigator.push(context, MaterialPageRoute(builder: (context) => const AccountListScreen())),
                        ),
                        const SizedBox(width: 12),
                        _buildNoSpendButton(context, ref),
                      ],
                    ),
                  ),
                  const SizedBox(height: 40), 
                ],
              ),
            ),
      ),
    );
  }

  Widget _buildRecentActivity(BuildContext context, WidgetRef ref, dynamic state) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              ref.read(localeProvider.notifier).translate('recent_activity'),
              style: GoogleFonts.manrope(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Theme.of(context).textTheme.titleLarge?.color,
              ),
            ),
            TextButton(
              onPressed: () {
                Navigator.push(context, MaterialPageRoute(builder: (context) => const TransactionHistoryScreen()));
              },
              child: Text(ref.read(localeProvider.notifier).translate('see_all'), style: TextStyle(color: Theme.of(context).colorScheme.primary)),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (state.transactions.isEmpty)
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 40),
              child: Text(
                'No recent transactions',
                style: TextStyle(color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.4)),
              ),
            ),
          )
        else
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: state.transactions.length > 5 ? 5 : state.transactions.length,
            itemBuilder: (context, index) {
                        final tx = state.transactions[index];
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
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: (isExpense ? Colors.red : Theme.of(context).colorScheme.primary).withOpacity(0.1),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    isExpense ? Icons.arrow_outward_rounded : Icons.south_west_rounded,
                                    color: isExpense ? Colors.red : Theme.of(context).colorScheme.primary,
                                    size: 20,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        tx.merchantName ?? tx.category,
                                        style: GoogleFonts.manrope(
                                          fontWeight: FontWeight.bold,
                                          color: Theme.of(context).textTheme.bodyLarge?.color,
                                        ),
                                      ),
                                      Row(
                                        children: [
                                          Text(
                                            tx.date.toString().split(' ')[0],
                                            style: GoogleFonts.manrope(
                                              fontSize: 12,
                                              color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.4),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          if (tx.accountId != null)
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                                                borderRadius: BorderRadius.circular(4),
                                              ),
                                              child: Text(
                                                                                                (ref.watch(accountProvider).accounts.where((a) => a.id == tx.accountId).firstOrNull)?.bankName ?? 'Unknown',
                                                style: GoogleFonts.manrope(
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.bold,
                                                  color: Theme.of(context).colorScheme.primary,
                                                ),
                                              ),
                                            ),
                                        ],
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
                                      '${isExpense ? '-' : '+'} ${currencyData.symbol} ${tx.amount.toStringAsFixed(0)}',
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
                      },
                    ),
      ],
    );
  }

  Widget _buildSmallInfo(BuildContext context, String label, String value) {
    return Column(
      children: [
        Text(
          label,
          style: GoogleFonts.manrope(
            fontSize: 12,
            color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.4),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: GoogleFonts.manrope(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Theme.of(context).textTheme.bodyLarge?.color,
          ),
        ),
      ],
    );
  }

  Widget _buildGoalsPreview(BuildContext context, WidgetRef ref) {
    final goalState = ref.watch(goalProvider);
    final goals = goalState.goals;

    if (goals.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              ref.read(localeProvider.notifier).translate('goals_progress'),
              style: GoogleFonts.manrope(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Theme.of(context).textTheme.titleLarge?.color,
              ),
            ),
            TextButton(
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const GoalListScreen())),
              child: Text(ref.read(localeProvider.notifier).translate('view_all'), style: TextStyle(color: Theme.of(context).colorScheme.primary)),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ...goals.take(2).map((goal) {
          final progress = (goal.currentAmount / goal.targetAmount).clamp(0.0, 1.0);
          final progressColor = goal.type == 'SAVING' ? Theme.of(context).colorScheme.primary : Colors.red;
          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            child: PremiumCard(
              padding: EdgeInsets.zero,
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const GoalListScreen())),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (goal.imagePath != null && File(goal.imagePath!).existsSync())
                    ClipRRect(
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                      child: Image.file(
                        File(goal.imagePath!),
                        height: 100,
                        width: double.infinity,
                        fit: BoxFit.cover,
                      ),
                    ),
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(goal.title, style: GoogleFonts.manrope(fontWeight: FontWeight.bold, fontSize: 13)),
                            Text('${(progress * 100).toStringAsFixed(0)}%', style: GoogleFonts.manrope(fontSize: 11, fontWeight: FontWeight.bold, color: progressColor)),
                          ],
                        ),
                        const SizedBox(height: 8),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: progress,
                            backgroundColor: progressColor.withOpacity(0.1),
                            valueColor: AlwaysStoppedAnimation<Color>(progressColor),
                            minHeight: 4,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ],
    );
  }

  Widget _buildAccountsGrid(BuildContext context, WidgetRef ref) {
    final accountState = ref.watch(accountProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          ref.read(localeProvider.notifier).translate('accounts'),
          style: GoogleFonts.manrope(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: Theme.of(context).textTheme.titleLarge?.color,
          ),
        ),
        const SizedBox(height: 16),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          child: Row(
            children: [
              ...accountState.accounts.map((account) {
                final accountDetail = ref.watch(accountDetailProvider(account.id!));
                return Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: _buildAccountCard(context, account, accountDetail.balance),
                );
              }),
              _buildAddAccountButton(context),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAddAccountButton(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const AddAccountScreen()),
      ),
      child: Container(
        width: 140, // Reduced width
        padding: const EdgeInsets.all(16), // Reduced padding
        decoration: BoxDecoration(
          color: Theme.of(context).cardTheme.color?.withOpacity(0.5),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: Theme.of(context).colorScheme.primary.withOpacity(0.2),
            style: BorderStyle.solid,
            width: 1.5,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.add_rounded,
                color: Theme.of(context).colorScheme.primary,
                size: 30,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Add Account',
              style: GoogleFonts.manrope(
                fontWeight: FontWeight.w700,
                fontSize: 14,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAccountCard(BuildContext context, AccountEntity account, double balance) {
    final isCreditCard = account.accountType == 'CREDIT_CARD';
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => AccountDetailScreen(account: account)),
      ),
      child: Container(
        width: 140, // Reduced width
        padding: const EdgeInsets.all(16), // Reduced padding
        decoration: BoxDecoration(
          color: Theme.of(context).cardTheme.color,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.05) ?? Colors.white.withOpacity(0.05)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: (isCreditCard ? Colors.red : Theme.of(context).colorScheme.primary).withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: BankUtils.getLogoWidget(
                account.logoAssetPath,
                size: 20,
                color: isCreditCard ? Colors.red : Theme.of(context).colorScheme.primary,
                bankName: account.bankName,
              ),
            ),
            const SizedBox(height: 12), // Reduced spacing
            Text(
              account.bankName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.manrope(
                fontWeight: FontWeight.w800,
                fontSize: 15,
                color: Theme.of(context).textTheme.titleMedium?.color,
              ),
            ),
            const SizedBox(height: 4),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Builder(
                  builder: (context) {
                    final currencyData = CurrencySelector.currencies.firstWhere(
                      (c) => c.code == account.currencyCode,
                      orElse: () => CurrencySelector.currencies.first,
                    );
                    return Text(
                      '${currencyData.symbol} ${balance.toStringAsFixed(0)}',
                      style: GoogleFonts.manrope(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: isCreditCard ? Colors.red : Theme.of(context).colorScheme.primary,
                      ),
                    );
                  },
                ),
                Consumer(
                  builder: (context, ref, child) {
                    final currencyState = ref.watch(currencyNotifierProvider);
                    if (account.currencyCode == currencyState.primaryCurrency) return const SizedBox.shrink();
                    
                    final primaryWorth = ref.read(currencyNotifierProvider.notifier).convertToPrimary(balance, account.currencyCode ?? 'PKR');
                    final primaryCurrencyData = CurrencySelector.currencies.firstWhere(
                      (c) => c.code == currencyState.primaryCurrency,
                      orElse: () => CurrencySelector.currencies.first,
                    );
                    
                    return Text(
                      '≈ ${primaryCurrencyData.symbol} ${primaryWorth.toStringAsFixed(0)}',
                      style: GoogleFonts.manrope(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.3),
                      ),
                    );
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStreakStatus(BuildContext context, WidgetRef ref) {
    final streakState = ref.watch(streakNotifierProvider);
    final history = ref.read(streakNotifierProvider.notifier).getWeeklyHistory();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Your Streak',
              style: GoogleFonts.manrope(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Theme.of(context).textTheme.titleLarge?.color,
              ),
            ),
            Row(
              children: [
                Icon(
                  Icons.ac_unit_rounded,
                  size: 14,
                  color: streakState.availableFreezes > 0 ? Colors.blue : Colors.grey.withOpacity(0.3),
                ),
                const SizedBox(width: 4),
                Text(
                  '${streakState.availableFreezes} Freezes',
                  style: GoogleFonts.manrope(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: streakState.availableFreezes > 0 ? Colors.blue : Colors.grey,
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 12),
        StreakCalendarRow(history: history),
      ],
    );
  }

  Widget _buildNoSpendButton(BuildContext context, WidgetRef ref) {
    final streakState = ref.watch(streakNotifierProvider);
    final isTodayActive = streakState.lastActiveDate == DateFormat('yyyy-MM-dd').format(DateTime.now());

    return _buildActionCard(
      context,
      'No Spend Day',
      isTodayActive ? 'Complete 🎯' : 'Mark Today 🎯',
      Icons.stars_rounded,
      isTodayActive 
        ? null 
        : () async {
            await ref.read(streakNotifierProvider.notifier).markNoSpendDay();
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Way to go! No-Spend day marked! 🎯🔥'),
                  behavior: SnackBarBehavior.floating,
                  duration: Duration(seconds: 2),
                ),
              );
            }
          },
      opacity: isTodayActive ? 0.5 : 1.0,
    );
  }

  Widget _buildActionCard(BuildContext context, String title, String subtitle, IconData icon, VoidCallback? onTap, {double opacity = 1.0}) {
    return Opacity(
      opacity: opacity,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Theme.of(context).cardTheme.color,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.05) ?? Colors.white.withOpacity(0.05)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: Theme.of(context).colorScheme.primary, size: 30),
              const SizedBox(height: 16),
              Text(
                title,
                style: GoogleFonts.manrope(
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                  color: Theme.of(context).textTheme.titleMedium?.color,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: GoogleFonts.manrope(
                  fontSize: 12,
                  color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.4),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
