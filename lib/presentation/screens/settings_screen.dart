import 'dart:async'; // For Timer if needed, though not used yet
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cointally/core/services/notification_service.dart';
import 'package:cointally/presentation/notifiers/locale_notifier.dart';
import 'package:cointally/presentation/notifiers/theme_notifier.dart';
import 'package:cointally/presentation/screens/category_management_screen.dart';
import 'package:cointally/presentation/screens/goal_list_screen.dart';
import 'package:cointally/presentation/screens/auto_detection_settings_screen.dart';
import 'package:cointally/presentation/screens/notification_settings_screen.dart';
import 'package:cointally/presentation/screens/format_settings_screen.dart';
import 'package:cointally/presentation/screens/backup_settings_screen.dart';
import 'package:cointally/presentation/screens/export_settings_screen.dart';
import 'package:cointally/presentation/screens/import_settings_screen.dart';
import 'package:cointally/presentation/notifiers/feature_notifier.dart';
import 'package:cointally/presentation/notifiers/currency_notifier.dart';
import 'package:cointally/presentation/notifiers/security_notifier.dart';
import 'package:cointally/presentation/screens/dashboard_settings_screen.dart';
import 'package:cointally/presentation/screens/zakat_settings_screen.dart';

import 'package:cointally/presentation/widgets/currency_selector.dart';
import 'package:cointally/presentation/widgets/sleek_components.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final localeNotifier = ref.read(localeProvider.notifier);
    final currentLocale = ref.watch(localeProvider);
    final themeMode = ref.watch(themeProvider);
    final themeNotifier = ref.read(themeProvider.notifier);
    final currencyState = ref.watch(currencyNotifierProvider);
    final currencyNotifier = ref.read(currencyNotifierProvider.notifier);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(localeNotifier.translate('settings'), style: GoogleFonts.manrope(fontWeight: FontWeight.w700)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionHeader(context, localeNotifier.translate('preferences')),
            const SizedBox(height: 16),
            _buildSettingTile(
              context,
              localeNotifier.translate('theme'),
              themeMode.name.toUpperCase(),
              Icons.palette_rounded,
              () => _showThemeDialog(context, themeNotifier, themeMode),
            ),
            _buildSettingTile(
              context,
              localeNotifier.translate('language'),
              currentLocale == 'en' ? 'English' : 'اردو',
              Icons.language_rounded,
              () => localeNotifier.toggleLocale(),
            ),
            _buildSettingTile(
              context,
              localeNotifier.translate('primary_currency'),
              currencyState.primaryCurrency,
              Icons.monetization_on_rounded,
              () => _showCurrencyPickerDialog(context, currencyNotifier, currencyState.primaryCurrency),
            ),
            _buildSettingTile(
              context,
              'Number & Currency Formatting',
              'Customize decimals & symbols',
              Icons.numbers_rounded,
              () => Navigator.push(context, MaterialPageRoute(builder: (_) => const FormatSettingsScreen())),
            ),
            _buildSettingTile(
              context,
              'Dashboard Customization',
              'Arrange and toggle widgets',
              Icons.dashboard_customize_rounded,
              () => Navigator.push(context, MaterialPageRoute(builder: (_) => const DashboardSettingsScreen())),
            ),
            _buildSettingTile(
              context,
              localeNotifier.translate('categories'),
              '',
              Icons.category_rounded,
              () => Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const CategoryManagementScreen()),
              ),
            ),
            _buildSettingTile(
              context,
              localeNotifier.translate('financial_goals'),
              '',
              Icons.flag_rounded,
              () => Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const GoalListScreen()),
              ),
            ),
            _buildSettingTile(
              context,
              localeNotifier.translate('notifications'),
              '',
              Icons.notifications_active_rounded,
              () => Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const NotificationSettingsScreen()),
              ),
            ),
            
            const SizedBox(height: 32),
            _buildSectionHeader(context, localeNotifier.translate('features')),
            const SizedBox(height: 16),
            _buildSettingTile(
              context,
              localeNotifier.translate('auto_detection'),
              '',
              Icons.auto_awesome_rounded,
              () => Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const AutoDetectionSettingsScreen()),
              ),
            ),
            const SizedBox(height: 16),
            _buildFeatureSwitch(
              context,
              ref,
              localeNotifier.translate('zakat_estimator_title'),
              localeNotifier.translate('zakat_estimator_desc'),
              Icons.calculate_rounded,
              ref.watch(featureProvider).isZakatEnabled,
              (val) => ref.read(featureProvider.notifier).toggleZakat(val),
            ),
            
            const SizedBox(height: 16),
            if (ref.watch(featureProvider).isZakatEnabled) ...[
              _buildSettingTile(
                context,
                'Zakaat Preferences',
                'Nisab & Fiqh School',
                Icons.balance_rounded,
                () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const ZakatSettingsScreen()),
                ),
              ),
              const SizedBox(height: 16),
            ],
            
            const SizedBox(height: 32),
            _buildSectionHeader(context, localeNotifier.translate('security')),
            const SizedBox(height: 16),
            _buildFeatureSwitch(
              context,
              ref,
              localeNotifier.translate('biometric_lock'),
              localeNotifier.translate('biometric_lock_desc'),
              Icons.fingerprint_rounded,
              ref.watch(securityProvider).isBiometricEnabled,
              (val) => ref.read(securityProvider.notifier).toggleBiometric(val),
            ),
            
            const SizedBox(height: 32),
            _buildSectionHeader(context, localeNotifier.translate('data_management')),
            const SizedBox(height: 16),
            _buildSettingTile(
              context,
              localeNotifier.translate('import_data'),
              'CSV Template Upload',
              Icons.upload_file_rounded,
              () => Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const ImportSettingsScreen()),
              ),
            ),
            _buildSettingTile(
              context,
              localeNotifier.translate('export_data'),
              localeNotifier.translate('csv_pdf'),
              Icons.file_download_rounded,
              () => Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const ExportSettingsScreen()),
              ),
            ),
            _buildSettingTile(
              context,
              localeNotifier.translate('backup_restore'),
              localeNotifier.translate('cloud_sync'),
              Icons.cloud_sync_rounded,
              () => Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const BackupSettingsScreen()),
              ),
            ),

            const SizedBox(height: 32),
            _buildSectionHeader(context, localeNotifier.translate('about')),
            const SizedBox(height: 16),
            _buildSettingTile(
              context,
              localeNotifier.translate('version'),
              '2.0.0 Premium',
              Icons.info_outline_rounded,
              null,
            ),
            _buildSettingTile(
              context,
              localeNotifier.translate('terms'),
              '',
              Icons.description_rounded,
              () {},
            ),
            _buildSettingTile(
              context,
              localeNotifier.translate('privacy'),
              '',
              Icons.privacy_tip_rounded,
              () {},
            ),
            
            const SizedBox(height: 48),
            Center(
              child: Text(
                localeNotifier.translate('made_with_heart'),
                style: GoogleFonts.manrope(
                  color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.2),
                  fontSize: 12,
                ),
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  void _showCurrencyPickerDialog(BuildContext context, CurrencyNotifier notifier, String currentSelection) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => CurrencySelector(
        initialSelection: currentSelection,
        onSelected: (currency) {
          notifier.updatePrimaryCurrency(currency.code);
          Navigator.pop(context);
        },
      ),
    );
  }

  Widget _buildFeatureSwitch(
    BuildContext context,
    WidgetRef ref,
    String title,
    String subtitle,
    IconData icon,
    bool value,
    Function(bool) onChanged,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.05) ?? Colors.white.withOpacity(0.05)),
      ),
      child: SwitchListTile(
        value: value,
        onChanged: onChanged,
        secondary: Icon(icon, color: Theme.of(context).colorScheme.primary, size: 24),
        title: Text(
          title,
          style: GoogleFonts.manrope(
            fontWeight: FontWeight.w600,
            color: Theme.of(context).textTheme.bodyLarge?.color,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: GoogleFonts.manrope(
            fontSize: 12,
            color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.4),
          ),
        ),
        activeColor: Theme.of(context).colorScheme.primary,
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      ),
    );
  }

  Widget _buildSettingTile(
    BuildContext context,
    String title,
    String value,
    IconData icon,
    VoidCallback? onTap,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Theme.of(context).cardTheme.color,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.05) ?? Colors.white.withOpacity(0.05)),
            ),
            child: Row(
              children: [
                Icon(icon, color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.4), size: 24),
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
                        ),
                      ),
                      if (value.isNotEmpty)
                        Text(
                          value,
                          style: GoogleFonts.manrope(
                            color: Theme.of(context).colorScheme.primary,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                    ],
                  ),
                ),
                if (onTap != null) ...[
                  const SizedBox(width: 8),
                  Icon(Icons.chevron_right_rounded, color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.2), size: 18),
                ],
              ],
            ),
          ),
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

  void _showThemeDialog(BuildContext context, ThemeNotifier notifier, ThemeMode current) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Choose Theme'),
        backgroundColor: Theme.of(context).cardTheme.color,
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: ThemeMode.values.map((mode) {
            return RadioListTile<ThemeMode>(
              title: Text(mode.name.toUpperCase(), style: GoogleFonts.manrope()),
              value: mode,
              groupValue: current,
              activeColor: Theme.of(context).colorScheme.primary,
              onChanged: (val) {
                if (val != null) {
                  notifier.setThemeMode(val);
                  Navigator.pop(context);
                }
              },
            );
          }).toList(),
        ),
      ),
    );
  }
}
