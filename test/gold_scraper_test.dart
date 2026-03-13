import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:cointally/data/services/gold_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('GoldService parses valid JSON correctly', () async {
    // Mock SharedPreferences
    SharedPreferences.setMockInitialValues({});

    // Mock HTTP Client for JSON structure
    final mockClient = MockClient((request) async {
      return http.Response('{"gold_rate": 526606.71, "silver_rate": 11500.0, "last_updated": "2026-01-27 15:40:44", "currency": "PKR"}', 200);
    });

    final service = GoldService(client: mockClient);
    final goldRate = await service.fetchLiveGoldRate();
    final silverRate = await service.fetchLiveSilverRate();
    
    print('Fetched Rates: Gold: $goldRate, Silver: $silverRate');
    
    expect(goldRate, equals(526606.71));
    expect(silverRate, equals(11500.0));
  });

  test('GoldService handles error or non-200 gracefully', () async {
     SharedPreferences.setMockInitialValues({});
     final mockClient = MockClient((request) async {
       return http.Response('Not Found', 404);
     });

     final service = GoldService(client: mockClient);
     final rate = await service.fetchLiveGoldRate();
     
     expect(rate, 0.0);
  });
}
