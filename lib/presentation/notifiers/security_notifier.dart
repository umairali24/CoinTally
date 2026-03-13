import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cointally/core/services/biometric_service.dart';

class SecurityState {
  final bool isBiometricEnabled;
  final bool isAppLocked;
  final DateTime? lastActiveTime;

  SecurityState({
    this.isBiometricEnabled = false,
    this.isAppLocked = false,
    this.lastActiveTime,
  });

  SecurityState copyWith({
    bool? isBiometricEnabled,
    bool? isAppLocked,
    DateTime? lastActiveTime,
  }) {
    return SecurityState(
      isBiometricEnabled: isBiometricEnabled ?? this.isBiometricEnabled,
      isAppLocked: isAppLocked ?? this.isAppLocked,
      lastActiveTime: lastActiveTime ?? this.lastActiveTime,
    );
  }
}

class SecurityNotifier extends StateNotifier<SecurityState> {
  final BiometricService _biometricService;
  static const String _biometricKey = 'biometric_lock_enabled';

  SecurityNotifier(this._biometricService) : super(SecurityState()) {
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final isEnabled = prefs.getBool(_biometricKey) ?? false;
    state = state.copyWith(isBiometricEnabled: isEnabled, isAppLocked: isEnabled);
  }

  Future<void> toggleBiometric(bool value) async {
    if (value) {
      final available = await _biometricService.isBiometricAvailable();
      if (!available) {
        // Handle no biometrics available
        return;
      }
      final authenticated = await _biometricService.authenticate(
        reason: 'Enable biometric lock',
      );
      if (!authenticated) return;
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_biometricKey, value);
    state = state.copyWith(isBiometricEnabled: value);
  }

  void setLockStatus(bool isLocked) {
    state = state.copyWith(isAppLocked: isLocked);
  }

  void updateLastActiveTime() {
    state = state.copyWith(lastActiveTime: DateTime.now());
  }

  Future<bool> authenticate() async {
    if (!state.isBiometricEnabled) return true;
    
    final authenticated = await _biometricService.authenticate();
    if (authenticated) {
      state = state.copyWith(isAppLocked: false);
      updateLastActiveTime();
    }
    return authenticated;
  }
}

final biometricServiceProvider = Provider((ref) => BiometricService());

final securityProvider = StateNotifierProvider<SecurityNotifier, SecurityState>((ref) {
  final biometricService = ref.watch(biometricServiceProvider);
  return SecurityNotifier(biometricService);
});
