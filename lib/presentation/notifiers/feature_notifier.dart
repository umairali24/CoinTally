import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FeatureState {
  final bool isZakatEnabled;

  FeatureState({required this.isZakatEnabled});

  FeatureState copyWith({bool? isZakatEnabled}) {
    return FeatureState(
      isZakatEnabled: isZakatEnabled ?? this.isZakatEnabled,
    );
  }
}

class FeatureNotifier extends StateNotifier<FeatureState> {
  static const String _zakatKey = 'feature_zakat_enabled';

  FeatureNotifier() : super(FeatureState(isZakatEnabled: false)) {
    _loadFeatures();
  }

  Future<void> _loadFeatures() async {
    final prefs = await SharedPreferences.getInstance();
    state = state.copyWith(
      isZakatEnabled: prefs.getBool(_zakatKey) ?? false,
    );
  }

  Future<void> toggleZakat(bool enabled) async {
    state = state.copyWith(isZakatEnabled: enabled);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_zakatKey, enabled);
  }
}

final featureProvider = StateNotifierProvider<FeatureNotifier, FeatureState>((ref) {
  return FeatureNotifier();
});
