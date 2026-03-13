import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cointally/presentation/notifiers/account_notifier.dart';
import 'package:cointally/presentation/notifiers/account_detail_notifier.dart';
import 'package:cointally/presentation/notifiers/locale_notifier.dart';
import 'package:cointally/presentation/screens/add_account_screen.dart';
import 'package:cointally/presentation/screens/account_detail_screen.dart';
import 'package:cointally/presentation/widgets/sleek_components.dart';
import 'package:cointally/presentation/widgets/growth_chart_card.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:cointally/core/utils/bank_utils.dart';
import 'package:cointally/presentation/notifiers/person_notifier.dart';
import 'package:cointally/presentation/notifiers/debt_notifier.dart';
import 'package:cointally/presentation/notifiers/transaction_notifier.dart';
import 'package:cointally/presentation/notifiers/currency_notifier.dart';
import 'package:cointally/presentation/widgets/currency_selector.dart';
import 'package:cointally/presentation/notifiers/format_preferences_notifier.dart';
import 'package:cointally/core/utils/format_utils.dart';

class AccountListScreen extends ConsumerStatefulWidget {
  const AccountListScreen({super.key});

  @override
  ConsumerState<AccountListScreen> createState() => _AccountListScreenState();
}

class _AccountListScreenState extends ConsumerState<AccountListScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(transactionProvider.notifier).loadData();
    });
  }

  @override
  Widget build(BuildContext context) {
    final accountState = ref.watch(accountProvider);
    final personState = ref.watch(personProvider);
    final transactionState = ref.watch(transactionProvider);
    final debtNotifier = ref.read(debtProvider.notifier);
    ref.watch(debtProvider); // Rebuild when debts change

    final totalWorth = transactionState.totalBalance;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text('My Assets', style: GoogleFonts.manrope(fontWeight: FontWeight.w700)),
      ),
      body: accountState.isLoading
          ? Center(child: CircularProgressIndicator(color: Theme.of(context).colorScheme.primary))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Total Portfolio Card
                  PremiumCard(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.account_balance_wallet_rounded,
                              color: Theme.of(context).colorScheme.primary.withOpacity(0.6),
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Portfolio Net Worth',
                              style: GoogleFonts.manrope(
                                color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.4),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Builder(
                          builder: (context) {
                            final currencyState = ref.watch(currencyNotifierProvider);
                            final formatPrefs = ref.watch(formatPreferencesProvider);
                            final currencyData = CurrencySelector.currencies.firstWhere(
                              (c) => c.code == currencyState.primaryCurrency,
                              orElse: () => CurrencySelector.currencies.first,
                            );
                            return Text(
                              FormatUtils.formatCurrency(totalWorth, prefs: formatPrefs, symbol: currencyData.symbol, forceDecimals: false),
                              style: GoogleFonts.manrope(
                                fontSize: 32,
                                fontWeight: FontWeight.w800,
                                color: Theme.of(context).textTheme.displayLarge?.color,
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Includes Cash, Bank & Debts',
                          style: GoogleFonts.manrope(
                            fontSize: 10,
                            color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.2),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),
                  
                  // Growth Chart
                  GrowthChartCard(
                    currentBalance: totalWorth,
                    transactions: transactionState.transactions,
                    isPortfolio: true,
                  ),

                  const SizedBox(height: 32),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Accounts & Cards',
                        style: GoogleFonts.manrope(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Theme.of(context).textTheme.titleLarge?.color,
                        ),
                      ),
                      TextButton.icon(
                        onPressed: () {
                          Navigator.push(context, MaterialPageRoute(builder: (context) => const AddAccountScreen()));
                        },
                        icon: Icon(Icons.add_rounded, size: 18, color: Theme.of(context).colorScheme.primary),
                        label: Text('Add', style: GoogleFonts.manrope(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.bold, fontSize: 13)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  if (accountState.accounts.isEmpty)
                    _buildEmptyState(context)
                    else
                    ...accountState.accounts.map((account) {
                      final isCreditCard = account.accountType == 'CREDIT_CARD';
                      final accountDetail = ref.watch(accountDetailProvider(account.id!));
                      final dynamicBalance = accountDetail.balance;

                      return Container(
                        margin: const EdgeInsets.only(bottom: 16),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () => Navigator.push(
                              context, 
                              MaterialPageRoute(builder: (context) => AccountDetailScreen(account: account))
                            ),
                            borderRadius: BorderRadius.circular(20),
                            child: Container(
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                color: Theme.of(context).cardTheme.color,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.05) ?? Colors.white.withOpacity(0.05)),
                              ),
                              child: Column(
                                children: [
                                  Row(
                                    children: [
                                        Container(
                                          padding: const EdgeInsets.all(12),
                                          decoration: BoxDecoration(
                                            color: (isCreditCard ? Colors.red : Theme.of(context).colorScheme.primary).withOpacity(0.1),
                                            shape: BoxShape.circle,
                                          ),
                                          child: BankUtils.getLogoWidget(
                                            account.logoAssetPath,
                                            size: 24,
                                            color: isCreditCard ? Colors.red : Theme.of(context).colorScheme.primary,
                                            bankName: account.bankName,
                                          ),
                                        ),
                                      const SizedBox(width: 16),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                Text(
                                                  account.bankName,
                                                  style: GoogleFonts.manrope(
                                                    fontWeight: FontWeight.w700,
                                                    fontSize: 16,
                                                      color: Theme.of(context).textTheme.titleMedium?.color,
                                                  ),
                                                ),
                                                if (account.isDefault) ...[
                                                  const SizedBox(width: 8),
                                                  Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                    decoration: BoxDecoration(
                                                      color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                                                      borderRadius: BorderRadius.circular(4),
                                                      border: Border.all(color: Theme.of(context).colorScheme.primary.withOpacity(0.2)),
                                                    ),
                                                    child: Text(
                                                      'DEFAULT',
                                                      style: GoogleFonts.manrope(
                                                        fontSize: 8,
                                                        fontWeight: FontWeight.w800,
                                                        color: Theme.of(context).colorScheme.primary,
                                                        letterSpacing: 0.5,
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ],
                                            ),
                                            Text(
                                              isCreditCard ? 'Credit Card' : 'Current Account',
                                              style: GoogleFonts.manrope(
                                                fontSize: 12,
                                                color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.3),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.end,
                                        children: [
                                            Consumer(
                                              builder: (context, ref, _) {
                                                final currencyData = CurrencySelector.currencies.firstWhere(
                                                  (c) => c.code == account.currencyCode,
                                                  orElse: () => CurrencySelector.currencies.first,
                                                );
                                                return Column(
                                                  crossAxisAlignment: CrossAxisAlignment.end,
                                                  children: [
                                                    Text(
                                                      FormatUtils.formatCurrency(dynamicBalance, prefs: ref.watch(formatPreferencesProvider), symbol: currencyData.symbol, forceDecimals: false),
                                                      style: GoogleFonts.manrope(
                                                        fontWeight: FontWeight.w800,
                                                        fontSize: 18,
                                                        color: isCreditCard ? Colors.red : Theme.of(context).colorScheme.primary,
                                                      ),
                                                    ),
                                                    Consumer(
                                                      builder: (context, ref, child) {
                                                        final currencyState = ref.watch(currencyNotifierProvider);
                                                        if (account.currencyCode == currencyState.primaryCurrency) return const SizedBox.shrink();
                                                        
                                                        final primaryWorth = ref.read(currencyNotifierProvider.notifier).convertToPrimary(dynamicBalance, account.currencyCode ?? 'PKR');
                                                        final primaryCurrencyData = CurrencySelector.currencies.firstWhere(
                                                          (c) => c.code == currencyState.primaryCurrency,
                                                          orElse: () => CurrencySelector.currencies.first,
                                                        );
                                                        
                                                        return Text(
                                                          '≈ ${primaryCurrencyData.symbol} ${primaryWorth.toStringAsFixed(0)}',
                                                          style: GoogleFonts.manrope(
                                                            fontSize: 10,
                                                            fontWeight: FontWeight.w600,
                                                            color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.3),
                                                          ),
                                                        );
                                                      },
                                                    ),
                                                  ],
                                                );
                                              },
                                            ),
                                          if (isCreditCard)
                                            Text(
                                              'Used',
                                              style: TextStyle(fontSize: 10, color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.3)),
                                            ),
                                        ],
                                      ),
                                    ],
                                  ),
                                  if (isCreditCard && account.creditLimit > 0) ...[
                                    const SizedBox(height: 16),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                         Builder(
                                           builder: (context) {
                                             final currencyData = CurrencySelector.currencies.firstWhere(
                                               (c) => c.code == account.currencyCode,
                                               orElse: () => CurrencySelector.currencies.first,
                                             );
                                             return Text(
                                               'Limit: ${currencyData.symbol} ${account.creditLimit.toStringAsFixed(0)}',
                                               style: TextStyle(fontSize: 11, color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.3)),
                                             );
                                           },
                                         ),
                                        Text(
                                          '${((dynamicBalance / account.creditLimit) * 100).toStringAsFixed(0)}%',
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                            color: (dynamicBalance / account.creditLimit) > 0.8 ? Colors.red : Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.4),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(4),
                                      child: LinearProgressIndicator(
                                        value: dynamicBalance / account.creditLimit,
                                        backgroundColor: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.05),
                                        valueColor: AlwaysStoppedAnimation<Color>((dynamicBalance / account.creditLimit) > 0.8 ? Colors.red : Colors.red.withOpacity(0.5)),
                                        minHeight: 4,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                    const SizedBox(height: 32),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'People (Debt & Credit)',
                        style: GoogleFonts.manrope(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Theme.of(context).textTheme.titleLarge?.color,
                        ),
                      ),
                      TextButton.icon(
                        onPressed: () => Navigator.pushNamed(context, '/add_person'),
                        icon: Icon(Icons.person_add_rounded, size: 18, color: Theme.of(context).colorScheme.primary),
                        label: Text('Add', style: GoogleFonts.manrope(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.bold, fontSize: 13)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  if (personState.persons.isEmpty)
                    _buildEmptyPersons(context)
                  else
                    ...personState.persons.map((person) {
                      final balance = debtNotifier.getPersonBalance(person.id!);
                      final isOwed = balance > 0;
                      final absBalance = balance.abs();

                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: PremiumCard(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          onTap: () => Navigator.pushNamed(context, '/person_detail', arguments: person),
                          child: Row(
                            children: [
                              CircleAvatar(
                                backgroundColor: (isOwed ? Theme.of(context).colorScheme.primary : Colors.red).withOpacity(0.1),
                                child: Text(
                                  person.name[0].toUpperCase(),
                                  style: TextStyle(color: isOwed ? Theme.of(context).colorScheme.primary : Colors.red, fontWeight: FontWeight.bold),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      person.name,
                                      style: GoogleFonts.manrope(fontWeight: FontWeight.w700, fontSize: 15),
                                    ),
                                    if (person.phoneNumber != null)
                                      Text(
                                        person.phoneNumber!,
                                        style: TextStyle(fontSize: 11, color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.3)),
                                      ),
                                  ],
                                ),
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    'Rs. ${absBalance.toStringAsFixed(0)}',
                                    style: GoogleFonts.manrope(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 16,
                                      color: balance == 0 ? Colors.grey : (isOwed ? Theme.of(context).colorScheme.primary : Colors.red),
                                    ),
                                  ),
                                  Text(
                                    balance == 0 ? 'Settled' : (isOwed ? 'Owes you' : 'You owe'),
                                    style: TextStyle(fontSize: 10, color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.3)),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),

                  const SizedBox(height: 100),
                ],
              ),
            ),
    );
  }

  Widget _buildEmptyPersons(BuildContext context) {
    final textColor = Theme.of(context).textTheme.bodyMedium?.color;
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: textColor?.withOpacity(0.05) ?? Colors.white.withOpacity(0.05)),
      ),
      child: Column(
        children: [
          Icon(Icons.people_outline_rounded, size: 40, color: textColor?.withOpacity(0.2)),
          const SizedBox(height: 16),
          Text(
            'No people added yet',
            style: GoogleFonts.manrope(
              fontSize: 14, 
              fontWeight: FontWeight.w600, 
              color: textColor?.withOpacity(0.5)
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Keep track of money you lend to or borrow from friends.',
            textAlign: TextAlign.center,
            style: GoogleFonts.manrope(
              fontSize: 12, 
              color: textColor?.withOpacity(0.25)
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final textColor = Theme.of(context).textTheme.bodyMedium?.color;
    return Center(
      child: Column(
        children: [
          const SizedBox(height: 48),
          Icon(Icons.account_balance_wallet_rounded, size: 64, color: textColor?.withOpacity(0.1)),
          const SizedBox(height: 24),
          Text(
            'No accounts yet',
            style: GoogleFonts.manrope(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: textColor?.withOpacity(0.4),
            ),
          ),
          const SizedBox(height: 12),
          Text(
             'Add your first bank account or credit card to get started.',
             textAlign: TextAlign.center,
             style: GoogleFonts.manrope(
               fontSize: 14,
               color: textColor?.withOpacity(0.2),
             ),
          ),
        ],
      ),
    );
  }
}
