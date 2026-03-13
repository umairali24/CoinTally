import 'dart:convert';
import 'package:http/http.dart' as http;
import 'dart:developer';

class CurrencyApiService {
  static const String _baseUrl = 'https://cdn.jsdelivr.net/npm/@fawazahmed0/currency-api@latest/v1/currencies';

  Future<Map<String, double>> fetchExchangeRates(String baseCurrency) async {
    final lowercaseBase = baseCurrency.toLowerCase();
    final url = Uri.parse('$_baseUrl/$lowercaseBase.json');
    
    try {
      log('Fetching exchange rates for $baseCurrency from $url');
      final response = await http.get(url);
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final dynamic rates = data[lowercaseBase];
        
        if (rates is Map<String, dynamic>) {
          return rates.map((key, value) => MapEntry(key.toUpperCase(), (value as num).toDouble()));
        }
      }
      throw Exception('Failed to load exchange rates: ${response.statusCode}');
    } catch (e) {
      log('Error fetching exchange rates: $e');
      rethrow;
    }
  }
}
