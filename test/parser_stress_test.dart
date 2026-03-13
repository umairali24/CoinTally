import 'package:flutter_test/flutter_test.dart';
import 'package:cointally/core/utils/transaction_parser.dart';

void main() {
  test('Stress Test: Parsing Real World Notification (Title + Body)', () {
    // Scenario: User "Ali" sends a message. The parser should combine "Ali" and "Paid..."
    const String title = "Ali";
    const String body = "Paid Rs 500 at Pizza Hut for dinner";
    
    final result = TransactionParser.parse(title, body);

    expect(result, isNotNull, reason: "Parser returned null for valid SMS");
    expect(result!.amount, 500.0, reason: "Incorrect Amount extracted");
    expect(result.merchantName, "Pizza Hut", reason: "Incorrect Merchant extracted");
  });

  test('Bug Reproduction: Amount without Currency Symbol', () {
      const String title = "Yasir";
      const String body = "Paid to Yasir 1000 for Bill";
      
      final result = TransactionParser.parse(title, body);
      
      expect(result, isNotNull, reason: "Parser returned null for message without 'Rs'");
      expect(result!.amount, 1000.0);
      expect(result.merchantName, "Yasir");
  });
}
