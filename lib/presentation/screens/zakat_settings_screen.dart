import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cointally/domain/entities/zakat_models.dart';
import 'package:cointally/presentation/notifiers/zakat_preference_notifier.dart';

class ZakatSettingsScreen extends ConsumerWidget {
  const ZakatSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(zakatPreferenceProvider);
    final notifier = ref.read(zakatPreferenceProvider.notifier);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          'Zakaat Preferences',
          style: GoogleFonts.manrope(fontWeight: FontWeight.w700),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionHeader(context, 'Calculation Standard'),
            const SizedBox(height: 16),
            _buildDropdownTile<NisabStandard>(
              context: context,
              title: 'Nisab Standard',
              subtitle: 'Silver is generally recommended for cash to benefit the poor.',
              icon: Icons.balance_rounded,
              value: state.nisabStandard,
              items: const [
                DropdownMenuItem(value: NisabStandard.gold, child: Text('Gold (7.5 Tolas)')),
                DropdownMenuItem(value: NisabStandard.silver, child: Text('Silver (52.5 Tolas)')),
              ],
              onChanged: (val) {
                if (val != null) notifier.setNisabStandard(val);
              },
            ),
            const SizedBox(height: 32),
            _buildSectionHeader(context, 'Islamic Jurisprudence'),
            const SizedBox(height: 16),
            _buildDropdownTile<FiqhSchool>(
              context: context,
              title: 'School of Thought (Fiqh)',
              subtitle: 'Determines exemptions like personal jewelry.',
              icon: Icons.menu_book_rounded,
              value: state.fiqhSchool,
              items: const [
                DropdownMenuItem(value: FiqhSchool.hanafi, child: Text('Hanafi')),
                DropdownMenuItem(value: FiqhSchool.shafii, child: Text('Shafi\'i')),
                DropdownMenuItem(value: FiqhSchool.maliki, child: Text('Maliki')),
                DropdownMenuItem(value: FiqhSchool.hanbali, child: Text('Hanbali')),
              ],
              onChanged: (val) {
                if (val != null) notifier.setFiqhSchool(val);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    return Text(
      title,
      style: GoogleFonts.manrope(
        fontSize: 14,
        fontWeight: FontWeight.w800,
        color: Theme.of(context).colorScheme.primary,
        letterSpacing: 1.2,
      ),
    );
  }

  Widget _buildDropdownTile<T>({
    required BuildContext context,
    required String title,
    required String subtitle,
    required IconData icon,
    required T value,
    required List<DropdownMenuItem<T>> items,
    required ValueChanged<T?> onChanged,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.05) ?? Colors.white.withOpacity(0.05),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Row(
        children: [
          Icon(icon, color: Theme.of(context).colorScheme.primary, size: 28),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.manrope(
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).textTheme.bodyLarge?.color,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: GoogleFonts.manrope(
                    fontSize: 12,
                    color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.6),
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).scaffoldBackgroundColor,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<T>(
                      value: value,
                      isExpanded: true,
                      dropdownColor: Theme.of(context).cardTheme.color,
                      style: GoogleFonts.manrope(
                        color: Theme.of(context).textTheme.bodyLarge?.color,
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                      icon: Icon(Icons.keyboard_arrow_down_rounded, color: Theme.of(context).colorScheme.primary),
                      items: items,
                      onChanged: onChanged,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
