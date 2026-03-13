import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cointally/domain/repository/preference_repository.dart';
import 'package:cointally/data/repository/preference_repository_impl.dart';

class FormatPreferencesState {
  final bool isLoading;
  final bool useShortNumberFormat;
  final int decimalPrecision;
  final bool showCurrencySymbol;
  final String? errorMessage;

  const FormatPreferencesState({
    this.isLoading = false,
    this.useShortNumberFormat = false,
    this.decimalPrecision = 1,
    this.showCurrencySymbol = true,
    this.errorMessage,
  });

  FormatPreferencesState copyWith({
    bool? isLoading,
    bool? useShortNumberFormat,
    int? decimalPrecision,
    bool? showCurrencySymbol,
    String? errorMessage,
  }) {
    return FormatPreferencesState(
      isLoading: isLoading ?? this.isLoading,
      useShortNumberFormat: useShortNumberFormat ?? this.useShortNumberFormat,
      decimalPrecision: decimalPrecision ?? this.decimalPrecision,
      showCurrencySymbol: showCurrencySymbol ?? this.showCurrencySymbol,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}

class FormatPreferencesNotifier extends StateNotifier<FormatPreferencesState> {
  final PreferenceRepository _repository;

  FormatPreferencesNotifier(this._repository) : super(const FormatPreferencesState());

  Future<void> loadPreferences() async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final shortFormat = await _repository.getUseShortNumberFormat();
      final precision = await _repository.getDecimalPrecision();
      final showSymbol = await _repository.getShowCurrencySymbol();

      state = state.copyWith(
        isLoading: false,
        useShortNumberFormat: shortFormat,
        decimalPrecision: precision,
        showCurrencySymbol: showSymbol,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Failed to load format preferences: $e',
      );
    }
  }

  Future<void> setUseShortNumberFormat(bool value) async {
    try {
      await _repository.setUseShortNumberFormat(value);
      state = state.copyWith(useShortNumberFormat: value);
    } catch (e) {
      state = state.copyWith(errorMessage: 'Failed to save short format preference: $e');
    }
  }

  Future<void> setDecimalPrecision(int value) async {
    try {
      await _repository.setDecimalPrecision(value);
      state = state.copyWith(decimalPrecision: value);
    } catch (e) {
      state = state.copyWith(errorMessage: 'Failed to save decimal precision: $e');
    }
  }

  Future<void> setShowCurrencySymbol(bool value) async {
    try {
      await _repository.setShowCurrencySymbol(value);
      state = state.copyWith(showCurrencySymbol: value);
    } catch (e) {
      state = state.copyWith(errorMessage: 'Failed to save currency symbol preference: $e');
    }
  }
}

final preferenceRepositoryProvider = Provider<PreferenceRepository>((ref) {
  return PreferenceRepositoryImpl();
});

final formatPreferencesProvider = StateNotifierProvider<FormatPreferencesNotifier, FormatPreferencesState>((ref) {
  final repository = ref.watch(preferenceRepositoryProvider);
  return FormatPreferencesNotifier(repository)..loadPreferences();
});
