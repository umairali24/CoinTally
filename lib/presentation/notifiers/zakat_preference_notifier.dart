import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cointally/domain/entities/zakat_models.dart';
import 'package:cointally/domain/repository/preference_repository.dart';
import 'package:cointally/presentation/screens/notification_settings_screen.dart'; // For preferenceRepositoryProvider

class ZakatPreferenceState {
  final NisabStandard nisabStandard;
  final FiqhSchool fiqhSchool;

  ZakatPreferenceState({
    required this.nisabStandard,
    required this.fiqhSchool,
  });

  ZakatPreferenceState copyWith({
    NisabStandard? nisabStandard,
    FiqhSchool? fiqhSchool,
  }) {
    return ZakatPreferenceState(
      nisabStandard: nisabStandard ?? this.nisabStandard,
      fiqhSchool: fiqhSchool ?? this.fiqhSchool,
    );
  }
}

class ZakatPreferenceNotifier extends StateNotifier<ZakatPreferenceState> {
  final PreferenceRepository _prefRepo;

  ZakatPreferenceNotifier(this._prefRepo)
      : super(ZakatPreferenceState(
          nisabStandard: NisabStandard.silver,
          fiqhSchool: FiqhSchool.hanafi,
        )) {
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    final standardStr = await _prefRepo.getZakatNisabStandard();
    final schoolStr = await _prefRepo.getZakatFiqhSchool();

    final standard = NisabStandard.values.firstWhere(
      (e) => e.name == standardStr,
      orElse: () => NisabStandard.silver,
    );

    final school = FiqhSchool.values.firstWhere(
      (e) => e.name == schoolStr,
      orElse: () => FiqhSchool.hanafi,
    );

    state = state.copyWith(nisabStandard: standard, fiqhSchool: school);
  }

  Future<void> setNisabStandard(NisabStandard standard) async {
    await _prefRepo.setZakatNisabStandard(standard.name);
    state = state.copyWith(nisabStandard: standard);
  }

  Future<void> setFiqhSchool(FiqhSchool school) async {
    await _prefRepo.setZakatFiqhSchool(school.name);
    state = state.copyWith(fiqhSchool: school);
  }
}

final zakatPreferenceProvider = StateNotifierProvider<ZakatPreferenceNotifier, ZakatPreferenceState>((ref) {
  final repo = ref.watch(preferenceRepositoryProvider);
  return ZakatPreferenceNotifier(repo);
});
