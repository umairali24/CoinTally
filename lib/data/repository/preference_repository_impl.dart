import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cointally/domain/repository/preference_repository.dart';
import 'package:intl/intl.dart';

class PreferenceRepositoryImpl implements PreferenceRepository {
  static const String _primaryCurrencyKey = 'primary_currency';
  static const String _currentStreakKey = 'current_streak';
  static const String _lastActiveDateKey = 'last_active_date';
  static const String _longestStreakKey = 'longest_streak';
  static const String _availableFreezesKey = 'available_freezes';
  static const String _dailyReminderEnabledKey = 'daily_reminder_enabled';
  static const String _dailyReminderTimeKey = 'daily_reminder_time';
  static const String _autoCaptureNotificationsEnabledKey = 'auto_capture_notifications_enabled';
  static const String _activeDatesKey = 'streak_active_dates';
  static const String _frozenDatesKey = 'streak_frozen_dates';
  static const String _useShortNumberFormatKey = 'use_short_number_format';
  static const String _decimalPrecisionKey = 'decimal_precision';
  static const String _showCurrencySymbolKey = 'show_currency_symbol';
  static const String _zakatNisabStandardKey = 'zakat_nisab_standard';
  static const String _zakatFiqhSchoolKey = 'zakat_fiqh_school';
  static const String _zakatAssetsKey = 'zakat_assets_json';
  static const String _zakatLiabilitiesKey = 'zakat_liabilities_json';

  @override
  Future<String> getPrimaryCurrency() async {
    final prefs = await SharedPreferences.getInstance();
    String? currency = prefs.getString(_primaryCurrencyKey);
    
    if (currency == null) {
      currency = _detectDefaultCurrency();
      await setPrimaryCurrency(currency);
    }
    
    return currency;
  }

  @override
  Future<void> setPrimaryCurrency(String currencyCode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_primaryCurrencyKey, currencyCode);
  }

  @override
  Future<int> getCurrentStreak() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_currentStreakKey) ?? 0;
  }

  @override
  Future<void> setCurrentStreak(int streak) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_currentStreakKey, streak);
  }

  @override
  Future<String?> getLastActiveDate() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_lastActiveDateKey);
  }

  @override
  Future<void> setLastActiveDate(String? date) async {
    final prefs = await SharedPreferences.getInstance();
    if (date == null) {
      await prefs.remove(_lastActiveDateKey);
    } else {
      await prefs.setString(_lastActiveDateKey, date);
    }
  }

  @override
  Future<int> getLongestStreak() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_longestStreakKey) ?? 0;
  }

  @override
  Future<void> setLongestStreak(int streak) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_longestStreakKey, streak);
  }

  @override
  Future<int> getAvailableFreezes() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_availableFreezesKey) ?? 1; // Default 1 freeze
  }

  @override
  Future<void> setAvailableFreezes(int freezes) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_availableFreezesKey, freezes);
  }

  @override
  Future<List<String>> getActiveDates() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_activeDatesKey) ?? [];
  }

  @override
  Future<void> setActiveDates(List<String> dates) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_activeDatesKey, dates);
  }

  @override
  Future<List<String>> getFrozenDates() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_frozenDatesKey) ?? [];
  }

  @override
  Future<void> setFrozenDates(List<String> dates) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_frozenDatesKey, dates);
  }

  @override
  Future<bool> isDailyReminderEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_dailyReminderEnabledKey) ?? false;
  }

  @override
  Future<void> setDailyReminderEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_dailyReminderEnabledKey, enabled);
  }

  @override
  Future<String> getDailyReminderTime() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_dailyReminderTimeKey) ?? '20:00';
  }

  @override
  Future<void> setDailyReminderTime(String time) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_dailyReminderTimeKey, time);
  }

  @override
  Future<bool> isAutoCaptureNotificationsEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_autoCaptureNotificationsEnabledKey) ?? false;
  }

  @override
  Future<void> setAutoCaptureNotificationsEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_autoCaptureNotificationsEnabledKey, enabled);
  }

  @override
  Future<bool> getUseShortNumberFormat() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_useShortNumberFormatKey) ?? false;
  }

  @override
  Future<void> setUseShortNumberFormat(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_useShortNumberFormatKey, value);
  }

  @override
  Future<int> getDecimalPrecision() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_decimalPrecisionKey) ?? 1; // Default to 1 decimal place
  }

  @override
  Future<void> setDecimalPrecision(int value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_decimalPrecisionKey, value);
  }

  @override
  Future<bool> getShowCurrencySymbol() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_showCurrencySymbolKey) ?? true;
  }

  @override
  Future<void> setShowCurrencySymbol(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_showCurrencySymbolKey, value);
  }

  @override
  Future<String> getZakatNisabStandard() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_zakatNisabStandardKey) ?? 'silver';
  }

  @override
  Future<void> setZakatNisabStandard(String standard) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_zakatNisabStandardKey, standard);
  }

  @override
  Future<String> getZakatFiqhSchool() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_zakatFiqhSchoolKey) ?? 'hanafi';
  }

  @override
  Future<void> setZakatFiqhSchool(String school) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_zakatFiqhSchoolKey, school);
  }

  @override
  Future<String?> getZakatAssetsJson() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_zakatAssetsKey);
  }

  @override
  Future<void> setZakatAssetsJson(String jsonStr) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_zakatAssetsKey, jsonStr);
  }

  @override
  Future<String?> getZakatLiabilitiesJson() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_zakatLiabilitiesKey);
  }

  @override
  Future<void> setZakatLiabilitiesJson(String jsonStr) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_zakatLiabilitiesKey, jsonStr);
  }

  String _detectDefaultCurrency() {
    try {
      final locale = Platform.localeName;
      if (locale.toUpperCase().contains('PK')) {
        return 'PKR';
      }
      final format = NumberFormat.simpleCurrency(locale: locale);
      if (format.currencyName != null && format.currencyName != 'USD') {
        return format.currencyName!;
      }
      return (format.currencyName == 'USD' && !locale.toUpperCase().contains('US')) ? 'PKR' : 'USD';
    } catch (e) {
      return 'PKR';
    }
  }
}
