import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:cointally/domain/entities/transaction_entity.dart';
import 'package:cointally/presentation/widgets/sleek_components.dart';
import 'package:intl/intl.dart' hide TextDirection;

class GrowthChartCard extends StatefulWidget {
  final double currentBalance;
  final List<TransactionEntity> transactions;
  final bool isPortfolio;
  final int? accountId;

  const GrowthChartCard({
    super.key,
    required this.currentBalance,
    required this.transactions,
    this.isPortfolio = false,
    this.accountId,
  });

  @override
  State<GrowthChartCard> createState() => _GrowthChartCardState();
}

class _GrowthChartCardState extends State<GrowthChartCard> {
  String _selectedFilter = 'This Month';
  DateTime? _customStartDate;
  DateTime? _customEndDate;

  // Represents a single point in time and balance
  List<FlSpot> _chartData = [];
  DateTime? _chartStartDate; // Storing this to calculate axes labels properly
  double _minY = 0;
  double _maxY = 0;
  double _growthPercentage = 0;
  bool _isPositiveGrowth = true;

  @override
  void initState() {
    super.initState();
    _calculateChartData();
  }

  @override
  void didUpdateWidget(covariant GrowthChartCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentBalance != widget.currentBalance ||
        oldWidget.transactions.length != widget.transactions.length ||
        oldWidget.isPortfolio != widget.isPortfolio ||
        oldWidget.accountId != widget.accountId) {
      _calculateChartData();
    }
  }

  void _calculateChartData() {
    final now = DateTime.now();
    DateTime startDate;
    DateTime endDate = now;

    if (_selectedFilter == 'This Month') {
      startDate = DateTime(now.year, now.month, 1);
    } else if (_selectedFilter == 'Last 7 Days') {
      startDate = now.subtract(const Duration(days: 7));
      startDate = DateTime(startDate.year, startDate.month, startDate.day);
    } else if (_selectedFilter == 'Custom' && _customStartDate != null && _customEndDate != null) {
      startDate = DateTime(_customStartDate!.year, _customStartDate!.month, _customStartDate!.day);
      endDate = DateTime(_customEndDate!.year, _customEndDate!.month, _customEndDate!.day, 23, 59, 59);
    } else {
      // All Time
      if (widget.transactions.isEmpty) {
        startDate = now.subtract(const Duration(days: 30));
      } else {
        DateTime earliest = widget.transactions.first.date;
        for (var tx in widget.transactions) {
          if (tx.date.isBefore(earliest)) earliest = tx.date;
        }
        startDate = DateTime(earliest.year, earliest.month, earliest.day);
      }
    }

    int daysDiff = endDate.difference(startDate).inDays;
    if (daysDiff <= 0) {
      startDate = endDate.subtract(const Duration(days: 1)); 
    }

    // Filter transactions up to endDate, sorted chronologically backwards (newest first)
    final sortedTxs = List<TransactionEntity>.from(widget.transactions)
      ..sort((a, b) => b.date.compareTo(a.date));

    double runningBalance = widget.currentBalance;

    // Fast-forward runningBalance to exactly endDate by reversing anything that happened after it
    final txsAfterEnd = sortedTxs.where((tx) => tx.date.isAfter(endDate)).toList();
    for (var tx in txsAfterEnd) {
      runningBalance = _reverseTransactionEffect(runningBalance, tx);
    }

    Map<DateTime, double> dailyBalances = {};
    DateTime currentDay = DateTime(endDate.year, endDate.month, endDate.day);
    dailyBalances[currentDay] = runningBalance;

    final txsInWindow = sortedTxs.where((tx) => !tx.date.isAfter(endDate)).toList();
    int txIndex = 0;
    
    DateTime startDay = DateTime(startDate.year, startDate.month, startDate.day);
    
    // Step backwards day by day to build historical balances
    while (!currentDay.isBefore(startDay)) {
      while (txIndex < txsInWindow.length) {
        final tx = txsInWindow[txIndex];
        DateTime txDay = DateTime(tx.date.year, tx.date.month, tx.date.day);
        
        if (txDay.isAfter(currentDay)) {
          txIndex++; // Skip transactions we somehow missed
        } else if (txDay.isAtSameMomentAs(currentDay)) {
          runningBalance = _reverseTransactionEffect(runningBalance, tx);
          txIndex++;
        } else {
          break; // These belong to earlier days
        }
      }
      
      currentDay = currentDay.subtract(const Duration(days: 1));
      if (!currentDay.isBefore(startDay)) {
         dailyBalances[currentDay] = runningBalance;
      }
    }

    final sortedDays = dailyBalances.keys.toList()..sort();

    _chartData = [];
    double minBal = double.infinity;
    double maxBal = double.negativeInfinity;

    for (var i = 0; i < sortedDays.length; i++) {
        final day = sortedDays[i];
        final val = dailyBalances[day]!;
        if (val < minBal) minBal = val;
        if (val > maxBal) maxBal = val;

        double x = day.difference(startDate).inDays.toDouble();
        _chartData.add(FlSpot(x, val));
    }
    
    // Safety padding for visual spacing
    if (minBal == double.infinity) minBal = 0;
    if (maxBal == double.negativeInfinity) maxBal = 100;
    
    double yPadding = (maxBal - minBal) * 0.1;
    if (yPadding == 0) yPadding = 10;
    
    setState(() {
      _chartStartDate = startDate;
      _minY = minBal - yPadding;
      _maxY = maxBal + yPadding;
      
      if (sortedDays.isNotEmpty) {
        final startBalance = dailyBalances[sortedDays.first]!;
        final endBalance = dailyBalances[sortedDays.last]!;
        
        if (startBalance == 0) {
          _growthPercentage = endBalance > 0 ? 100 : 0;
        } else {
          _growthPercentage = ((endBalance - startBalance) / startBalance.abs()) * 100;
        }
        _isPositiveGrowth = _growthPercentage >= 0;
      }
    });
  }

  double _reverseTransactionEffect(double balance, TransactionEntity tx) {
    if (widget.isPortfolio && tx.type == 'TRANSFER') {
      return balance; // General portfolio sees no net change from internal transfers
    }

    if (tx.type == 'INCOME') {
      return balance - tx.amount; 
    } else if (tx.type == 'EXPENSE') {
      return balance + tx.amount; 
    } else if (tx.type == 'TRANSFER') {
      if (!widget.isPortfolio && widget.accountId != null) {
        if (tx.accountId == widget.accountId) {
          // It was a transfer OUT. This means it reduced the balance.
          return balance + tx.amount; 
        } else if (tx.toAccountId == widget.accountId) {
          // It was a transfer IN. This means it increased the balance.
          return balance - tx.amount; 
        }
      }
      return balance; // Ignore transfer impact if we can't be sure
    } else if (tx.type == 'ADJUSTMENT') {
        return balance - tx.amount; 
    }
    return balance;
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
              _calculateChartData();
            });
          }
        } else {
          setState(() {
            _selectedFilter = value;
            _customStartDate = null;
            _customEndDate = null;
            _calculateChartData();
          });
        }
      },
      itemBuilder: (context) => [
        'This Month',
        'Last 7 Days',
        'All Time',
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
    if (_chartData.isEmpty || _chartData.length < 2) {
      return PremiumCard(
         padding: const EdgeInsets.all(24),
         child: Column(
           crossAxisAlignment: CrossAxisAlignment.start,
           children: [
             Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Growth',
                    style: GoogleFonts.manrope(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: Theme.of(context).textTheme.titleLarge?.color,
                    ),
                  ),
                  _buildFilterDropdown(),
                ],
              ),
              const SizedBox(height: 32),
              Center(
                child: Text(
                  'Not enough data to graph yet.',
                  style: GoogleFonts.manrope(
                    color: Theme.of(context).textTheme.bodyMedium?.color?.withValues(alpha: 0.4),
                  ),
                ),
              ),
           ],
         ),
      );
    }

    final lineColor = _isPositiveGrowth ? Theme.of(context).colorScheme.primary : Colors.redAccent;
    final gradientColors = [
      lineColor.withValues(alpha: 0.5),
      lineColor.withValues(alpha: 0.0),
    ];

    return PremiumCard(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Growth',
                    style: GoogleFonts.manrope(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: Theme.of(context).textTheme.titleLarge?.color,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(
                        _isPositiveGrowth ? Icons.trending_up_rounded : Icons.trending_down_rounded,
                        color: lineColor,
                        size: 16,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${_isPositiveGrowth ? '+' : ''}${_growthPercentage.toStringAsFixed(1)}%',
                        style: GoogleFonts.manrope(
                          fontWeight: FontWeight.bold,
                          color: lineColor,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              _buildFilterDropdown(),
            ],
          ),
          const SizedBox(height: 32),
          SizedBox(
            height: 200,
            child: LineChart(
              LineChartData(
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: (_maxY - _minY) / 4 > 0 ? (_maxY - _minY) / 4 : 1,
                  getDrawingHorizontalLine: (value) {
                    return FlLine(
                      color: Theme.of(context).textTheme.bodyMedium?.color?.withValues(alpha: 0.05),
                      strokeWidth: 1,
                    );
                  },
                ),
                titlesData: FlTitlesData(
                  show: true,
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 30,
                      interval: _chartData.isNotEmpty && _chartData.last.x > 0 
                          ? math.max(1, (_chartData.last.x / 4).roundToDouble()) 
                          : 1,
                      getTitlesWidget: (value, meta) {
                        if (value == meta.max || value == meta.min) {
                          return const SizedBox.shrink(); // Don't crowd the edges
                        }
                        
                        // X axis is days since _selectedFilter startDate
                        if (_chartStartDate == null || _chartData.isEmpty) return const SizedBox.shrink();
                        
                        DateTime labelDate = _chartStartDate!.add(Duration(days: value.toInt()));
                        String dateStr = DateFormat('MMM d').format(labelDate);
                        
                        return Padding(
                          padding: const EdgeInsets.only(top: 8.0),
                          child: Text(
                            dateStr,
                            style: GoogleFonts.manrope(
                              color: Theme.of(context).textTheme.bodyMedium?.color?.withValues(alpha: 0.5),
                              fontSize: 10,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 40,
                      getTitlesWidget: (value, meta) {
                        if (value == meta.max || value == meta.min) {
                          return const SizedBox.shrink();
                        }
                        return Padding(
                          padding: const EdgeInsets.only(right: 8.0),
                          child: Text(
                            NumberFormat.compact().format(value),
                            style: GoogleFonts.manrope(
                              color: Theme.of(context).textTheme.bodyMedium?.color?.withValues(alpha: 0.5),
                              fontSize: 10,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                borderData: FlBorderData(show: false),
                minX: 0,
                maxX: _chartData.last.x,
                minY: _minY,
                maxY: _maxY,
                lineBarsData: [
                  LineChartBarData(
                    spots: _chartData,
                    isCurved: true,
                    preventCurveOverShooting: true,
                    curveSmoothness: 0.20,
                    color: lineColor,
                    barWidth: 3,
                    isStrokeCapRound: true,
                    dotData: const FlDotData(show: false),
                    belowBarData: BarAreaData(
                      show: true,
                      gradient: LinearGradient(
                        colors: gradientColors,
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                  ),
                ],
                lineTouchData: LineTouchData(
                  touchTooltipData: LineTouchTooltipData(
                    getTooltipColor: (_) => Theme.of(context).cardColor,
                    getTooltipItems: (List<LineBarSpot> touchedSpots) {
                      return touchedSpots.map((barSpot) {
                        return LineTooltipItem(
                          barSpot.y.toStringAsFixed(0),
                          GoogleFonts.manrope(
                            color: Theme.of(context).textTheme.bodyLarge?.color,
                            fontWeight: FontWeight.bold,
                          ),
                        );
                      }).toList();
                    },
                  ),
                  handleBuiltInTouches: true,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}


