import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cointally/presentation/notifiers/budget_notifier.dart';
import 'package:cointally/presentation/screens/budget_creation_screen.dart';
import 'package:cointally/presentation/widgets/budget_pie_chart.dart';
import 'package:cointally/presentation/notifiers/locale_notifier.dart';
import 'package:cointally/domain/entities/budget_progress.dart';
import 'package:cointally/presentation/notifiers/category_notifier.dart';
import 'package:cointally/presentation/notifiers/format_preferences_notifier.dart';
import 'package:cointally/core/utils/format_utils.dart';
import 'package:cointally/presentation/widgets/sleek_components.dart';
import 'package:cointally/presentation/notifiers/currency_notifier.dart';
import 'package:cointally/presentation/widgets/currency_selector.dart';

class BudgetListScreen extends ConsumerWidget {
  const BudgetListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final budgetState = ref.watch(budgetProvider);
    final progressList = ref.watch(budgetProgressProvider);
    final formatPrefs = ref.watch(formatPreferencesProvider);
    final currencyState = ref.watch(currencyNotifierProvider);
    final primaryCurrencyData = CurrencySelector.currencies.firstWhere(
      (c) => c.code == currencyState.primaryCurrency,
      orElse: () => CurrencySelector.currencies.first,
    );
    final symbol = primaryCurrencyData.symbol;
    
    final overallProgress = progressList.where((p) => p.budget.isOverall).firstOrNull;
    final categoryProgressList = progressList.where((p) => !p.budget.isOverall).toList();

    double totalBudget = overallProgress?.budget.monthlyLimit ?? categoryProgressList.fold(0, (sum, p) => sum + p.budget.monthlyLimit);
    double totalSpent = progressList.where((p) => p.budget.isOverall).firstOrNull?.amountSpent ?? categoryProgressList.fold(0, (sum, p) => sum + p.amountSpent);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text('Budgets', style: GoogleFonts.manrope(fontWeight: FontWeight.w700)),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: TextButton(
              onPressed: () {
                Navigator.push(context, MaterialPageRoute(builder: (context) => const BudgetCreationScreen()));
              },
              child: Text(
                'Create Budget',
                style: GoogleFonts.manrope(
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
            ),
          ),
        ],
      ),
      body: budgetState.isLoading
          ? Center(child: CircularProgressIndicator(color: Theme.of(context).colorScheme.primary))
          : progressList.isEmpty
              ? _buildEmptyState(context)
              : ListView(
                  padding: const EdgeInsets.all(24),
                  children: [
                    // Overall Budget Card (If exists)
                    if (overallProgress != null) ...[
                      _buildOverallCard(context, ref, overallProgress, formatPrefs, symbol),
                      const SizedBox(height: 32),
                    ],

                    // Summary Card (Pie Chart & Stats)
                    if (categoryProgressList.isNotEmpty) ...[
                      PremiumCard(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          children: [
                            BudgetPieChart(progressList: categoryProgressList),
                            const SizedBox(height: 24),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceAround,
                              children: [
                                _buildSummaryItem(context, 'Cat. Budget', FormatUtils.formatCurrency(categoryProgressList.fold(0.0, (sum, p) => sum + p.budget.monthlyLimit), prefs: formatPrefs, symbol: symbol, forceDecimals: false)),
                                Container(width: 1, height: 30, color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.1)),
                                _buildSummaryItem(context, 'Cat. Spent', FormatUtils.formatCurrency(categoryProgressList.fold(0.0, (sum, p) => sum + p.amountSpent), prefs: formatPrefs, symbol: symbol, forceDecimals: false)),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 32),
                    ],

                    if (categoryProgressList.isNotEmpty) ...[
                      Text(
                        'Category Budgets',
                        style: GoogleFonts.manrope(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Theme.of(context).textTheme.titleMedium?.color,
                        ),
                      ),
                      const SizedBox(height: 16),
                      ...categoryProgressList.map((progress) => _buildBudgetCard(context, ref, progress, formatPrefs, symbol)).toList(),
                    ],
                    
                    const SizedBox(height: 80),
                  ],
                ),
    );
  }

  Widget _buildOverallCard(BuildContext context, WidgetRef ref, BudgetProgress progress, FormatPreferencesState formatPrefs, String symbol) {
    final budget = progress.budget;
    final isOver = progress.isOverBudget;
    final progressColor = isOver ? Colors.red : Theme.of(context).colorScheme.primary;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Theme.of(context).colorScheme.primary.withOpacity(0.15),
            Colors.transparent,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Theme.of(context).colorScheme.primary.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.speed_rounded, color: Theme.of(context).colorScheme.primary, size: 28),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Overall Monthly Limit',
                            style: GoogleFonts.manrope(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Track all your expenses',
                            style: GoogleFonts.manrope(
                              fontSize: 12,
                              color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.4),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Row(
                children: [
                  IconButton(
                    icon: Icon(Icons.edit_rounded, color: Theme.of(context).colorScheme.primary, size: 20),
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => BudgetCreationScreen(existingBudget: budget),
                      ),
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.delete_outline_rounded, color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.2), size: 20),
                    onPressed: () => _showDeleteDialog(context, ref, budget.id!, budget.category),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 32),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        FormatUtils.formatCurrency(progress.amountSpent, prefs: formatPrefs, symbol: symbol, forceDecimals: false),
                        style: GoogleFonts.manrope(
                          fontSize: 32,
                          fontWeight: FontWeight.w800,
                          color: Theme.of(context).textTheme.displayLarge?.color,
                        ),
                      ),
                    ),
                    Text(
                      'of ${FormatUtils.formatCurrency(progress.budget.monthlyLimit, prefs: formatPrefs, symbol: symbol, forceDecimals: false)}',
                      style: GoogleFonts.manrope(
                        fontSize: 14,
                        color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.3),
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
              Text(
                FormatUtils.formatPercentage(progress.percentage, prefs: formatPrefs),
                style: GoogleFonts.manrope(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: progressColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: LinearProgressIndicator(
              value: progress.percentage > 1.0 ? 1.0 : progress.percentage,
              minHeight: 10,
              backgroundColor: Colors.white.withOpacity(0.05),
              valueColor: AlwaysStoppedAnimation<Color>(progressColor),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBudgetCard(BuildContext context, WidgetRef ref, BudgetProgress progress, FormatPreferencesState formatPrefs, String symbol) {
    final budget = progress.budget;
    final isOver = progress.isOverBudget;
    final progressColor = isOver ? Colors.red : Theme.of(context).colorScheme.primary;
    
    final categoryState = ref.watch(categoryProvider);
    final categoryData = categoryState.categories
        .where((c) => c.name.toLowerCase() == budget.category.toLowerCase())
        .firstOrNull;
    
    final categoryIcon = categoryData?.icon ?? Icons.category_rounded;
    final categoryColor = categoryData?.color ?? Theme.of(context).colorScheme.primary;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.05) ?? Colors.white.withOpacity(0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: categoryColor.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(categoryIcon, color: categoryColor, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    budget.category,
                    style: GoogleFonts.manrope(
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                      color: Theme.of(context).textTheme.bodyLarge?.color,
                    ),
                  ),
                ],
              ),
              Row(
                children: [
                  IconButton(
                    icon: Icon(Icons.edit_rounded, color: Theme.of(context).colorScheme.primary, size: 20),
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => BudgetCreationScreen(existingBudget: budget),
                      ),
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.delete_outline_rounded, color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.2), size: 20),
                    onPressed: () => _showDeleteDialog(context, ref, budget.id!, budget.category),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: Text(
                  '${FormatUtils.formatCurrency(progress.amountSpent, prefs: formatPrefs, symbol: symbol, forceDecimals: false)} spent',
                  style: GoogleFonts.manrope(
                    fontSize: 13,
                    color: isOver ? Colors.red : Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.4),
                    fontWeight: isOver ? FontWeight.w700 : FontWeight.w500,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'of ${FormatUtils.formatCurrency(budget.monthlyLimit, prefs: formatPrefs, symbol: symbol, forceDecimals: false)}',
                  textAlign: TextAlign.right,
                  style: GoogleFonts.manrope(
                    fontSize: 13,
                    color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.2),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: progress.percentage > 1.0 ? 1.0 : progress.percentage,
              minHeight: 6,
              backgroundColor: Colors.white.withOpacity(0.05),
              valueColor: AlwaysStoppedAnimation<Color>(progressColor),
            ),
          ),
          if (isOver) ...[
            const SizedBox(height: 8),
            Text(
              'Exceeded by ${FormatUtils.formatCurrency(progress.amountSpent - budget.monthlyLimit, prefs: formatPrefs, symbol: symbol, forceDecimals: false)}',
              style: GoogleFonts.manrope(
                fontSize: 11,
                color: Colors.red,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSummaryItem(BuildContext context, String label, String value) {
    return Expanded(
      child: Column(
        children: [
          Text(
            label,
            style: GoogleFonts.manrope(fontSize: 11, color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.3)),
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: GoogleFonts.manrope(fontSize: 16, fontWeight: FontWeight.w800, color: Theme.of(context).textTheme.bodyLarge?.color),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.pie_chart_outline_rounded, size: 64, color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.1)),
          const SizedBox(height: 24),
          Text(
            'No budgets yet',
            style: GoogleFonts.manrope(fontSize: 18, fontWeight: FontWeight.w600, color: Theme.of(context).textTheme.bodyLarge?.color?.withOpacity(0.4)),
          ),
          const SizedBox(height: 12),
          Text(
             'Set monthly limits for your expense categories to stay on track.',
             textAlign: TextAlign.center,
             style: GoogleFonts.manrope(fontSize: 14, color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.2)),
          ),
          const SizedBox(height: 24),
          NeonButton(
            text: 'Create First Budget',
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const BudgetCreationScreen())),
          ),
        ],
      ),
    );
  }

  void _showDeleteDialog(BuildContext context, WidgetRef ref, int id, String category) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).cardTheme.color,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Delete Budget', style: GoogleFonts.manrope(fontWeight: FontWeight.w700)),
        content: Text('Are you sure you want to delete the $category budget?', style: GoogleFonts.manrope(color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.6))),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: GoogleFonts.manrope(color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.4))),
          ),
          TextButton(
            onPressed: () {
              ref.read(budgetProvider.notifier).deleteBudget(id);
              Navigator.pop(context);
            },
            child: Text('Delete', style: GoogleFonts.manrope(color: Colors.red, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}
