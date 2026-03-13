import 'package:flutter_test/flutter_test.dart';
import 'package:cointally/domain/entities/transaction_entity.dart';
import 'package:cointally/domain/entities/account_entity.dart';
import 'package:cointally/domain/entities/goal_entity.dart';

void main() {
  group('TransactionEntity', () {
    test('toMap converts DateTime to milliseconds and bool to int', () {
      final date = DateTime.fromMillisecondsSinceEpoch(1672531200000); // 2023-01-01
      final transaction = TransactionEntity(
        id: 1,
        amount: 500.0,
        type: 'EXPENSE',
        category: 'Food',
        date: date,
        isAutoDetected: true,
      );

      final map = transaction.toMap();

      expect(map['date'], 1672531200000);
      expect(map['is_auto_detected'], 1);
    });

    test('fromMap converts int to DateTime and int to bool', () {
      final map = {
        'id': 1,
        'amount': 500.0,
        'type': 'EXPENSE',
        'category': 'Food',
        'date': 1672531200000,
        'is_auto_detected': 1,
      };

      final transaction = TransactionEntity.fromMap(map);

      expect(transaction.date.millisecondsSinceEpoch, 1672531200000);
      expect(transaction.isAutoDetected, true);
    });
  });

  group('GoalEntity', () {
    test('isLocked converts correctly', () {
      final goal = GoalEntity(title: 'Car', targetAmount: 1000, isLocked: true);
      expect(goal.toMap()['is_locked'], 1);

      final map = {
        'title': 'Car',
        'target_amount': 1000.0,
        'current_amount': 0.0,
        'is_locked': 0,
      };
      expect(GoalEntity.fromMap(map).isLocked, false);
    });
  });
}
