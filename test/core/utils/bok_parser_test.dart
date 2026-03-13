import 'package:cointally/core/utils/transaction_parser.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('BOK Debit Notification Test', () {
    const title = 'BOK Mobile';
    const body = 'Trans Alert: Dear Customer, Your A/C 000123 has been debited by PKR 1,000.00 for IBFT to MR. TEST on 17-02-2026. Available Balance is PKR 5,000.00';
    
    final result = TransactionParser.parse(title, body);
    
    print('Amount: ${result?.amount}');
    print('Type: ${result?.type}');
    print('Merchant: ${result?.merchantName}');
    
    expect(result, isNotNull);
    expect(result!.amount, 1000.0);
    expect(result.type, 'EXPENSE');
  });

  test('BOK SMS Test', () {
    const title = 'BOK';
    const body = 'Your A/C 000123 has been debited by PKR 500.00 for POS Purchase at DAWN BREAD on 17-02-2026.';
    
    final result = TransactionParser.parse(title, body);
    
    print('Amount: ${result?.amount}');
    print('Type: ${result?.type}');
    print('Merchant: ${result?.merchantName}');
    
    expect(result, isNotNull);
    expect(result!.amount, 500.0);
    expect(result.type, 'EXPENSE');
  });
}
