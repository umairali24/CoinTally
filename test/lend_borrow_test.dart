import 'package:flutter_test/flutter_test.dart';
import 'package:cointally/domain/entities/debt_entity.dart';
import 'package:cointally/domain/entities/person_entity.dart';

void main() {
  group('Lend & Borrow Entities', () {
    test('PersonEntity toMap and fromMap', () {
      final date = DateTime(2023, 10, 1);
      final person = PersonEntity(
        id: 1,
        name: 'John Doe',
        phoneNumber: '123456789',
        createdAt: date,
      );

      final map = person.toMap();
      expect(map['id'], 1);
      expect(map['name'], 'John Doe');
      expect(map['phone_number'], '123456789');
      expect(map['created_at'], date.millisecondsSinceEpoch);

      final fromMap = PersonEntity.fromMap(map);
      expect(fromMap.id, 1);
      expect(fromMap.name, 'John Doe');
      expect(fromMap.phoneNumber, '123456789');
      expect(fromMap.createdAt, date);
    });

    test('DebtEntity toMap and fromMap', () {
      final date = DateTime(2023, 10, 1);
      final dueDate = DateTime(2023, 10, 10);
      final debt = DebtEntity(
        id: 1,
        personId: 10,
        amount: 500.0,
        type: 'LEND',
        description: 'Lunch money',
        date: date,
        dueDate: dueDate,
        remindMe: true,
        isSettled: false,
        accountId: 2,
      );

      final map = debt.toMap();
      expect(map['id'], 1);
      expect(map['person_id'], 10);
      expect(map['amount'], 500.0);
      expect(map['type'], 'LEND');
      expect(map['description'], 'Lunch money');
      expect(map['date'], date.millisecondsSinceEpoch);
      expect(map['due_date'], dueDate.millisecondsSinceEpoch);
      expect(map['remind_me'], 1);
      expect(map['is_settled'], 0);
      expect(map['account_id'], 2);

      final fromMap = DebtEntity.fromMap(map);
      expect(fromMap.id, 1);
      expect(fromMap.personId, 10);
      expect(fromMap.amount, 500.0);
      expect(fromMap.type, 'LEND');
      expect(fromMap.remindMe, true);
      expect(fromMap.isSettled, false);
      expect(fromMap.dueDate, dueDate);
    });
  });
}
