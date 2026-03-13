import 'package:cointally/data/local/db_helper.dart';
import 'package:cointally/core/services/currency_api_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:developer';

class CurrencySyncService {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;
  final CurrencyApiService _apiService = CurrencyApiService();

  Future<bool> syncRates() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final primaryCurrency = prefs.getString('primary_currency') ?? 'PKR';
      
      log('Background Sync: Fetching rates for $primaryCurrency');
      final rates = await _apiService.fetchExchangeRates(primaryCurrency);
      
      final normalizedRates = <String, double>{};
      rates.forEach((currency, rateToBase) {
        if (rateToBase != 0) {
          normalizedRates[currency] = 1.0 / rateToBase;
        }
      });
      normalizedRates[primaryCurrency.toUpperCase()] = 1.0;

      final db = await _dbHelper.database;
      final batch = db.batch();
      
      batch.delete('exchange_rates', where: 'to_currency = ?', whereArgs: [primaryCurrency]);
      
      final now = DateTime.now().millisecondsSinceEpoch;
      normalizedRates.forEach((from, rate) {
        batch.insert('exchange_rates', {
          'from_currency': from,
          'to_currency': primaryCurrency,
          'rate': rate,
          'last_updated': now,
        });
      });
      
      await batch.commit(noResult: true);
      log('Background Sync: Successful for $primaryCurrency');
      return true;
    } catch (e) {
      log('Background Sync: Failed - $e');
      return false;
    }
  }
}
