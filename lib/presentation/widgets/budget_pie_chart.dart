import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cointally/domain/entities/budget_progress.dart';
import 'package:cointally/domain/entities/category_entity.dart';
import 'package:cointally/presentation/notifiers/category_notifier.dart';

class BudgetPieChart extends ConsumerStatefulWidget {
  final List<BudgetProgress> progressList;

  const BudgetPieChart({super.key, required this.progressList});

  @override
  ConsumerState<BudgetPieChart> createState() => _BudgetPieChartState();
}

class _BudgetPieChartState extends ConsumerState<BudgetPieChart> {
  int touchedIndex = -1;

  @override
  Widget build(BuildContext context) {
    if (widget.progressList.isEmpty || widget.progressList.every((p) => p.amountSpent == 0)) {
      return const SizedBox.shrink();
    }

    final categoryState = ref.watch(categoryProvider);
    final categories = categoryState.categories;

    return AspectRatio(
      aspectRatio: 1.5,
      child: Stack(
        alignment: Alignment.center,
        children: [
          PieChart(
            PieChartData(
              pieTouchData: PieTouchData(
                touchCallback: (FlTouchEvent event, pieTouchResponse) {
                  setState(() {
                    if (!event.isInterestedForInteractions ||
                        pieTouchResponse == null ||
                        pieTouchResponse.touchedSection == null) {
                      touchedIndex = -1;
                      return;
                    }
                    touchedIndex = pieTouchResponse.touchedSection!.touchedSectionIndex;
                  });
                },
              ),
              sectionsSpace: 4,
              centerSpaceRadius: 60,
              sections: _getSections(categories),
            ),
          ),
          if (touchedIndex != -1 && touchedIndex < widget.progressList.length)
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  widget.progressList[touchedIndex].budget.category,
                  style: GoogleFonts.manrope(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Theme.of(context).textTheme.bodyLarge?.color,
                  ),
                ),
                Text(
                  'Rs. ${widget.progressList[touchedIndex].amountSpent.toStringAsFixed(0)}',
                  style: GoogleFonts.manrope(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: _getCategoryColor(widget.progressList[touchedIndex].budget.category, categories),
                  ),
                ),
              ],
            )
          else
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Spent',
                  style: GoogleFonts.manrope(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.4),
                  ),
                ),
                Text(
                  'Rs. ${widget.progressList.fold(0.0, (sum, p) => sum + p.amountSpent).toStringAsFixed(0)}',
                  style: GoogleFonts.manrope(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: Theme.of(context).textTheme.bodyLarge?.color,
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  List<PieChartSectionData> _getSections(List<CategoryEntity> categories) {
    return List.generate(widget.progressList.length, (i) {
      final isTouched = i == touchedIndex;
      final radius = isTouched ? 30.0 : 20.0;
      final progress = widget.progressList[i];
      
      final categoryColor = _getCategoryColor(progress.budget.category, categories);

      return PieChartSectionData(
        color: categoryColor,
        value: progress.amountSpent,
        title: '',
        radius: radius,
        badgeWidget: progress.isOverBudget 
            ? Icon(Icons.warning_rounded, size: isTouched ? 16 : 12, color: Colors.white) 
            : null,
        badgePositionPercentageOffset: 1.3,
      );
    });
  }

  Color _getCategoryColor(String categoryName, List<CategoryEntity> categories) {
    return categories
        .where((c) => c.name.toLowerCase() == categoryName.toLowerCase())
        .firstOrNull?.color ?? Theme.of(context).colorScheme.primary;
  }
}
