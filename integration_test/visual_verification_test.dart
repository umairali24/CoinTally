import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:path/path.dart';
import 'package:cointally/main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Verify Add Transaction Update Balance', (WidgetTester tester) async {
    // 0. Reset Database
    // We need to initialize FFI for the test runner to delete the DB
    if (Platform.isWindows || Platform.isLinux) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'hisaabmate.db');
    await deleteDatabase(path);

    // 1. Launch the app
    await app.main();
    await tester.pumpAndSettle();

    // 2. Click Floating Action Button
    final fab = find.byType(FloatingActionButton);
    expect(fab, findsOneWidget);
    await tester.tap(fab);
    await tester.pumpAndSettle(); // Wait for navigation

    // 3. Select INCOME (to resolve positive balance expectation)
    await tester.tap(find.text('INCOME'));
    await tester.pumpAndSettle();

    // 4. Input '500' for Amount
    final amountLabel = find.text('Amount');
    final amountTextField = find.ancestor(of: amountLabel, matching: find.byType(TextFormField)).first;
    
    await tester.enterText(amountTextField, '500');
    await tester.pumpAndSettle();

    // 4. Click Save (using the key I added)
    final saveButton = find.byKey(const Key('saveTransactionButton'));
    expect(saveButton, findsOneWidget);
    await tester.tap(saveButton);
    await tester.pumpAndSettle(); // Wait for navigation back

    // 5. Verify Total Balance is 500.00
    // The previous code showed 'Rs. ${state.totalBalance.toStringAsFixed(2)}' which means 'Rs. 500.00'
    expect(find.text('Rs. 500.00'), findsOneWidget);
  });
}
