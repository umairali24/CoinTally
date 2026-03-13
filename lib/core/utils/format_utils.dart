import 'package:intl/intl.dart';
import 'package:cointally/presentation/notifiers/format_preferences_notifier.dart';

class FormatUtils {
  /// Formats an amount as a currency string respecting user preferences.
  static String formatCurrency(
    double amount, {
    required FormatPreferencesState prefs,
    required String symbol,
    bool forceDecimals = true, // Sometimes we always want to show decimals even if short format is off
  }) {
    String formattedAmount;

    if (prefs.useShortNumberFormat && amount >= 1000) {
      // Short format logic
      if (amount >= 1000000000) {
        formattedAmount = '${(amount / 1000000000).toStringAsFixed(prefs.decimalPrecision)}B';
      } else if (amount >= 1000000) {
        formattedAmount = '${(amount / 1000000).toStringAsFixed(prefs.decimalPrecision)}M';
      } else {
        formattedAmount = '${(amount / 1000).toStringAsFixed(prefs.decimalPrecision)}K';
      }
      
      // Clean up e.g., '1.0K' to '1K' if precision allows it
      if (formattedAmount.contains('.') && formattedAmount.endsWith('0' + formattedAmount[formattedAmount.length-1])) {
         // This is a basic cleanup, but Dart's toStringAsFixed handles the requested precision.
         // If they ask for 1 precision, it will be 1.0K. If they ask for 0, it's 1K.
      }
    } else {
      // Standard comma-separated format
      final decimalPlaces = forceDecimals ? 2 : 0;
      final formatPattern = decimalPlaces > 0 ? '#,##0.${'0' * decimalPlaces}' : '#,##0';
      formattedAmount = NumberFormat(formatPattern).format(amount);
    }

    if (prefs.showCurrencySymbol) {
      return '$symbol $formattedAmount';
    } else {
      return formattedAmount;
    }
  }

  /// Formats a decimal percentage (e.g., 0.1567) into a display string (e.g., "15.7%").
  static String formatPercentage(double decimalPercentage, {required FormatPreferencesState prefs}) {
    final percentage = decimalPercentage * 100;
    return '${percentage.toStringAsFixed(prefs.decimalPrecision)}%';
  }
}
