import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cointally/core/services/import_service.dart';
import 'package:cointally/presentation/notifiers/locale_notifier.dart';
import 'package:cointally/presentation/notifiers/transaction_notifier.dart';
import 'package:cointally/presentation/notifiers/account_notifier.dart';

class ImportSettingsScreen extends ConsumerStatefulWidget {
  const ImportSettingsScreen({super.key});

  @override
  ConsumerState<ImportSettingsScreen> createState() => _ImportSettingsScreenState();
}

class _ImportSettingsScreenState extends ConsumerState<ImportSettingsScreen> {
  final ImportService _importService = ImportService();
  bool _isProcessing = false;

  Future<void> _handleDownloadTemplate() async {
    setState(() => _isProcessing = true);
    await Future.delayed(const Duration(milliseconds: 500));
    
    final success = await _importService.downloadTemplate();
    
    if (mounted) {
      setState(() => _isProcessing = false);
      if (!success) {
         ScaffoldMessenger.of(context).showSnackBar(
           const SnackBar(content: Text('Failed to download template. Please try again.')),
         );
      }
    }
  }

  Future<void> _handleImportCsv() async {
    setState(() => _isProcessing = true);
    
    final result = await _importService.importFromCsv();
    
    if (mounted) {
      setState(() => _isProcessing = false);
      if (result.error != null) {
        // Show error message (could be 'No file selected', so handle gracefully)
        if (result.error != 'No file selected') {
           ScaffoldMessenger.of(context).showSnackBar(
             SnackBar(content: Text(result.error!)),
           );
        }
      } else {
        // Refresh data
        ref.read(transactionProvider.notifier).loadData();
        ref.read(accountProvider.notifier).loadAccounts();
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
             content: Text('Import complete: ${result.successCount} added, ${result.failedCount} failed/skipped.'),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final localeNotifier = ref.read(localeProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: Text(localeNotifier.translate('import_data'), style: GoogleFonts.manrope(fontWeight: FontWeight.w700)),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
             const Icon(Icons.upload_file_rounded, size: 80, color: Colors.blueAccent),
             const SizedBox(height: 32),
             
             Text(
               'Use our CSV template to structure your transactions, then import them directly into HisaabMate.',
               textAlign: TextAlign.center,
               style: GoogleFonts.manrope(
                 fontSize: 16,
                 color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.7),
               ),
             ),
             const SizedBox(height: 48),

             if (_isProcessing)
               const Center(child: CircularProgressIndicator())
             else ...[
               _buildImportOption(
                 context: context,
                 title: localeNotifier.translate('download_template'),
                 subtitle: 'Get the blank CSV structure',
                 icon: Icons.sim_card_download_rounded,
                 color: Colors.blueAccent,
                 onTap: _handleDownloadTemplate,
               ),
               const SizedBox(height: 16),
               _buildImportOption(
                 context: context,
                 title: localeNotifier.translate('import_csv'),
                 subtitle: 'Choose a file to upload data',
                 icon: Icons.file_upload_rounded,
                 color: Colors.deepOrangeAccent,
                 onTap: _handleImportCsv,
               ),
             ],
          ],
        ),
      ),
    );
  }

  Widget _buildImportOption({
    required BuildContext context,
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Theme.of(context).cardTheme.color,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Theme.of(context).colorScheme.primary.withOpacity(0.1)),
          ),
          child: Row(
            children: [
               Container(
                 padding: const EdgeInsets.all(12),
                 decoration: BoxDecoration(
                   color: color.withOpacity(0.1),
                   shape: BoxShape.circle,
                 ),
                 child: Icon(icon, color: color, size: 28),
               ),
               const SizedBox(width: 16),
               Expanded(
                 child: Column(
                   crossAxisAlignment: CrossAxisAlignment.start,
                   children: [
                     Text(
                       title,
                       style: GoogleFonts.manrope(
                         fontWeight: FontWeight.w700,
                         fontSize: 16,
                       ),
                     ),
                     const SizedBox(height: 4),
                     Text(
                       subtitle,
                       style: GoogleFonts.manrope(
                         fontSize: 12,
                         color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.5),
                       ),
                     ),
                   ],
                 ),
               ),
               Icon(Icons.chevron_right_rounded, color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.2)),
            ],
          ),
        ),
      ),
    );
  }
}
