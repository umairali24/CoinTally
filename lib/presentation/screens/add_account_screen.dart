import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cointally/core/utils/bank_utils.dart';
import 'package:cointally/domain/entities/account_entity.dart';
import 'package:cointally/presentation/notifiers/account_notifier.dart';
import 'package:cointally/presentation/notifiers/locale_notifier.dart';
import 'package:cointally/presentation/widgets/sleek_components.dart';
import 'package:cointally/presentation/widgets/currency_selector.dart';
import 'package:intl/intl.dart';
import 'dart:io';
import 'package:flutter_svg/flutter_svg.dart';

class AddAccountScreen extends ConsumerStatefulWidget {
  final AccountEntity? existingAccount;
  const AddAccountScreen({super.key, this.existingAccount});

  @override
  ConsumerState<AddAccountScreen> createState() => _AddAccountScreenState();
}

class _AddAccountScreenState extends ConsumerState<AddAccountScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _balanceController = TextEditingController(text: '0');
  final _limitController = TextEditingController(text: '0');
  
  String? _selectedLogo;
  String _accountType = 'BANK'; // BANK or CREDIT_CARD
  String _selectedCurrency = 'PKR';
  String? _selectedColorHex;
  
  final List<String> _colorPalette = [
    '#008477', '#8c1d3f', '#019b4c', '#0055a4', '#d32f2f', 
    '#1976d2', '#388e3c', '#f57c00', '#7b1fa2', '#13ec13', '#607d8b'
  ];

  int _billPaymentDate = 1;
  bool _enableReminder = false;

  @override
  void initState() {
    super.initState();
    if (widget.existingAccount != null) {
      final acc = widget.existingAccount!;
      _nameController.text = acc.bankName;
      _balanceController.text = acc.balance.toStringAsFixed(2);
      _limitController.text = acc.creditLimit.toStringAsFixed(2);
      _accountType = acc.accountType;
      _selectedCurrency = acc.currencyCode;
      _selectedColorHex = acc.themeColor;
      if (acc.logoAssetPath != null && acc.logoAssetPath!.isNotEmpty) {
        _selectedLogo = acc.logoAssetPath!.split('/').last;
      }
      if (acc.accountType == 'CREDIT_CARD') {
        _billPaymentDate = acc.billPaymentDate ?? 1;
        _enableReminder = acc.enableReminder;
      }
    } else {
      _detectDefaultCurrency();
    }
  }

  void _detectDefaultCurrency() {
    try {
      final locale = Platform.localeName;
      
      // Explicit check for Pakistan as it's a primary target and common locale issue
      if (locale.toUpperCase().contains('PK')) {
        setState(() {
          _selectedCurrency = 'PKR';
        });
        return;
      }

      final format = NumberFormat.simpleCurrency(locale: locale);
      if (format.currencyName != null && format.currencyName != 'USD') {
        setState(() {
          _selectedCurrency = format.currencyName!;
        });
      } else if (format.currencyName == 'USD' && !locale.toUpperCase().contains('US')) {
        // If it's returning USD but the locale isn't explicitly US, keep PKR as the safer local default for this app
        setState(() {
          _selectedCurrency = 'PKR';
        });
      }
    } catch (e) {
      // Fallback already set to PKR
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _balanceController.dispose();
    _limitController.dispose();
    super.dispose();
  }

  void _submit() {
    if (_formKey.currentState!.validate()) {
      if (_selectedLogo == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select a bank.')),
        );
        return;
      }

      final balance = double.tryParse(_balanceController.text) ?? 0.0;
      final limit = _accountType == 'CREDIT_CARD' ? (double.tryParse(_limitController.text) ?? 0.0) : 0.0;

      if (_accountType == 'CREDIT_CARD' && balance > limit) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Used balance cannot exceed credit limit.'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      final account = AccountEntity(
        id: widget.existingAccount?.id,
        bankName: _nameController.text,
        balance: balance,
        logoAssetPath: 'assets/banks/$_selectedLogo',
        accountType: _accountType,
        themeColor: _selectedColorHex ?? _getThemeColorForBank(_selectedLogo!),
        creditLimit: limit,
        currencyCode: _selectedCurrency,
        isDefault: widget.existingAccount?.isDefault ?? false,
        billPaymentDate: _accountType == 'CREDIT_CARD' ? _billPaymentDate : null,
        enableReminder: _accountType == 'CREDIT_CARD' ? _enableReminder : false,
      );

      if (widget.existingAccount != null) {
        ref.read(accountProvider.notifier).updateAccount(account);
      } else {
        ref.read(accountProvider.notifier).addAccount(account);
      }
      Navigator.pop(context);
    }
  }

  String _getThemeColorForBank(String logo) {
    if (logo.contains('hbl')) return '#008477';
    if (logo.contains('meezan')) return '#8c1d3f';
    if (logo.contains('mcb')) return '#019b4c';
    if (logo.contains('ubl')) return '#0055a4';
    if (logo.contains('faysal')) return '#003D7A';
    if (logo.contains('alfalah')) return '#D4111E';
    if (logo.contains('allied')) return '#E26027';
    if (logo.contains('askari')) return '#FABF00';
    if (logo.contains('naya_pay') || logo.contains('nayapay')) return '#FF5A00';
    if (logo.contains('sada_pay') || logo.contains('sadapay')) return '#1E88E5';
    if (logo.contains('jazz_cash') || logo.contains('jazzcash')) return '#ED1C24';
    if (logo.contains('easy_paisa') || logo.contains('easypaisa')) return '#00A651';
    if (logo.contains('standard_chartered')) return '#009EB3';
    if (logo.contains('wallet')) return '#13ec13';
    return '#009688';
  }

  void _showCurrencyPicker() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => CurrencySelector(
        initialSelection: _selectedCurrency,
        onSelected: (currency) {
          setState(() {
            _selectedCurrency = currency.code;
          });
          Navigator.pop(context);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isCC = _accountType == 'CREDIT_CARD';

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(widget.existingAccount != null ? 'Edit Asset' : 'Add Asset', style: GoogleFonts.manrope(fontWeight: FontWeight.w700)),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(24.0),
          children: [
            // Account Type Selector
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: const Color(0xFF1A1A1A),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  _buildTypeTab('Bank Account', 'BANK', Icons.account_balance_rounded),
                  _buildTypeTab('Credit Card', 'CREDIT_CARD', Icons.credit_card_rounded),
                ],
              ),
            ),
            const SizedBox(height: 32),

            // Bank Search Picker
            Text(
              'Select Provider',
              style: GoogleFonts.manrope(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.4),
              ),
            ),
            const SizedBox(height: 12),
            SearchAnchor(
              builder: (context, controller) {
                return GestureDetector(
                  onTap: () => controller.openView(),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                    decoration: BoxDecoration(
                      color: Theme.of(context).cardTheme.color,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.05) ?? Colors.white.withOpacity(0.05)),
                    ),
                    child: Row(
                      children: [
                        if (_selectedLogo != null)
                          Container(
                            margin: const EdgeInsets.only(right: 12),
                            child: BankUtils.getLogoWidget(
                              'assets/banks/$_selectedLogo',
                              size: 24,
                              bankName: BankUtils.getDisplayName(_selectedLogo!),
                            ),
                          )
                        else
                          Icon(
                            Icons.search_rounded,
                            color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.3),
                          ),
                        const SizedBox(width: 12),
                        Text(
                          _selectedLogo != null ? BankUtils.getDisplayName(_selectedLogo!) : 'Search bank...',
                          style: GoogleFonts.manrope(
                            color: _selectedLogo != null ? Theme.of(context).textTheme.bodyLarge?.color : Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.3),
                            fontWeight: _selectedLogo != null ? FontWeight.w600 : FontWeight.w400,
                          ),
                        ),
                        const Spacer(),
                        Icon(Icons.keyboard_arrow_down_rounded, color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.2)),
                      ],
                    ),
                  ),
                );
              },
              viewBackgroundColor: Theme.of(context).cardTheme.color,
              suggestionsBuilder: (context, controller) {
                final query = controller.text.toLowerCase();
                final filteredBanks = BankUtils.bankLogos.where((logo) {
                  return BankUtils.getDisplayName(logo).toLowerCase().contains(query);
                }).toList();

                final suggestions = [
                  ...filteredBanks.map((logo) => ListTile(
                    leading: Container(
                      width: 32,
                      height: 32,
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.05),
                        shape: BoxShape.circle,
                      ),
                      child: BankUtils.getLogoWidget(
                        'assets/banks/$logo',
                        color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.3),
                        bankName: BankUtils.getDisplayName(logo),
                      ),
                    ),
                    title: Text(BankUtils.getDisplayName(logo), style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color)),
                    onTap: () {
                      setState(() {
                        _selectedLogo = logo;
                        _nameController.text = BankUtils.getDisplayName(logo);
                        _selectedColorHex = _getThemeColorForBank(logo);
                        controller.closeView(BankUtils.getDisplayName(logo));
                      });
                    },
                  )),
                  ListTile(
                    leading: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.05),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.account_balance_outlined, size: 20, color: Theme.of(context).colorScheme.primary),
                    ),
                    title: Text('Other (Custom Bank)', style: TextStyle(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.bold)),
                    onTap: () {
                      setState(() {
                        _selectedLogo = 'other.svg';
                        _nameController.clear();
                        controller.closeView('Other');
                      });
                    },
                  ),
                ];

                return suggestions;
              },
            ),
            const SizedBox(height: 24),

            // Theme Color Picker
            Text(
              'Theme Color',
              style: GoogleFonts.manrope(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.4),
              ),
            ),
            const SizedBox(height: 12),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: _colorPalette.map((hex) {
                  final color = Color(int.parse(hex.replaceFirst('#', '0xFF')));
                  final currentDetectedColor = _selectedLogo != null ? _getThemeColorForBank(_selectedLogo!) : null;
                  final isSelected = _selectedColorHex == hex || (_selectedColorHex == null && currentDetectedColor?.toLowerCase() == hex.toLowerCase());
                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        _selectedColorHex = hex;
                      });
                    },
                    child: Container(
                      margin: const EdgeInsets.only(right: 12),
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                        border: isSelected ? Border.all(color: Colors.white, width: 3) : null,
                      ),
                      child: isSelected ? const Icon(Icons.check, color: Colors.white, size: 20) : null,
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 24),

            // Currency Selector
            Text(
              'Default Currency',
              style: GoogleFonts.manrope(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.4),
              ),
            ),
            const SizedBox(height: 12),
            GestureDetector(
              onTap: _showCurrencyPicker,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                decoration: BoxDecoration(
                  color: Theme.of(context).cardTheme.color,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.05) ?? Colors.white.withOpacity(0.05)),
                ),
                child: Row(
                  children: [
                    Text(
                      CurrencySelector.currencies.firstWhere((c) => c.code == _selectedCurrency, orElse: () => CurrencySelector.currencies.first).flag,
                      style: const TextStyle(fontSize: 20),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      '$_selectedCurrency - ${CurrencySelector.currencies.firstWhere((c) => c.code == _selectedCurrency, orElse: () => CurrencySelector.currencies.first).name}',
                      style: GoogleFonts.manrope(
                        color: Theme.of(context).textTheme.bodyLarge?.color,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const Spacer(),
                    Icon(Icons.keyboard_arrow_down_rounded, color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.2)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            SleekTextField(
              label: 'Display Name',
              hintText: 'e.g. My Salary Account',
              controller: _nameController,
              prefixIcon: Icons.edit_rounded,
            ),
            const SizedBox(height: 24),

            if (isCC) ...[
              SleekTextField(
                label: 'Credit Limit',
                hintText: '0.00',
                controller: _limitController,
                prefixIcon: Icons.speed_rounded,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))],
              ),
              const SizedBox(height: 24),
              SleekTextField(
                label: 'Currently Used',
                hintText: '0.00',
                controller: _balanceController,
                prefixIcon: Icons.trending_up_rounded,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))],
              ),
              const SizedBox(height: 24),
              // Bill Payment Date Dropdown
              Text(
                'Bill Payment Date',
                style: GoogleFonts.manrope(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.4),
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: Theme.of(context).cardTheme.color,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.05) ?? Colors.white.withOpacity(0.05)),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<int>(
                    value: _billPaymentDate,
                    isExpanded: true,
                    dropdownColor: Theme.of(context).cardTheme.color,
                    icon: Icon(Icons.keyboard_arrow_down_rounded, color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.2)),
                    items: List.generate(28, (index) {
                      return DropdownMenuItem(
                        value: index + 1,
                        child: Text(
                          '${index + 1}',
                          style: GoogleFonts.manrope(
                            color: Theme.of(context).textTheme.bodyLarge?.color,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      );
                    }),
                    onChanged: (val) {
                      if (val != null) {
                        setState(() {
                          _billPaymentDate = val;
                        });
                      }
                    },
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Remind Me Monthly',
                    style: GoogleFonts.manrope(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).textTheme.bodyLarge?.color,
                    ),
                  ),
                  Switch(
                    value: _enableReminder,
                    onChanged: (val) {
                      setState(() {
                        _enableReminder = val;
                      });
                    },
                    activeColor: Theme.of(context).colorScheme.primary,
                  ),
                ],
              ),
            ] else ...[
              SleekTextField(
                label: 'Initial Balance',
                hintText: '0.00',
                controller: _balanceController,
                prefixIcon: Icons.account_balance_wallet_rounded,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))],
              ),
            ],
            const SizedBox(height: 48),

            NeonButton(
              text: widget.existingAccount != null ? 'Save Changes' : 'Save Asset',
              onPressed: _submit,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTypeTab(String label, String value, IconData icon) {
    final isSelected = _accountType == value;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _accountType = value),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? Theme.of(context).colorScheme.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 18,
                  color: isSelected ? Colors.black : Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.3),
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: GoogleFonts.manrope(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: isSelected ? Colors.black : Colors.white.withOpacity(0.3),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
