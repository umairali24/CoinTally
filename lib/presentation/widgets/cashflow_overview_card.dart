import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cointally/domain/entities/transaction_entity.dart';
import 'package:cointally/domain/entities/category_entity.dart';
import 'package:cointally/presentation/notifiers/category_notifier.dart';
import 'package:cointally/presentation/notifiers/account_notifier.dart';
import 'package:cointally/presentation/widgets/sleek_components.dart';
import 'package:cointally/presentation/notifiers/currency_notifier.dart';
import 'package:cointally/presentation/notifiers/format_preferences_notifier.dart';
import 'package:cointally/core/utils/format_utils.dart';
import 'package:cointally/presentation/widgets/currency_selector.dart';
import 'package:cointally/presentation/notifiers/transaction_notifier.dart';
import 'package:cointally/presentation/screens/add_transaction_screen.dart';
import 'package:intl/intl.dart' hide TextDirection;

class CashflowOverviewCard extends ConsumerStatefulWidget {
  final List<TransactionEntity> transactions;

  const CashflowOverviewCard({super.key, required this.transactions});

  @override
  ConsumerState<CashflowOverviewCard> createState() => _CashflowOverviewCardState();
}

class _CashflowOverviewCardState extends ConsumerState<CashflowOverviewCard> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  
  CategoryEntity? _selectedExpenseCategory;
  CategoryEntity? _selectedIncomeCategory;

  String _selectedFilter = 'This Month';
  DateTime? _customStartDate;
  DateTime? _customEndDate;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  List<TransactionEntity> get _filteredTransactions {
    final now = DateTime.now();
    List<TransactionEntity> filtered = widget.transactions;

    if (_selectedFilter == 'This Month') {
      filtered = filtered.where((tx) => tx.date.month == now.month && tx.date.year == now.year).toList();
    } else if (_selectedFilter == 'Last 7 Days') {
      final weekAgo = now.subtract(const Duration(days: 7));
      final startOfDay = DateTime(weekAgo.year, weekAgo.month, weekAgo.day);
      filtered = filtered.where((tx) => tx.date.isAfter(startOfDay)).toList();
    } else if (_selectedFilter == 'Custom' && _customStartDate != null && _customEndDate != null) {
      final start = DateTime(_customStartDate!.year, _customStartDate!.month, _customStartDate!.day);
      final end = DateTime(_customEndDate!.year, _customEndDate!.month, _customEndDate!.day, 23, 59, 59);
      filtered = filtered.where((tx) => tx.date.isAfter(start.subtract(const Duration(seconds: 1))) && tx.date.isBefore(end.add(const Duration(seconds: 1)))).toList();
    }

    return filtered;
  }

  Map<CategoryEntity, double> _aggregateByCategory(String type, List<CategoryEntity> allCategories, CurrencyNotifier currencyNotifier) {
    final Map<CategoryEntity, double> totals = {};

    // Shared 'Debt' category for all debt-related transactions so they are
    // displayed as a single slice in the chart, not one per sub-type.
    final debtCategory = CategoryEntity(
      name: 'Debt',
      icon: Icons.people_alt_rounded,
      color: Colors.orange,
      type: 'EXPENSE',
    );
    
    final relevantTransactions = _filteredTransactions.where((t) => t.type == type).toList();
    
    for (var tx in relevantTransactions) {
      final isDebtCategory = tx.category.startsWith('Debt') ||
          tx.category == 'Debt: LEND' ||
          tx.category == 'Debt: BORROW';

      late CategoryEntity category;
      if (isDebtCategory) {
        // Always merge into a single 'Debt' bucket
        category = debtCategory;
      } else {
        // Find the matching category by name. HisaabMate uses Name for matching.
        category = allCategories.firstWhere(
          (c) => c.name == tx.category && c.type == type,
          orElse: () => CategoryEntity(name: tx.category, icon: Icons.help_outline, color: Colors.grey, type: type),
        );
      }

      totals[category] = (totals[category] ?? 0) + tx.amount.abs();
    }

    // Sort by amount descending
    final sortedEntries = totals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
      
    return Map.fromEntries(sortedEntries);
  }


  Widget _buildPagerIndicator(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(2, (index) {
        final isActive = _currentPage == index;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          margin: const EdgeInsets.symmetric(horizontal: 4),
          height: 6,
          width: isActive ? 24 : 6,
          decoration: BoxDecoration(
            color: isActive 
              ? Theme.of(context).colorScheme.primary 
              : Theme.of(context).colorScheme.primary.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(3),
          ),
        );
      }),
    );
  }

  // Returns the date range that matches the currently-active filter.
  ({DateTime start, DateTime end}) _getDateRangeForCurrentFilter() {
    final now = DateTime.now();
    if (_selectedFilter == 'This Month') {
      return (
        start: DateTime(now.year, now.month, 1),
        end: DateTime(now.year, now.month + 1, 0),
      );
    } else if (_selectedFilter == 'Last 7 Days') {
      final weekAgo = now.subtract(const Duration(days: 7));
      return (
        start: DateTime(weekAgo.year, weekAgo.month, weekAgo.day),
        end: now,
      );
    } else if (_selectedFilter == 'Custom' &&
        _customStartDate != null &&
        _customEndDate != null) {
      return (start: _customStartDate!, end: _customEndDate!);
    } else {
      // 'All Time' — use a very wide window
      return (start: DateTime(2000), end: now);
    }
  }

  void _showDrillDownSheet(
    BuildContext context,
    CategoryEntity category,
    double totalAmount,
    String type,
  ) {
    final dateRange = _getDateRangeForCurrentFilter();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useRootNavigator: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _CategoryDrillDownSheet(
        category: category,
        totalAmount: totalAmount,
        startDate: dateRange.start,
        endDate: dateRange.end,
        type: type,
      ),
    );
  }

  Widget _buildActiveSelectionCard(
    BuildContext context,
    CategoryEntity? selectedCategory,
    double amount,
    double total,
    String type,
  ) {
    if (selectedCategory == null || total == 0) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: Theme.of(context).textTheme.bodyMedium?.color?.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(16),
        ),
        alignment: Alignment.center,
        child: Text(
          'Tap a chart segment to view details',
          style: GoogleFonts.manrope(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: Theme.of(context).textTheme.bodyMedium?.color?.withValues(alpha: 0.5),
          ),
        ),
      );
    }

    final percentage = (amount / total) * 100;
    final formatPrefs = ref.watch(formatPreferencesProvider);
    final currencyState = ref.watch(currencyNotifierProvider);
    final symbol = CurrencySelector.currencies.firstWhere(
      (c) => c.code == currencyState.primaryCurrency,
      orElse: () => CurrencySelector.currencies.first,
    ).symbol;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _showDrillDownSheet(context, selectedCategory, amount, type),
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          decoration: BoxDecoration(
            color: Theme.of(context).cardTheme.color,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: selectedCategory.color.withValues(alpha: 0.3)),
            boxShadow: [
              BoxShadow(
                color: selectedCategory.color.withValues(alpha: 0.1),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: selectedCategory.color.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(selectedCategory.icon, color: selectedCategory.color, size: 20),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        selectedCategory.name,
                        style: GoogleFonts.manrope(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: Theme.of(context).textTheme.titleLarge?.color,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${percentage.toStringAsFixed(1)}% of total ${_currentPage == 0 ? 'expenses' : 'income'}',
                        style: GoogleFonts.manrope(
                          fontSize: 12,
                          color: Theme.of(context).textTheme.bodyMedium?.color?.withValues(alpha: 0.6),
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  FormatUtils.formatCurrency(amount, prefs: formatPrefs, symbol: symbol, forceDecimals: false),
                  style: GoogleFonts.manrope(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: selectedCategory.color,
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  Icons.chevron_right_rounded,
                  color: selectedCategory.color.withValues(alpha: 0.7),
                  size: 20,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDonutPage(String type, Map<CategoryEntity, double> dataMap, double total) {
    final isExpense = type == 'EXPENSE';
    final selectedCategory = isExpense ? _selectedExpenseCategory : _selectedIncomeCategory;
    final selectedAmount = selectedCategory != null ? (dataMap[selectedCategory] ?? 0.0) : 0.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Text(
                  isExpense ? 'Expenses ' : 'Income ',
                  style: GoogleFonts.manrope(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Theme.of(context).textTheme.titleLarge?.color,
                  ),
                ),
                Icon(
                  isExpense ? Icons.arrow_outward_rounded : Icons.south_west_rounded,
                  color: isExpense ? Colors.red : Theme.of(context).colorScheme.primary,
                  size: 20,
                ),
              ],
            ),
            _buildFilterDropdown(),
          ],
        ),
        const SizedBox(height: 24),
        if (total == 0 || dataMap.isEmpty)
          Expanded(
            child: Center(
              child: Text(
                'No $type data to display.',
                style: GoogleFonts.manrope(color: Theme.of(context).textTheme.bodyMedium?.color?.withValues(alpha: 0.4)),
              ),
            ),
          )
        else
          Expanded(
            child: Row(
              children: [
                // Left Side: Legend (Weight 1f)
                Expanded(
                  flex: 2,
                  child: ListView.builder(
                    physics: const BouncingScrollPhysics(),
                    itemCount: dataMap.length,
                    itemBuilder: (context, index) {
                      final category = dataMap.keys.elementAt(index);
                      final isSelected = selectedCategory == category;
                      
                      return GestureDetector(
                        onTap: () {
                          setState(() {
                            if (isExpense) {
                              _selectedExpenseCategory = isSelected ? null : category;
                            } else {
                              _selectedIncomeCategory = isSelected ? null : category;
                            }
                          });
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                          margin: const EdgeInsets.only(bottom: 4),
                          decoration: BoxDecoration(
                            color: isSelected ? category.color.withValues(alpha: 0.1) : Colors.transparent,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 12,
                                height: 12,
                                decoration: BoxDecoration(
                                  color: category.color,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  category.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.manrope(
                                    fontSize: 13,
                                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                                    color: isSelected ? category.color : Theme.of(context).textTheme.bodyMedium?.color,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
                // Right Side: Donut Chart (Weight 1.5f -> 3 flex)
                Expanded(
                  flex: 3,
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final size = math.min(constraints.maxWidth, constraints.maxHeight);
                      return Center(
                        child: SizedBox(
                          width: size,
                          height: size,
                          child: GestureDetector(
                            onTapUp: (details) {
                              final tapPosition = details.localPosition;
                              final centerX = size / 2;
                              final centerY = size / 2;
                              
                              // Distance formula: d = sqrt((x - centerX)^2 + (y - centerY)^2)
                              final dx = tapPosition.dx - centerX;
                              final dy = tapPosition.dy - centerY;
                              final distance = math.sqrt(dx * dx + dy * dy);
                              
                              final strokeWidth = size * 0.25;
                              final outerRadius = size / 2;
                              final innerRadius = outerRadius - strokeWidth;

                              // Only register if tap is ON the donut rim
                              if (distance >= innerRadius && distance <= outerRadius) {
                                // Calculate angle in radians
                                var touchAngle = math.atan2(dy, dx);
                                // Convert to range 0 .. 2pi (atan2 returns -pi to pi)
                                if (touchAngle < 0) {
                                  touchAngle += 2 * math.pi;
                                }

                                // Convert -pi/2 starting rotation of Canvas
                                touchAngle = (touchAngle + math.pi / 2) % (2 * math.pi);

                                // Find which segment was tapped
                                double currentAngle = 0;
                                CategoryEntity? tappedCategory;
                                
                                for (var entry in dataMap.entries) {
                                  final sweepAngle = (entry.value / total) * 2 * math.pi;
                                  if (touchAngle >= currentAngle && touchAngle <= currentAngle + sweepAngle) {
                                    tappedCategory = entry.key;
                                    break;
                                  }
                                  currentAngle += sweepAngle;
                                }

                                if (tappedCategory != null) {
                                  setState(() {
                                    if (isExpense) {
                                      _selectedExpenseCategory = tappedCategory;
                                    } else {
                                      _selectedIncomeCategory = tappedCategory;
                                    }
                                  });
                                }
                              } else {
                                // Clicked the center hole or outside
                                setState(() {
                                  if (isExpense) {
                                    _selectedExpenseCategory = null;
                                  } else {
                                    _selectedIncomeCategory = null;
                                  }
                                });
                              }
                            },
                            child: CustomPaint(
                              size: Size(size, size),
                              painter: DonutChartPainter(
                                dataMap: dataMap,
                                total: total,
                                selectedCategory: selectedCategory,
                                strokeWidth: size * 0.25,
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        
        const SizedBox(height: 16),
        _buildActiveSelectionCard(context, selectedCategory, selectedAmount, total, type),
      ],
    );
  }

  Widget _buildFilterDropdown() {
    String displayLabel = _selectedFilter;
    if (_selectedFilter == 'Custom' && _customStartDate != null && _customEndDate != null) {
      final startStr = DateFormat('MMM d').format(_customStartDate!);
      final endStr = DateFormat('MMM d').format(_customEndDate!);
      displayLabel = '$startStr - $endStr';
    }

    return PopupMenuButton<String>(
      onSelected: (value) async {
        if (value == 'Custom') {
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
            setState(() {
              _selectedFilter = 'Custom';
              _customStartDate = picked.start;
              _customEndDate = picked.end;
            });
          }
        } else {
          setState(() {
            _selectedFilter = value;
            _customStartDate = null;
            _customEndDate = null;
          });
        }
      },
      itemBuilder: (context) => [
        'All Time',
        'This Month',
        'Last 7 Days',
        'Custom'
      ].map((String choice) {
        return PopupMenuItem<String>(
          value: choice,
          child: Text(
            choice,
            style: GoogleFonts.manrope(
              fontWeight: _selectedFilter == choice ? FontWeight.bold : FontWeight.normal,
              color: _selectedFilter == choice ? Theme.of(context).colorScheme.primary : Theme.of(context).textTheme.bodyLarge?.color,
            ),
          ),
        );
      }).toList(),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: Theme.of(context).textTheme.bodyMedium?.color?.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              displayLabel,
              style: GoogleFonts.manrope(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).textTheme.bodyMedium?.color?.withValues(alpha: 0.7),
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.keyboard_arrow_down_rounded,
              size: 16,
              color: Theme.of(context).textTheme.bodyMedium?.color?.withValues(alpha: 0.7),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.transactions.isEmpty) {
      return const SizedBox.shrink(); // Don't show anything if no transactions exist
    }

    final categoryState = ref.watch(categoryProvider);
    final currencyNotifier = ref.read(currencyNotifierProvider.notifier);

    final expenseMap = _aggregateByCategory('EXPENSE', categoryState.categories, currencyNotifier);
    final incomeMap = _aggregateByCategory('INCOME', categoryState.categories, currencyNotifier);

    final totalExpenses = expenseMap.values.fold(0.0, (sum, val) => sum + val);
    final totalIncome = incomeMap.values.fold(0.0, (sum, val) => sum + val);

    return PremiumCard(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 380, // Fixed height for pager
            child: PageView(
              controller: _pageController,
              onPageChanged: (idx) {
                setState(() => _currentPage = idx);
              },
              children: [
                _buildDonutPage('EXPENSE', expenseMap, totalExpenses),
                _buildDonutPage('INCOME', incomeMap, totalIncome),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _buildPagerIndicator(context),
        ],
      ),
    );
  }
}

class DonutChartPainter extends CustomPainter {
  final Map<CategoryEntity, double> dataMap;
  final double total;
  final CategoryEntity? selectedCategory;
  final double strokeWidth;

  DonutChartPainter({
    required this.dataMap,
    required this.total,
    this.selectedCategory,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (total == 0) return;

    final rect = Rect.fromLTWH(
      strokeWidth / 2, 
      strokeWidth / 2, 
      size.width - strokeWidth, 
      size.height - strokeWidth
    );
    
    double startAngle = -math.pi / 2; // Start from top
    double gapAngle = 0.05; // Gap between segments

    for (var entry in dataMap.entries) {
      final category = entry.key;
      final sweepAngle = (entry.value / total) * (2 * math.pi);
      
      final isSelected = selectedCategory == null || selectedCategory == category;
      
      final paint = Paint()
        ..color = isSelected ? category.color : category.color.withValues(alpha: 0.3)
        ..style = PaintingStyle.stroke
        ..strokeWidth = isSelected ? strokeWidth : strokeWidth * 0.85
        ..strokeCap = StrokeCap.round;

      // Draw the arc segment
      // Use math.max to ensure there's a visible arc even with gap
      final actualSweep = math.max(0.01, sweepAngle - gapAngle);
      canvas.drawArc(rect, startAngle + (gapAngle / 2), actualSweep, false, paint);

      // Task 3: Trigonometry for Overlaid Icons
      // Only draw icon if the slice is large enough, or if it's the only one
      if (sweepAngle > 0.15 || dataMap.length == 1) {
        final double midAngle = startAngle + (sweepAngle / 2);
        final double radius = (size.width - strokeWidth) / 2;
        
        // Calculate center point of the stroke arc
        final double centerX = (size.width / 2) + radius * math.cos(midAngle);
        final double centerY = (size.height / 2) + radius * math.sin(midAngle);

        // Draw Icon Background Circle
        final bgPaint = Paint()..color = Colors.white.withValues(alpha: isSelected ? 0.9 : 0.4);
        canvas.drawCircle(Offset(centerX, centerY), strokeWidth * 0.35, bgPaint);

        // Draw the Icon using TextPainter
        final iconStr = String.fromCharCode(category.icon.codePoint);
        final textPainter = TextPainter(
          text: TextSpan(
            text: iconStr,
            style: TextStyle(
              fontSize: strokeWidth * 0.45,
              fontFamily: category.icon.fontFamily,
              color: category.color,
            ),
          ),
          textDirection: TextDirection.ltr,
        );
        
        textPainter.layout();
        // Center the icon strictly over the calculated point
        textPainter.paint(
          canvas, 
          Offset(centerX - (textPainter.width / 2), centerY - (textPainter.height / 2))
        );
      }

      startAngle += sweepAngle;
    }
  }

  @override
  bool shouldRepaint(DonutChartPainter oldDelegate) {
    return oldDelegate.selectedCategory != selectedCategory || 
           oldDelegate.dataMap != dataMap || 
           oldDelegate.total != total;
  }
}

// ---------------------------------------------------------------------------
// Drill-Down Bottom Sheet
// ---------------------------------------------------------------------------

class _CategoryDrillDownSheet extends ConsumerWidget {
  final CategoryEntity category;
  final double totalAmount;
  final DateTime startDate;
  final DateTime endDate;
  final String type;

  const _CategoryDrillDownSheet({
    required this.category,
    required this.totalAmount,
    required this.startDate,
    required this.endDate,
    required this.type,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.read(transactionRepositoryProvider);
    final formatPrefs = ref.watch(formatPreferencesProvider);
    final currencyState = ref.watch(currencyNotifierProvider);
    final symbol = CurrencySelector.currencies
        .firstWhere(
          (c) => c.code == currencyState.primaryCurrency,
          orElse: () => CurrencySelector.currencies.first,
        )
        .symbol;

    final bottomPadding = MediaQuery.of(context).viewPadding.bottom;
    final sheetHeight = MediaQuery.of(context).size.height * 0.72;

    return Container(
      height: sheetHeight + bottomPadding,
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Drag handle
          Padding(
            padding: const EdgeInsets.only(top: 12, bottom: 8),
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Theme.of(context).textTheme.bodyMedium?.color?.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: category.color.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(category.icon, color: category.color, size: 22),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        category.name,
                        style: GoogleFonts.manrope(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: Theme.of(context).textTheme.titleLarge?.color,
                        ),
                      ),
                      Text(
                        'Transactions breakdown',
                        style: GoogleFonts.manrope(
                          fontSize: 12,
                          color: Theme.of(context).textTheme.bodyMedium?.color?.withValues(alpha: 0.5),
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  FormatUtils.formatCurrency(
                    totalAmount,
                    prefs: formatPrefs,
                    symbol: symbol,
                    forceDecimals: false,
                  ),
                  style: GoogleFonts.manrope(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: category.color,
                  ),
                ),
              ],
            ),
          ),
          Divider(
            height: 1,
            color: Theme.of(context).textTheme.bodyMedium?.color?.withValues(alpha: 0.08),
          ),
          // Body — transaction list
          Expanded(
            child: FutureBuilder<List<TransactionEntity>>(
              future: repo.getTransactionsByCategoryAndDateRange(
                category.name,
                startDate,
                endDate,
              ),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(
                    child: Text(
                      'Error loading transactions',
                      style: GoogleFonts.manrope(
                        color: Theme.of(context).textTheme.bodyMedium?.color?.withValues(alpha: 0.4),
                      ),
                    ),
                  );
                }
                final transactions = snapshot.data ?? [];
                if (transactions.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.receipt_long_rounded,
                          size: 48,
                          color: Theme.of(context).textTheme.bodyMedium?.color?.withValues(alpha: 0.15),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'No transactions found',
                          style: GoogleFonts.manrope(
                            fontWeight: FontWeight.w600,
                            color: Theme.of(context).textTheme.bodyMedium?.color?.withValues(alpha: 0.4),
                          ),
                        ),
                      ],
                    ),
                  );
                }
                return ListView.builder(
                  padding: EdgeInsets.fromLTRB(20, 12, 20, 12 + bottomPadding),
                  itemCount: transactions.length,
                  itemBuilder: (context, index) {
                    return _DrillDownTransactionTile(
                      tx: transactions[index],
                      formatPrefs: formatPrefs,
                      symbol: symbol,
                      categoryColor: category.color,
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Individual Transaction Tile (mirrors transaction_history_screen.dart style)
// ---------------------------------------------------------------------------

class _DrillDownTransactionTile extends ConsumerWidget {
  final TransactionEntity tx;
  final FormatPreferencesState formatPrefs;
  final String symbol;
  final Color categoryColor;

  const _DrillDownTransactionTile({
    required this.tx,
    required this.formatPrefs,
    required this.symbol,
    required this.categoryColor,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final allCategories = ref.watch(categoryProvider).categories;
    final allAccounts = ref.watch(accountProvider).accounts;

    final cat = allCategories.firstWhere(
      (c) => c.name == tx.category,
      orElse: () => CategoryEntity(
        name: tx.category,
        icon: Icons.receipt_long_rounded,
        color: categoryColor,
        type: tx.type,
      ),
    );

    final account = allAccounts.where((a) => a.id == tx.accountId).firstOrNull;
    final accountName = account?.bankName ?? 'Wallet';
    final txCurrencyCode = account?.currencyCode ?? 'PKR';
    final txSymbol = CurrencySelector.currencies
        .firstWhere(
          (c) => c.code == txCurrencyCode,
          orElse: () => CurrencySelector.currencies.first,
        )
        .symbol;

    final isExpense = tx.type == 'EXPENSE';

    return InkWell(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => AddTransactionScreen(transaction: tx),
        ),
      ),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).cardTheme.color,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.color
                    ?.withValues(alpha: 0.05) ??
                Colors.white.withValues(alpha: 0.02),
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: cat.color.withValues(alpha: 0.08),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: cat.color.withValues(alpha: 0.08),
                    blurRadius: 10,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: Icon(cat.icon, color: cat.color, size: 20),
            ),
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
                    '$accountName · ${DateFormat('MMM d, yyyy').format(tx.date)}',
                    style: GoogleFonts.manrope(
                      fontSize: 11,
                      color: Theme.of(context)
                          .textTheme
                          .bodyMedium
                          ?.color
                          ?.withValues(alpha: 0.35),
                    ),
                  ),
                ],
              ),
            ),
            Text(
              '${isExpense ? '-' : '+'}${FormatUtils.formatCurrency(tx.amount, prefs: formatPrefs, symbol: txSymbol, forceDecimals: false)}',
              style: GoogleFonts.manrope(
                fontWeight: FontWeight.w800,
                color: isExpense
                    ? Theme.of(context).textTheme.bodyLarge?.color
                    : Theme.of(context).colorScheme.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
