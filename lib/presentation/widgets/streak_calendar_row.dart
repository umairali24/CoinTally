import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cointally/presentation/notifiers/streak_notifier.dart';

class StreakCalendarRow extends StatelessWidget {
  final List<DayStreakInfo> history;

  const StreakCalendarRow({super.key, required this.history});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: history.map((day) => Expanded(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4.0),
          child: StreakTile(day: day),
        ),
      )).toList(),
    );
  }
}

class StreakTile extends StatelessWidget {
  final DayStreakInfo day;

  const StreakTile({super.key, required this.day});

  @override
  Widget build(BuildContext context) {
    final isToday = DateFormat('yyyy-MM-dd').format(DateTime.now()) == 
                    DateFormat('yyyy-MM-dd').format(day.date);
    final dayName = DateFormat('E').format(day.date).substring(0, 3);
    final dateNum = DateFormat('d').format(day.date);

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isToday 
              ? Theme.of(context).colorScheme.primary 
              : Colors.transparent,
          width: 2,
        ),
        boxShadow: isToday ? [
          BoxShadow(
            color: Theme.of(context).colorScheme.primary.withOpacity(0.2),
            blurRadius: 8,
            offset: const Offset(0, 2),
          )
        ] : null,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            dayName,
            style: GoogleFonts.manrope(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.5),
            ),
          ),
          const SizedBox(height: 8),
          _buildCoinGraphic(context),
          const SizedBox(height: 8),
          Text(
            dateNum,
            style: GoogleFonts.manrope(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: isToday 
                  ? Theme.of(context).colorScheme.primary 
                  : Theme.of(context).textTheme.bodyLarge?.color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCoinGraphic(BuildContext context) {
    if (day.isFrozen) {
      return Image.asset(
        'assets/streak_icon/streak_freeze.png',
        width: 32,
        height: 32,
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) => const Icon(
          Icons.ac_unit_rounded,
          color: Color(0xFF87CEEB), // Blue Snowflake
          size: 20,
        ),
      );
    }

    if (!day.isActive) {
      final isToday = DateFormat('yyyy-MM-dd').format(DateTime.now()) == 
                      DateFormat('yyyy-MM-dd').format(day.date);
      if (!isToday) {
        return Image.asset(
          'assets/streak_icon/streak_broken.png',
          width: 32,
          height: 32,
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) => Icon(
            Icons.cancel_outlined,
            color: Colors.red.withOpacity(0.5),
            size: 20,
          ),
        );
      }
      return Icon(
        Icons.circle_outlined,
        color: Colors.grey.withOpacity(0.3), // Gray Outlined Circle
        size: 20,
      );
    }

    final count = day.streakCount;
    if (count >= 7) {
      // Tier 3 (7+ Days): Large Stack
      return Image.asset(
        'assets/streak_icon/streak_7+.png',
        width: 48,
        height: 48,
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) => const Icon(Icons.error, color: Colors.red),
      );
    } else if (count >= 4) {
      // Tier 2 (4-6 Days): Small Stack
      return Image.asset(
        'assets/streak_icon/streak_2+.png',
        width: 36,
        height: 36,
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) => const Icon(Icons.error, color: Colors.orange),
      );
    } else {
      // Tier 1 (1-3 Days): Single Coin
      return Image.asset(
        'assets/streak_icon/streak_coin.png',
        width: 32,
        height: 32,
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) => const Icon(Icons.error, color: Colors.yellow),
      );
    }
  }
}
