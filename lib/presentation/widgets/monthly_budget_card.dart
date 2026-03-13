import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cointally/presentation/widgets/sleek_components.dart';
import 'package:cointally/presentation/notifiers/format_preferences_notifier.dart';
import 'package:cointally/core/utils/format_utils.dart';

class MonthlyBudgetCard extends StatelessWidget {
  final double totalBudget;
  final double totalSpent;
  final String currencySymbol;
  final FormatPreferencesState formatPrefs;

  const MonthlyBudgetCard({
    super.key,
    required this.totalBudget,
    required this.totalSpent,
    required this.currencySymbol,
    required this.formatPrefs,
  });

  @override
  Widget build(BuildContext context) {
    // Ensure we don't divide by zero
    final safeTotalBudget = totalBudget > 0 ? totalBudget : 1.0;
    final progress = (totalSpent / safeTotalBudget).clamp(0.0, 1.0);
    
    // Determine Color based on usage
    Color progressColor;
    if (progress >= 0.90) {
      progressColor = Colors.red;
    } else if (progress >= 0.75) {
      progressColor = Colors.orange;
    } else {
      progressColor = Theme.of(context).colorScheme.primary; // Green
    }

    // Calculate Daily Safe Limit
    final now = DateTime.now();
    // Get last day of current month
    final lastDayOfMonth = DateTime(now.year, now.month + 1, 0).day;
    final daysRemaining = (lastDayOfMonth - now.day) + 1; // +1 to include today
    
    final remainingBudget = (totalBudget - totalSpent).clamp(0.0, double.infinity);
    final dailySafeLimit = remainingBudget / daysRemaining;

    return PremiumCard(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top Row: Spent vs Total
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Spent',
                    style: GoogleFonts.manrope(
                      color: Theme.of(context).textTheme.bodyMedium?.color?.withValues(alpha: 0.6),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    FormatUtils.formatCurrency(totalSpent, prefs: formatPrefs, symbol: currencySymbol, forceDecimals: false),
                    style: GoogleFonts.manrope(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).textTheme.bodyLarge?.color,
                    ),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'Budget',
                    style: GoogleFonts.manrope(
                      color: Theme.of(context).textTheme.bodyMedium?.color?.withValues(alpha: 0.6),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    FormatUtils.formatCurrency(totalBudget, prefs: formatPrefs, symbol: currencySymbol, forceDecimals: false),
                    style: GoogleFonts.manrope(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).textTheme.bodyLarge?.color,
                    ),
                  ),
                ],
              ),
            ],
          ),
          
          const SizedBox(height: 16),
          
          // Middle Row: Progress Bar
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 12,
              backgroundColor: Theme.of(context).textTheme.bodyMedium?.color?.withValues(alpha: 0.05),
              valueColor: AlwaysStoppedAnimation<Color>(progressColor),
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Bottom Row: Remaining & Daily Safe Limit
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Theme.of(context).textTheme.bodyMedium?.color?.withValues(alpha: 0.03),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Remaining',
                        style: GoogleFonts.manrope(
                          color: Theme.of(context).textTheme.bodyMedium?.color?.withValues(alpha: 0.6),
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        FormatUtils.formatCurrency(remainingBudget, prefs: formatPrefs, symbol: currencySymbol, forceDecimals: false),
                        style: GoogleFonts.manrope(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: remainingBudget > 0 ? progressColor : Colors.red,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  width: 1,
                  height: 30,
                  color: Theme.of(context).textTheme.bodyMedium?.color?.withValues(alpha: 0.1),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        'Daily Safe Limit',
                        style: GoogleFonts.manrope(
                          color: Theme.of(context).textTheme.bodyMedium?.color?.withValues(alpha: 0.6),
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        FormatUtils.formatCurrency(dailySafeLimit, prefs: formatPrefs, symbol: currencySymbol, forceDecimals: false),
                        style: GoogleFonts.manrope(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
