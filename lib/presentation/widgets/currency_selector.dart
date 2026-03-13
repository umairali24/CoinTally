import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class CurrencyData {
  final String code;
  final String name;
  final String symbol;
  final String flag;

  const CurrencyData({
    required this.code,
    required this.name,
    required this.symbol,
    required this.flag,
  });
}

class CurrencySelector extends StatefulWidget {
  final Function(CurrencyData) onSelected;
  final String? initialSelection;

  const CurrencySelector({
    super.key,
    required this.onSelected,
    this.initialSelection,
  });

  @override
  State<CurrencySelector> createState() => _CurrencySelectorState();

  static const List<CurrencyData> currencies = [
    CurrencyData(code: 'PKR', name: 'Pakistani Rupee', symbol: 'Rs', flag: '🇵🇰'),
    CurrencyData(code: 'USD', name: 'US Dollar', symbol: '\$', flag: '🇺🇸'),
    CurrencyData(code: 'EUR', name: 'Euro', symbol: '€', flag: '🇪🇺'),
    CurrencyData(code: 'GBP', name: 'British Pound', symbol: '£', flag: '🇬🇧'),
    CurrencyData(code: 'AED', name: 'UAE Dirham', symbol: 'د.إ', flag: '🇦🇪'),
    CurrencyData(code: 'SAR', name: 'Saudi Riyal', symbol: 'ر.س', flag: '🇸🇦'),
    CurrencyData(code: 'INR', name: 'Indian Rupee', symbol: '₹', flag: '🇮🇳'),
    CurrencyData(code: 'CAD', name: 'Canadian Dollar', symbol: 'CA\$', flag: '🇨🇦'),
    CurrencyData(code: 'AUD', name: 'Australian Dollar', symbol: 'A\$', flag: '🇦🇺'),
    CurrencyData(code: 'CNY', name: 'Chinese Yuan', symbol: '¥', flag: '🇨🇳'),
    CurrencyData(code: 'JPY', name: 'Japanese Yen', symbol: '¥', flag: '🇯🇵'),
    CurrencyData(code: 'TRY', name: 'Turkish Lira', symbol: '₺', flag: '🇹🇷'),
    CurrencyData(code: 'MYR', name: 'Malaysian Ringgit', symbol: 'RM', flag: '🇲🇾'),
    CurrencyData(code: 'QAR', name: 'Qatari Rial', symbol: 'ر.ق', flag: '🇶🇦'),
    CurrencyData(code: 'KWD', name: 'Kuwaiti Dinar', symbol: 'د.ك', flag: '🇰🇼'),
    CurrencyData(code: 'OMR', name: 'Omani Rial', symbol: 'ر.ع.', flag: '🇴🇲'),
    CurrencyData(code: 'BHD', name: 'Bahraini Dinar', symbol: 'ب.د', flag: '🇧🇭'),
  ];
}

class _CurrencySelectorState extends State<CurrencySelector> {
  late List<CurrencyData> _filteredCurrencies;
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _filteredCurrencies = CurrencySelector.currencies;
  }

  void _filterCurrencies(String query) {
    setState(() {
      _filteredCurrencies = CurrencySelector.currencies
          .where((c) =>
              c.code.toLowerCase().contains(query.toLowerCase()) ||
              c.name.toLowerCase().contains(query.toLowerCase()))
          .toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    final suggested = ['PKR', 'USD', 'EUR', 'GBP'];
    
    // Split into suggested and others
    final suggestedItems = _filteredCurrencies.where((c) => suggested.contains(c.code)).toList();
    final otherItems = _filteredCurrencies.where((c) => !suggested.contains(c.code)).toList();
    
    // Sort others alphabetically
    otherItems.sort((a, b) => a.name.compareTo(b.name));

    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Select Currency',
                style: GoogleFonts.manrope(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close_rounded),
                padding: EdgeInsets.zero,
              ),
            ],
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _searchController,
            onChanged: _filterCurrencies,
            decoration: InputDecoration(
              hintText: 'Search currency...',
              prefixIcon: const Icon(Icons.search_rounded),
              filled: true,
              fillColor: Theme.of(context).cardTheme.color,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 24),
          Expanded(
            child: ListView(
              children: [
                if (suggestedItems.isNotEmpty) ...[
                  Text(
                    'SUGGESTED',
                    style: GoogleFonts.manrope(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: Theme.of(context).colorScheme.primary.withOpacity(0.5),
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ...suggestedItems.map((c) => _buildCurrencyTile(c)),
                  const SizedBox(height: 24),
                ],
                if (otherItems.isNotEmpty) ...[
                  Text(
                    'ALL CURRENCIES',
                    style: GoogleFonts.manrope(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: Theme.of(context).colorScheme.primary.withOpacity(0.5),
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ...otherItems.map((c) => _buildCurrencyTile(c)),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCurrencyTile(CurrencyData currency) {
    final isSelected = widget.initialSelection == currency.code;
    return InkWell(
      onTap: () => widget.onSelected(currency),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? Theme.of(context).colorScheme.primary.withOpacity(0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          border: isSelected 
              ? Border.all(color: Theme.of(context).colorScheme.primary.withOpacity(0.3))
              : null,
        ),
        child: Row(
          children: [
            Text(
              currency.flag,
              style: const TextStyle(fontSize: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    currency.name,
                    style: GoogleFonts.manrope(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                  ),
                  Text(
                    '${currency.code} • ${currency.symbol}',
                    style: GoogleFonts.manrope(
                      fontSize: 12,
                      color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.5),
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              Icon(Icons.check_circle_rounded, color: Theme.of(context).colorScheme.primary, size: 20),
          ],
        ),
      ),
    );
  }
}
