import 'package:flutter_test/flutter_test.dart';
import 'package:cointally/core/utils/transaction_parser.dart';

void main() {
  group('TransactionParser', () {
    test('parses expense correctly', () {
      final result = TransactionParser.parse('Bank Alert', 'Paid Rs 500 at McDonalds via Card');
      
      expect(result, isNotNull);
      expect(result!.amount, 500.0);
      expect(result.type, 'EXPENSE');
      expect(result.merchantName, 'McDonalds');
    });

    test('parses income correctly', () {
      final result = TransactionParser.parse('Bank Alert', 'Received Rs. 10,000 from Salary');
      
      expect(result, isNotNull);
      expect(result!.amount, 10000.0);
      expect(result.type, 'INCOME');
      expect(result.category, 'Salary');
    });

    test('parses PKR format', () {
      final result = TransactionParser.parse('Alert', 'Purchase of PKR 2500.50 at Shell Station');
      
      expect(result!.amount, 2500.50);
      expect(result.merchantName, 'Shell Station');
    });

    test('handles commas in numbers', () {
      final result = TransactionParser.parse('Alert', 'Debited Rs 100,000 for Car');
      
      expect(result!.amount, 100000.0);
    });

    test('returns null for non-transaction messages', () {
      final result = TransactionParser.parse('OTP', 'Your OTP is 1234');
      
      // It might match 1234 as amount if regex is too loose, but let's see. 
      // Rs./PKR is required by my regex, so this should return null.
      expect(result, isNull);
    });

    test('parses e-commerce transaction with PKR. format', () {
      const sms = 'Dear Customer, you have performed an e-commerce transaction of PKR. 2,322.00 from Account: 001232*****017, at 00:38:02 Dated: 21-FEB-26';
      final result = TransactionParser.parse('Bank', sms);
      
      expect(result, isNotNull);
      expect(result!.amount, 2322.0);
      expect(result.type, 'EXPENSE');
      expect(result.merchantName, 'e-commerce transaction');
    });

    test('parses HBL CreditCard PKR- format with charged keyword', () {
      const sms = 'Dear Customer, Your HBL CreditCard (ending with 5314) has been charged at SNGPL for PKR-8,990.00 on 21/Feb/2026.';
      final result = TransactionParser.parse('HBL', sms);
      
      expect(result, isNotNull);
      expect(result!.amount, 8990.0);
      expect(result.type, 'EXPENSE');
      expect(result.merchantName, 'SNGPL');
    });
  });
}
