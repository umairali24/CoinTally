import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cointally/domain/repository/preference_repository.dart';
import 'package:cointally/presentation/notifiers/currency_notifier.dart'; // To get preferenceRepositoryProvider
import 'package:intl/intl.dart';

class StreakState {
  final int currentStreak;
  final int longestStreak;
  final int availableFreezes;
  final String? lastActiveDate;
  final List<String> activeDates;
  final List<String> frozenDates;

  StreakState({
    required this.currentStreak,
    required this.longestStreak,
    required this.availableFreezes,
    this.lastActiveDate,
    this.activeDates = const [],
    this.frozenDates = const [],
  });

  StreakState copyWith({
    int? currentStreak,
    int? longestStreak,
    int? availableFreezes,
    String? lastActiveDate,
    List<String>? activeDates,
    List<String>? frozenDates,
  }) {
    return StreakState(
      currentStreak: currentStreak ?? this.currentStreak,
      longestStreak: longestStreak ?? this.longestStreak,
      availableFreezes: availableFreezes ?? this.availableFreezes,
      lastActiveDate: lastActiveDate ?? this.lastActiveDate,
      activeDates: activeDates ?? this.activeDates,
      frozenDates: frozenDates ?? this.frozenDates,
    );
  }
}

class StreakNotifier extends StateNotifier<StreakState> {
  final PreferenceRepository _prefRepo;

  StreakNotifier(this._prefRepo)
      : super(StreakState(currentStreak: 0, longestStreak: 0, availableFreezes: 1)) {
    _loadStreakData();
  }

  Future<void> _loadStreakData() async {
    final current = await _prefRepo.getCurrentStreak();
    final longest = await _prefRepo.getLongestStreak();
    final freezes = await _prefRepo.getAvailableFreezes();
    final lastActive = await _prefRepo.getLastActiveDate();
    final activeDates = await _prefRepo.getActiveDates();
    final frozenDates = await _prefRepo.getFrozenDates();

    state = StreakState(
      currentStreak: current,
      longestStreak: longest,
      availableFreezes: freezes,
      lastActiveDate: lastActive,
      activeDates: activeDates,
      frozenDates: frozenDates,
    );
  }

  Future<void> incrementStreakSafely() async {
    final now = DateTime.now();
    final dateFormat = DateFormat('yyyy-MM-dd');
    final todayStr = dateFormat.format(now);
    
    // 1. If today is already marked as active, do nothing
    if (state.lastActiveDate == todayStr) {
      return;
    }

    final yesterday = now.subtract(const Duration(days: 1));
    final yesterdayStr = dateFormat.format(yesterday);
    
    final dayBeforeYesterday = now.subtract(const Duration(days: 2));
    final dayBeforeYesterdayStr = dateFormat.format(dayBeforeYesterday);

    int newStreak = state.currentStreak;
    int newFreezes = state.availableFreezes;
    List<String> newActiveDates = List.from(state.activeDates);
    List<String> newFrozenDates = List.from(state.frozenDates);

    if (state.lastActiveDate == yesterdayStr) {
      // 2. Continuous streak
      newStreak += 1;
    } else if (state.lastActiveDate == dayBeforeYesterdayStr) {
      // 3. Missed exactly 1 day
      if (state.availableFreezes > 0) {
        // Use freeze
        newFreezes -= 1;
        newStreak += 1;
        newFrozenDates.add(yesterdayStr);
      } else {
        // Reset streak
        newStreak = 1;
      }
    } else {
      // 4. Older than day before yesterday or no last active date
      newStreak = 1;
    }

    // Add today to active dates
    newActiveDates.add(todayStr);

    // Keep only last 30 days to save space
    if (newActiveDates.length > 30) newActiveDates.removeAt(0);
    if (newFrozenDates.length > 30) newFrozenDates.removeAt(0);

    // Update longest streak
    int newLongest = state.longestStreak;
    if (newStreak > newLongest) {
      newLongest = newStreak;
    }

    // Save and update state
    await _prefRepo.setCurrentStreak(newStreak);
    await _prefRepo.setLongestStreak(newLongest);
    await _prefRepo.setAvailableFreezes(newFreezes);
    await _prefRepo.setLastActiveDate(todayStr);
    await _prefRepo.setActiveDates(newActiveDates);
    await _prefRepo.setFrozenDates(newFrozenDates);

    state = state.copyWith(
      currentStreak: newStreak,
      longestStreak: newLongest,
      availableFreezes: newFreezes,
      lastActiveDate: todayStr,
      activeDates: newActiveDates,
      frozenDates: newFrozenDates,
    );
  }
  
  // Method to manually mark active (e.g. for "No Spend Day" button)
  Future<void> markNoSpendDay() async {
    await incrementStreakSafely();
  }

  List<DayStreakInfo> getWeeklyHistory() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final dateFormat = DateFormat('yyyy-MM-dd');
    List<DayStreakInfo> history = [];
    
    // Fallback logic for users who already have a streak but no historical data saved yet
    final int currentStreakCount = state.currentStreak;
    final DateTime? lastActive = state.lastActiveDate != null ? dateFormat.parse(state.lastActiveDate!) : null;

    for (int i = 6; i >= 0; i--) {
      // Normalize to midnight
      final date = today.subtract(Duration(days: i));
      final dateStr = dateFormat.format(date);
      
      bool isActive = state.activeDates.contains(dateStr);
      bool isFrozen = state.frozenDates.contains(dateStr);
      
      // Fallback: If we don't have explicit historical dates, but we know the user has a streak
      // and their last active date is recent enough, we can safely assume they were active
      if (!isActive && !isFrozen && currentStreakCount > 0 && lastActive != null) {
        // Did they miss a day?
        final daysSinceLastActive = today.difference(lastActive).inDays;
        
        // If the date in question is within the continuous streak period before the last active date
        // Note: this is a heuristic. If they used freezes historically, this might not be 100% accurate,
        // but it's much better than showing empty circles for a 15-day streak.
        final daysBetweenDateAndLastActive = lastActive.difference(date).inDays;
        
        if (daysSinceLastActive <= 1) { // They are active today or yesterday
          if (daysBetweenDateAndLastActive >= 0 && daysBetweenDateAndLastActive < currentStreakCount) {
             isActive = true;
          }
        }
      }

      int countForDay = 0;
      if (isActive || isFrozen) {
        if (lastActive != null) {
          final daysBetweenDateAndLastActive = lastActive.difference(date).inDays;
          if (daysBetweenDateAndLastActive >= 0 && daysBetweenDateAndLastActive < currentStreakCount) {
             countForDay = currentStreakCount - daysBetweenDateAndLastActive;
          } else {
             countForDay = 1; 
             DateTime tempDate = date.subtract(const Duration(days: 1));
             while (true) {
                final tempStr = dateFormat.format(tempDate);
                if (state.activeDates.contains(tempStr) || state.frozenDates.contains(tempStr)) {
                   countForDay++;
                   tempDate = tempDate.subtract(const Duration(days: 1));
                } else {
                   break;
                }
             }
          }
        } else {
          countForDay = 1;
        }
      }

      history.add(DayStreakInfo(
        date: date,
        isActive: isActive,
        isFrozen: isFrozen,
        streakCount: countForDay,
      ));
    }
    return history;
  }
}

class DayStreakInfo {
  final DateTime date;
  final bool isActive;
  final bool isFrozen;
  final int streakCount;

  DayStreakInfo({
    required this.date,
    required this.isActive,
    required this.isFrozen,
    required this.streakCount,
  });
}

final streakNotifierProvider = StateNotifierProvider<StreakNotifier, StreakState>((ref) {
  final prefRepo = ref.watch(preferenceRepositoryProvider);
  return StreakNotifier(prefRepo);
});
