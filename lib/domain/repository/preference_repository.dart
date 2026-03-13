abstract class PreferenceRepository {
  Future<String> getPrimaryCurrency();
  Future<void> setPrimaryCurrency(String currencyCode);

  // Streak fields
  Future<int> getCurrentStreak();
  Future<void> setCurrentStreak(int streak);
  Future<String?> getLastActiveDate();
  Future<void> setLastActiveDate(String? date);
  Future<int> getLongestStreak();
  Future<void> setLongestStreak(int streak);
  Future<int> getAvailableFreezes();
  Future<void> setAvailableFreezes(int freezes);

  // Historical Streak Data
  Future<List<String>> getActiveDates();
  Future<void> setActiveDates(List<String> dates);
  Future<List<String>> getFrozenDates();
  Future<void> setFrozenDates(List<String> dates);

  // Notification Preferences
  Future<bool> isDailyReminderEnabled();
  Future<void> setDailyReminderEnabled(bool enabled);
  Future<String> getDailyReminderTime();
  Future<void> setDailyReminderTime(String time);
  Future<bool> isAutoCaptureNotificationsEnabled();
  Future<void> setAutoCaptureNotificationsEnabled(bool enabled);

  // Formatting Preferences
  Future<bool> getUseShortNumberFormat();
  Future<void> setUseShortNumberFormat(bool value);
  Future<int> getDecimalPrecision();
  Future<void> setDecimalPrecision(int value);
  Future<bool> getShowCurrencySymbol();
  Future<void> setShowCurrencySymbol(bool value);

  // Zakat Preferences
  Future<String> getZakatNisabStandard();
  Future<void> setZakatNisabStandard(String standard);
  Future<String> getZakatFiqhSchool();
  Future<void> setZakatFiqhSchool(String school);
  
  Future<String?> getZakatAssetsJson();
  Future<void> setZakatAssetsJson(String jsonStr);
  
  Future<String?> getZakatLiabilitiesJson();
  Future<void> setZakatLiabilitiesJson(String jsonStr);
}
