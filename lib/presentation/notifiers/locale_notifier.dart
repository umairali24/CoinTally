import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cointally/core/utils/localization_service.dart';

class LocaleNotifier extends StateNotifier<String> {
  static const String _prefKey = 'app_language';

  LocaleNotifier() : super('en') {
    _loadLocale();
  }

  Future<void> _loadLocale() async {
    final prefs = await SharedPreferences.getInstance();
    final savedLocale = prefs.getString(_prefKey);
    if (savedLocale != null) {
      state = savedLocale;
    }
  }

  Future<void> toggleLocale() async {
    state = state == 'en' ? 'ur' : 'en';
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefKey, state);
  }

  String translate(String key) {
    return LocalizationService.translate(key, state);
  }
}

final localeProvider = StateNotifierProvider<LocaleNotifier, String>((ref) {
  return LocaleNotifier();
});
