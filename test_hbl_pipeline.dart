import 'package:cointally/core/utils/transaction_parser.dart';
import 'package:cointally/data/local/db_helper.dart';

void main() async {
  // Mocking the event data
  final String title1 = "Transaction Alert: Credit Card Payment";
  final String text1 = "Payment for Other Bank Credit Card of PKR 55700 has been made successfully from Source Account # 1993XXXXXXX6001 via HBL Digital on 27-02-2026 04:09:59. UAN: 021111111425.";
  final String pkg1 = "com.hbl.mob";

  final String title2 = "Transaction Alert: Raast Payment";
  final String text2 = "PKR 9500.00 sent to MUHAMMAD USMAN UR REHMAN KHAN MBL from your HBL A/C *6001 on 27-02-2026 05:15:31 via RAAST Tx ID 17718774006. UAN: 021111111425.";
  final String pkg2 = "com.hbl.mob";

  final tx1 = TransactionParser.parse(title1, text1);
  print('TX1 Parsed: \${tx1 != null}');
  
  if (tx1 != null) {
      final isBlocked = await DatabaseHelper.instance.isSenderBlocked(title1);
      print('Is Sender Blocked 1: $isBlocked');

      final pendingTx = {
        'amount': tx1.amount,
        'type': tx1.type,
        'date': tx1.date.millisecondsSinceEpoch,
        'merchant_name': tx1.merchantName,
        'raw_title': title1,
        'raw_body': text1,
        'package_name': pkg1,
        'suggested_account_id': 1,
        'is_reconciled': 0,
        'notification_key': 'mock_key_1', 
      };
      // Try insert
      final result = await DatabaseHelper.instance.insertPendingUnique(pendingTx);
      print('Insert Result 1: $result');
  }

  final tx2 = TransactionParser.parse(title2, text2);
  print('TX2 Parsed: \${tx2 != null}');
  
  if (tx2 != null) {
      final isBlocked = await DatabaseHelper.instance.isSenderBlocked(title2);
      print('Is Sender Blocked 2: $isBlocked');

      final pendingTx = {
        'amount': tx2.amount,
        'type': tx2.type,
        'date': tx2.date.millisecondsSinceEpoch,
        'merchant_name': tx2.merchantName,
        'raw_title': title2,
        'raw_body': text2,
        'package_name': pkg2,
        'suggested_account_id': 1,
        'is_reconciled': 0,
        'notification_key': 'mock_key_2', 
      };
      // Try insert
      final result = await DatabaseHelper.instance.insertPendingUnique(pendingTx);
      print('Insert Result 2: $result');
  }
}
