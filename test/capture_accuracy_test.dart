import 'package:flutter_test/flutter_test.dart';
import 'package:cointally/core/utils/transaction_parser.dart';
import 'package:cointally/core/utils/spam_filter.dart';

void main() {
  group('Transaction Detection Accuracy Tests', () {
    test('Should ignore promotional messages with percentages', () {
      const text = "Enjoy Flat 7.5% Off on the entire bill at Almirah.";
      expect(SpamFilter.isSpam(text), isTrue);
      expect(TransactionParser.parse('Bank', text), isNull);
    });

    test('Should ignore Raast informational downtime messages', () {
      const text = "Raast services will be unavailable from 5AM to 9AM on 14 Feb. 1LINK transfers will work as usual.";
      expect(SpamFilter.isSpam(text), isTrue);
      expect(TransactionParser.parse('Raast', text), isNull);
    });

    test('Should ignore promotional "deals"', () {
      const text = "The deal is LIVE and flying off the shelves! Broadway Small Pizza just Rs 199.";
      expect(SpamFilter.isSpam(text), isTrue);
    });

    test('Should capture legitimate PAID message', () {
      const text = "PAID 500 FROM BOK FOR PETROL";
      expect(SpamFilter.isSpam(text), isFalse);
      final tx = TransactionParser.parse('Bank', text);
      expect(tx, isNotNull);
      expect(tx!.amount, 500);
      expect(tx.merchantName, 'BOK');
    });

    test('Should correctly parse Meezan Bank legitimate notification', () {
       const text = "Paid Rs. 1500 to KEENU at Grocery Store on 11-Feb-2026";
       expect(SpamFilter.isSpam(text), isFalse);
       final tx = TransactionParser.parse('Meezan Bank', text);
       expect(tx, isNotNull);
       expect(tx!.amount, 1500);
       expect(tx.merchantName, 'KEENU');
    });

    test('Should ignore time range headers as amounts', () {
       // "5AM to 9AM" should not be interpreted as "Rs. 5" or "Rs. 9"
       const text = "unavailable from 5AM to 9AM";
       final tx = TransactionParser.parse('Info', text);
       expect(tx, isNull);
    });
    
    test('Should ignore dates (14 Feb) as amounts', () {
       const text = "maintenance on 14 Feb";
       final tx = TransactionParser.parse('Info', text);
       expect(tx, isNull);
    });

    test('Should ignore "Predict & Win" promotional messages', () {
       const text = "Predict match results for just Rs.1 and win an iPad and AirPods.";
       // This SHOULD be caught by SpamFilter
       expect(SpamFilter.isSpam(text), isTrue);
    });

    test('Should capture BOK SMS with PKR no space', () {
      const text = "BOK: Acc... Credited PKR5,000.00 on 14-Feb-2026. Ref: ...";
      expect(SpamFilter.isSpam(text), isFalse);
      final tx = TransactionParser.parse('BOK', text);
      expect(tx, isNotNull);
      expect(tx!.amount, 5000.00);
      expect(tx.type, 'INCOME');
    });

    test('Should capture HBL App Notification', () {
      const text = "Transaction Successful. PKR 120,450.00 sent to UMER GUL on 14-FEB-26";
      expect(SpamFilter.isSpam(text), isFalse);
      final tx = TransactionParser.parse('HBL Mobile', text);
      expect(tx, isNotNull);
      expect(tx!.amount, 120450.00);
      expect(tx.type, 'EXPENSE');
      expect(tx.merchantName, 'UMER GUL');
    });
  });
}
