import 'dart:io';
import 'package:csv/csv.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:cointally/data/local/db_helper.dart';
import 'dart:developer';
import 'package:file_picker/file_picker.dart';

class ImportResult {
  final int successCount;
  final int failedCount;
  final String? error;

  ImportResult(this.successCount, this.failedCount, {this.error});
}

class ImportService {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  Future<bool> downloadTemplate() async {
    try {
      List<List<dynamic>> csvData = [
        ['Date', 'Amount', 'Type', 'Category', 'Merchant', 'Account'],
        ['${DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now())}', 500.0, 'INCOME', 'Salary', 'Company Inc', 'Cash']
      ];

      String csvString = const CsvEncoder().convert(csvData);
      
      final directory = await getTemporaryDirectory();
      final path = '${directory.path}/hisaabmate_import_template.csv';
      final file = File(path);
      await file.writeAsString(csvString);

      await Share.shareXFiles([XFile(path)], text: 'HisaabMate Import Template (CSV)');
      return true;
    } catch (e) {
      log('Error creating template: $e');
      return false;
    }
  }

  Future<ImportResult> importFromCsv() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv'],
      );

      if (result == null || result.files.single.path == null) {
        return ImportResult(0, 0, error: 'No file selected');
      }

      final file = File(result.files.single.path!);
      final csvString = await file.readAsString();
      
      final List<List<dynamic>> rows = const CsvDecoder().convert(csvString);
      
      if (rows.isEmpty) {
        return ImportResult(0, 0, error: 'File is empty');
      }

      final headers = rows.first.map((e) => e.toString().trim().toLowerCase()).toList();
      
      // Basic validation
      if (!headers.contains('date') || !headers.contains('amount') || !headers.contains('type')) {
        return ImportResult(0, 0, error: 'Invalid CSV format. Please use the template.');
      }

      int success = 0;
      int failed = 0;

      // Cache accounts to map bank names to IDs
      final db = await _dbHelper.database;
      final accounts = await db.query('accounts', columns: ['id', 'bank_name', 'account_type']);
      final accountMap = <String, int>{};
      int? defaultAccountId;
      
      for (var a in accounts) {
        final name = (a['bank_name'] as String).toLowerCase().trim();
        accountMap[name] = a['id'] as int;
        defaultAccountId ??= a['id'] as int; // Just fallback
      }

      for (int i = 1; i < rows.length; i++) {
        try {
          final row = rows[i];
          if (row.length < 3) continue; // Skip incomplete lines

          // Mapping indexes
          final dateIdx = headers.indexOf('date');
          final amountIdx = headers.indexOf('amount');
          final typeIdx = headers.indexOf('type');
          final catIdx = headers.indexOf('category');
          final merchIdx = headers.indexOf('merchant');
          final accIdx = headers.indexOf('account');

          final dateStr = dateIdx >= 0 && dateIdx < row.length ? row[dateIdx].toString().trim() : '';
          final amountStr = amountIdx >= 0 && amountIdx < row.length ? row[amountIdx].toString().trim() : '0';
          final typeStr = typeIdx >= 0 && typeIdx < row.length ? row[typeIdx].toString().trim().toUpperCase() : 'EXPENSE';
          final category = catIdx >= 0 && catIdx < row.length ? row[catIdx].toString().trim() : 'Other';
          final merchant = merchIdx >= 0 && merchIdx < row.length ? row[merchIdx].toString().trim() : null;
          final accountStr = accIdx >= 0 && accIdx < row.length ? row[accIdx].toString().trim() : '';

          DateTime date;
          try {
             date = DateFormat('yyyy-MM-dd HH:mm').parse(dateStr);
          } catch(e) {
             date = DateTime.now();
          }

          final amount = double.tryParse(amountStr.replaceAll(',', '')) ?? 0.0;
          if (amount <= 0.0) {
             failed++;
             continue; // Invalid amount
          }

          if (typeStr != 'INCOME' && typeStr != 'EXPENSE' && typeStr != 'TRANSFER') {
            failed++;
            continue;
          }

          int? accountId = defaultAccountId;
          if (accountStr.isNotEmpty) {
             final key = accountStr.toLowerCase();
             if (accountMap.containsKey(key)) {
                accountId = accountMap[key];
             }
          }

          final newTx = {
            'amount': amount,
            'type': typeStr,
            'category': category.isEmpty ? 'Other' : category,
            'date': date.millisecondsSinceEpoch,
            'merchant_name': merchant?.isEmpty == true ? null : merchant,
            'account_id': accountId,
            'is_auto_detected': 0,
            'is_promotional': 0,
          };

          await _dbHelper.addTransaction(newTx);
          success++;

        } catch (e) {
          log('Row failed: $e');
          failed++;
        }
      }

      return ImportResult(success, failed);

    } catch (e) {
      log('Error importing CSV: $e');
      return ImportResult(0, 0, error: 'An unexpected error occurred: $e');
    }
  }
}
