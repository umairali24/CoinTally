import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class GoldService {
  static const String _url = 'https://raw.githubusercontent.com/umairali24/hisaabmate-server/master/gold_rate.json';
  static const String _goldKey = 'last_gold_rate';
  static const String _silverKey = 'last_silver_rate';

  final http.Client client;

  GoldService({http.Client? client}) : client = client ?? http.Client();

  /// Fetches the live gold rate from the proxy server.
  Future<double> fetchLiveGoldRate() async {
    final rates = await _fetchAllRates();
    return rates['gold'] ?? await _getCachedRate(_goldKey);
  }

  /// Fetches the live silver rate from the proxy server.
  Future<double> fetchLiveSilverRate() async {
    final rates = await _fetchAllRates();
    return rates['silver'] ?? await _getCachedRate(_silverKey);
  }

  Future<Map<String, double>> _fetchAllRates() async {
    try {
      final response = await client.get(Uri.parse(_url));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final double gold = (data['gold_rate'] as num).toDouble();
        final double silver = (data['silver_rate'] as num).toDouble();
        
        print("Fetched Rates from Server: Gold: $gold, Silver: $silver");
        
        await _cacheRate(_goldKey, gold);
        await _cacheRate(_silverKey, silver);
        
        return {'gold': gold, 'silver': silver};
      }
    } catch (e) {
      print('Error fetching rates from server: $e');
    }
    return {};
  }

  Future<void> _cacheRate(String key, double rate) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(key, rate);
  }

  Future<double> _getCachedRate(String key) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getDouble(key) ?? 0.0;
  }
}
