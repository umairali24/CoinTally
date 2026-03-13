import 'dart:io';
import 'package:csv/csv.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:cointally/data/local/db_helper.dart';
import 'dart:developer';

class ExportService {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  Future<List<Map<String, dynamic>>> _fetchData() async {
    final db = await _dbHelper.database;
    // We do a raw query to join accounts and get bank names instead of raw IDs
    final data = await db.rawQuery('''
      SELECT 
        t.date, 
        t.amount, 
        t.type, 
        t.category, 
        t.merchant_name, 
        a.bank_name 
      FROM transactions t
      LEFT JOIN accounts a ON t.account_id = a.id
      ORDER BY t.date DESC
    ''');
    return data;
  }

  Future<bool> exportToCsv() async {
    try {
      final transactions = await _fetchData();
      
      List<List<dynamic>> csvData = [
        ['Date', 'Amount', 'Type', 'Category', 'Merchant', 'Account']
      ];

      for (var row in transactions) {
        final dateStr = DateFormat('yyyy-MM-dd HH:mm').format(DateTime.fromMillisecondsSinceEpoch(row['date'] as int));
        csvData.add([
          dateStr,
          row['amount'],
          row['type'],
          row['category'],
          row['merchant_name'] ?? '',
          row['bank_name'] ?? 'Unknown',
        ]);
      }

      String csvString = const CsvEncoder().convert(csvData);
      
      final directory = await getTemporaryDirectory();
      final path = '${directory.path}/hisaabmate_export_${DateFormat('yyyyMMdd').format(DateTime.now())}.csv';
      final file = File(path);
      await file.writeAsString(csvString);

      await Share.shareXFiles([XFile(path)], text: 'HisaabMate Financial Export (CSV)');
      return true;
    } catch (e) {
      log('Error exporting CSV: $e');
      return false;
    }
  }

  Future<bool> exportToPdf() async {
    try {
      final transactions = await _fetchData();
      final pdf = pw.Document();

      final headers = ['Date', 'Amount', 'Type', 'Category', 'Account'];

      final dataRows = transactions.map((row) {
        return [
          DateFormat('MMM dd, yyyy').format(DateTime.fromMillisecondsSinceEpoch(row['date'] as int)),
          row['amount'].toString(),
          row['type'].toString(),
          row['category'].toString(),
          row['bank_name']?.toString() ?? 'Unknown',
        ];
      }).toList();

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          build: (context) => [
            pw.Header(
              level: 0,
              child: pw.Text('HisaabMate Transaction Export', style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
            ),
            pw.Text(
              'Generated on: ${DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now())}',
              style: const pw.TextStyle(fontSize: 12, color: PdfColors.grey700),
            ),
            pw.SizedBox(height: 20),
            pw.TableHelper.fromTextArray(
              headers: headers,
              data: dataRows,
              border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
              headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white),
              headerDecoration: const pw.BoxDecoration(color: PdfColors.blueGrey800),
              rowDecoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey300, width: 0.5))),
              cellAlignment: pw.Alignment.centerLeft,
              cellPadding: const pw.EdgeInsets.all(6),
            ),
          ],
        ),
      );

      final directory = await getTemporaryDirectory();
      final path = '${directory.path}/hisaabmate_export_${DateFormat('yyyyMMdd').format(DateTime.now())}.pdf';
      final file = File(path);
      await file.writeAsBytes(await pdf.save());

      await Share.shareXFiles([XFile(path)], text: 'HisaabMate Financial Export (PDF)');
      return true;
    } catch (e) {
      log('Error exporting PDF: $e');
      return false;
    }
  }
}
