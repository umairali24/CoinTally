import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cointally/core/services/export_service.dart';
import 'package:cointally/presentation/notifiers/locale_notifier.dart';
import 'package:cointally/presentation/widgets/sleek_components.dart';

class ExportSettingsScreen extends ConsumerStatefulWidget {
  const ExportSettingsScreen({super.key});

  @override
  ConsumerState<ExportSettingsScreen> createState() => _ExportSettingsScreenState();
}

class _ExportSettingsScreenState extends ConsumerState<ExportSettingsScreen> {
  final ExportService _exportService = ExportService();
  bool _isProcessing = false;

  Future<void> _handleExport(bool isPdf) async {
    setState(() => _isProcessing = true);
    
    // Simulate slight delay for UX
    await Future.delayed(const Duration(milliseconds: 500));
    
    bool success;
    if (isPdf) {
      success = await _exportService.exportToPdf();
    } else {
      success = await _exportService.exportToCsv();
    }
    
    if (mounted) {
      setState(() => _isProcessing = false);
      if (!success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Export failed. Please try again.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final localeNotifier = ref.read(localeProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: Text(localeNotifier.translate('export_data'), style: GoogleFonts.manrope(fontWeight: FontWeight.w700)),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
             const Icon(Icons.file_download_rounded, size: 80, color: Colors.green),
             const SizedBox(height: 32),
             
             Text(
               'Export your financial data to analyze it in Excel, or save it as a PDF report for your records.',
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
               _buildExportOption(
                 context: context,
                 title: 'Export to CSV',
                 subtitle: 'Best for Excel or Google Sheets',
                 icon: Icons.table_chart_rounded,
                 color: Colors.green,
                 onTap: () => _handleExport(false),
               ),
               const SizedBox(height: 16),
               _buildExportOption(
                 context: context,
                 title: 'Export to PDF',
                 subtitle: 'Best for printing or sharing',
                 icon: Icons.picture_as_pdf_rounded,
                 color: Colors.redAccent,
                 onTap: () => _handleExport(true),
               ),
             ],
          ],
        ),
      ),
    );
  }

  Widget _buildExportOption({
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
