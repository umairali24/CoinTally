import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class WhitelistState {
  final Set<String> whitelistedPackages;
  final bool smsAlertsEnabled;
  final String? defaultSmsPackage;

  WhitelistState({
    required this.whitelistedPackages,
    required this.smsAlertsEnabled,
    this.defaultSmsPackage,
  });

  WhitelistState copyWith({
    Set<String>? whitelistedPackages,
    bool? smsAlertsEnabled,
    String? defaultSmsPackage,
  }) {
    return WhitelistState(
      whitelistedPackages: whitelistedPackages ?? this.whitelistedPackages,
      smsAlertsEnabled: smsAlertsEnabled ?? this.smsAlertsEnabled,
      defaultSmsPackage: defaultSmsPackage ?? this.defaultSmsPackage,
    );
  }
}

final whitelistProvider = StateNotifierProvider<WhitelistNotifier, WhitelistState>((ref) {
  return WhitelistNotifier();
});

class WhitelistNotifier extends StateNotifier<WhitelistState> {
  WhitelistNotifier() : super(WhitelistState(whitelistedPackages: {}, smsAlertsEnabled: false)) {
    _loadWhitelist();
  }

  static const String _storageKey = 'notification_whitelist';
  static const String _smsKey = 'sms_alerts_enabled';
  static const String _defaultSmsKey = 'default_sms_package';

  Future<void> _loadWhitelist() async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_storageKey) ?? [];
    final smsEnabled = prefs.getBool(_smsKey) ?? false;
    final defaultSms = prefs.getString(_defaultSmsKey);
    
    state = state.copyWith(
      whitelistedPackages: list.toSet(),
      smsAlertsEnabled: smsEnabled,
      defaultSmsPackage: defaultSms,
    );
  }

  Future<void> toggleApp(String packageName) async {
    final newWhitelist = Set<String>.from(state.whitelistedPackages);
    if (newWhitelist.contains(packageName)) {
      newWhitelist.remove(packageName);
    } else {
      newWhitelist.add(packageName);
    }
    state = state.copyWith(whitelistedPackages: newWhitelist);
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_storageKey, state.whitelistedPackages.toList());
  }

  Future<void> setSmsAlertsEnabled(bool enabled) async {
    state = state.copyWith(smsAlertsEnabled: enabled);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_smsKey, enabled);
  }

  Future<void> setDefaultSmsPackage(String? packageName) async {
    state = state.copyWith(defaultSmsPackage: packageName);
    final prefs = await SharedPreferences.getInstance();
    if (packageName != null) {
      await prefs.setString(_defaultSmsKey, packageName);
    } else {
      await prefs.remove(_defaultSmsKey);
    }
  }

  bool isAllowed(String packageName) {
    if (state.smsAlertsEnabled && packageName == state.defaultSmsPackage) {
      return true;
    }
    return state.whitelistedPackages.contains(packageName);
  }
}
