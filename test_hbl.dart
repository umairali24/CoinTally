import 'package:cointally/core/utils/transaction_parser.dart';

void main() {
  final notif1 = TransactionParser.parse(
    "Transaction Alert: Credit Card Payment",
    "Payment for Other Bank Credit Card of PKR 55700 has been made successfully from Source Account # 1993XXXXXXX6001 via HBL Digital on 27-02-2026 04:09:59. UAN: 021111111425."
  );
  print('Notif 1: ${notif1?.amount} ${notif1?.type} ${notif1?.merchantName}');

  final notif2 = TransactionParser.parse(
    "Transaction Alert: Raast Payment",
    "PKR 9500.00 sent to MUHAMMAD USMAN UR REHMAN KHAN MBL from your HBL A/C *6001 on 27-02-2026 05:15:31 via RAAST Tx ID 17718774006. UAN: 021111111425."
  );
  print('Notif 2: ${notif2?.amount} ${notif2?.type} ${notif2?.merchantName}');
}
