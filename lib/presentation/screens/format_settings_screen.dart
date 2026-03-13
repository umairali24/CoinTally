import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cointally/presentation/widgets/sleek_components.dart';
import 'package:cointally/presentation/notifiers/format_preferences_notifier.dart';
import 'package:cointally/presentation/notifiers/currency_notifier.dart';
import 'package:cointally/core/utils/format_utils.dart';

class FormatSettingsScreen extends ConsumerWidget {
  const FormatSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final formatPrefs = ref.watch(formatPreferencesProvider);
    final currencyPrefs = ref.watch(currencyNotifierProvider);

    // Mock values for preview
    final previewAmount = 1450000.75;
    final previewPercentage = 0.1567; // 15.67%

    final formattedCurrency = FormatUtils.formatCurrency(
      previewAmount, 
      prefs: formatPrefs, 
      symbol: currencyPrefs?.primaryCurrency ?? 'PKR',
    );
    
    final formattedPercent = FormatUtils.formatPercentage(
      previewPercentage, 
      prefs: formatPrefs,
    );

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.background,
      appBar: AppBar(
        title: Text(
          'Format Preferences',
          style: GoogleFonts.manrope(
            fontWeight: FontWeight.w700,
            color: Theme.of(context).textTheme.titleLarge?.color,
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          // Live Preview Card
          PremiumCard(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Icon(Icons.visibility_rounded, color: Theme.of(context).colorScheme.primary, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'Live Preview',
                      style: GoogleFonts.manrope(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Theme.of(context).textTheme.bodyMedium?.color?.withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Balance', style: GoogleFonts.manrope(fontWeight: FontWeight.w500)),
                    Text(formattedCurrency, style: GoogleFonts.manrope(fontWeight: FontWeight.w800, fontSize: 18)),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Growth', style: GoogleFonts.manrope(fontWeight: FontWeight.w500)),
                    Text(formattedPercent, style: GoogleFonts.manrope(fontWeight: FontWeight.w800, fontSize: 18, color: Colors.green)),
                  ],
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 32),
          
          Text(
            'Options',
            style: GoogleFonts.manrope(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Theme.of(context).textTheme.bodyLarge?.color,
            ),
          ),
          const SizedBox(height: 16),
          
          // Toggle Short Number Format
          SwitchListTile(
            title: Text('Short Number Format', style: GoogleFonts.manrope(fontWeight: FontWeight.w600)),
            subtitle: Text('e.g., 1M instead of 1,000,000', style: GoogleFonts.manrope(fontSize: 12)),
            value: formatPrefs.useShortNumberFormat,
            activeColor: Theme.of(context).colorScheme.primary,
            contentPadding: EdgeInsets.zero,
            onChanged: (bool value) {
              ref.read(formatPreferencesProvider.notifier).setUseShortNumberFormat(value);
            },
          ),
          
          const Divider(height: 32),
          
          // Toggle Currency Symbol
          SwitchListTile(
            title: Text('Show Currency Symbol', style: GoogleFonts.manrope(fontWeight: FontWeight.w600)),
            subtitle: Text('Show ${currencyPrefs?.primaryCurrency ?? "PKR"} next to amounts', style: GoogleFonts.manrope(fontSize: 12)),
            value: formatPrefs.showCurrencySymbol,
            activeColor: Theme.of(context).colorScheme.primary,
            contentPadding: EdgeInsets.zero,
            onChanged: (bool value) {
              ref.read(formatPreferencesProvider.notifier).setShowCurrencySymbol(value);
            },
          ),
          
          const Divider(height: 32),
          
          // Decimal Precision Selector
          Text('Decimal Precision', style: GoogleFonts.manrope(fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text(
            'Number of decimal places (0-2)', 
            style: GoogleFonts.manrope(fontSize: 12, color: Theme.of(context).textTheme.bodyMedium?.color?.withValues(alpha: 0.6))
          ),
          const SizedBox(height: 16),
          SegmentedButton<int>(
            segments: const [
              ButtonSegment<int>(value: 0, label: Text('0')),
              ButtonSegment<int>(value: 1, label: Text('1')),
              ButtonSegment<int>(value: 2, label: Text('2')),
            ],
            selected: {formatPrefs.decimalPrecision},
            onSelectionChanged: (Set<int> newSelection) {
              if (newSelection.isNotEmpty) {
                ref.read(formatPreferencesProvider.notifier).setDecimalPrecision(newSelection.first);
              }
            },
            style: SegmentedButton.styleFrom(
              selectedForegroundColor: Colors.white,
              selectedBackgroundColor: Theme.of(context).colorScheme.primary,
            ),
          ),
        ],
      ),
    );
  }
}
