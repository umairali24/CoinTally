import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cointally/data/local/db_helper.dart';
import 'package:cointally/domain/repository/preference_repository.dart';
import 'package:cointally/data/repository/preference_repository_impl.dart';
import 'package:cointally/core/services/currency_api_service.dart';
import 'dart:developer';

class CurrencyState {
  final String primaryCurrency;
  final Map<String, double> exchangeRates; // Key: from_currency, Value: rate to primary
  final bool isLoading;
  final String? errorMessage;

  CurrencyState({
    required this.primaryCurrency,
    this.exchangeRates = const {},
    this.isLoading = false,
    this.errorMessage,
  });

  CurrencyState copyWith({
    String? primaryCurrency,
    Map<String, double>? exchangeRates,
    bool? isLoading,
    String? errorMessage,
  }) {
    return CurrencyState(
      primaryCurrency: primaryCurrency ?? this.primaryCurrency,
      exchangeRates: exchangeRates ?? this.exchangeRates,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}

class CurrencyNotifier extends StateNotifier<CurrencyState> {
  final PreferenceRepository _prefRepo;
  final CurrencyApiService _apiService;
  final DatabaseHelper _dbHelper;

  CurrencyNotifier(this._prefRepo, this._apiService, this._dbHelper)
      : super(CurrencyState(primaryCurrency: 'PKR')) {
    init();
  }

  Future<void> init() async {
    state = state.copyWith(isLoading: true);
    try {
      final primary = await _prefRepo.getPrimaryCurrency();
      state = state.copyWith(primaryCurrency: primary);
      
      // Load cached rates from DB
      await _loadCachedRates();
      
      // Fetch fresh rates if necessary (e.g., if cache is old or empty)
      await refreshRates();
      
      state = state.copyWith(isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
    }
  }

  Future<void> _loadCachedRates() async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'exchange_rates',
      where: 'to_currency = ?',
      whereArgs: [state.primaryCurrency],
    );
    
    final rates = <String, double>{};
    for (var map in maps) {
      rates[map['from_currency'] as String] = (map['rate'] as num).toDouble();
    }
    
    state = state.copyWith(exchangeRates: rates);
  }

  Future<void> refreshRates() async {
    try {
      // 1. Fetch from API
      final rates = await _apiService.fetchExchangeRates(state.primaryCurrency);
      
      // 2. We need the INVERSE rates if the API provides rates relative to the base
      // The API returns: { "base": "usd", "usd": { "pkr": 280 } }
      // Our logic needs: "PKR" -> 1/280 multiplier to get USD
      // Actually, if we want everything in USD, and we have USD rates, 
      // the API gives us `1 USD = X PKR`, so `1 PKR = 1/X USD`.
      
      final normalizedRates = <String, double>{};
      rates.forEach((currency, rateToBase) {
        if (rateToBase != 0) {
          normalizedRates[currency] = 1.0 / rateToBase;
        }
      });
      // Ensure primary currency itself is 1.0
      normalizedRates[state.primaryCurrency.toUpperCase()] = 1.0;

      // 3. Update DB Cache
      final db = await _dbHelper.database;
      final batch = db.batch();
      
      // Delete old rates for this primary currency
      batch.delete('exchange_rates', where: 'to_currency = ?', whereArgs: [state.primaryCurrency]);
      
      final now = DateTime.now().millisecondsSinceEpoch;
      normalizedRates.forEach((from, rate) {
        batch.insert('exchange_rates', {
          'from_currency': from,
          'to_currency': state.primaryCurrency,
          'rate': rate,
          'last_updated': now,
        });
      });
      
      await batch.commit(noResult: true);
      
      state = state.copyWith(exchangeRates: normalizedRates);
    } catch (e) {
      log('Failed to refresh rates: $e');
      // If API fails, we rely on existing cache
    }
  }

  Future<void> updatePrimaryCurrency(String currencyCode) async {
    state = state.copyWith(isLoading: true, primaryCurrency: currencyCode);
    await _prefRepo.setPrimaryCurrency(currencyCode);
    await refreshRates();
    state = state.copyWith(isLoading: false);
  }
  
  double convertToPrimary(double amount, String fromCurrency) {
    if (fromCurrency == state.primaryCurrency) return amount;
    final rate = state.exchangeRates[fromCurrency.toUpperCase()];
    if (rate == null) return amount; // Fallback to 1:1 if no rate found
    return amount * rate;
  }
}

final preferenceRepositoryProvider = Provider<PreferenceRepository>((ref) {
  return PreferenceRepositoryImpl();
});

final currencyNotifierProvider = StateNotifierProvider<CurrencyNotifier, CurrencyState>((ref) {
  final prefRepo = ref.watch(preferenceRepositoryProvider);
  final apiService = CurrencyApiService();
  final dbHelper = DatabaseHelper.instance;
  return CurrencyNotifier(prefRepo, apiService, dbHelper);
});
