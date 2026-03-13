import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cointally/presentation/widgets/sleek_components.dart';
import 'package:cointally/domain/entities/account_entity.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cointally/presentation/notifiers/currency_notifier.dart';
import 'package:cointally/presentation/notifiers/format_preferences_notifier.dart';
import 'package:cointally/core/utils/format_utils.dart';
import 'package:cointally/presentation/widgets/currency_selector.dart';

import 'package:cointally/presentation/notifiers/account_detail_notifier.dart';

Color getBankColor(AccountEntity account, Color defaultColor) {
  if (account.themeColor.isNotEmpty && account.themeColor != '#FFFFFF') {
    try {
      return Color(int.parse(account.themeColor.replaceFirst('#', '0xFF')));
    } catch (e) {
      // ignore parsing errors and fallback
    }
  }

  final name = account.bankName;
  final logo = account.logoAssetPath;

  if (name.toLowerCase() == 'wallet') return const Color(0xFF13EC13);
  if (logo == null) return defaultColor;
  final lowerLogo = logo.toLowerCase();
  
  if (lowerLogo.contains('hbl')) return const Color(0xFF008266);
  if (lowerLogo.contains('mcb')) return const Color(0xFFF47920);
  if (lowerLogo.contains('ubl')) return const Color(0xFF0066A6);
  if (lowerLogo.contains('faysal')) return const Color(0xFF003D7A);
  if (lowerLogo.contains('meezan')) return const Color(0xFF6A2A5E);
  if (lowerLogo.contains('alfalah')) return const Color(0xFFD4111E);
  if (lowerLogo.contains('allied')) return const Color(0xFFE26027);
  if (lowerLogo.contains('askari')) return const Color(0xFFFABF00);
  if (lowerLogo.contains('naya_pay') || lowerLogo.contains('nayapay')) return const Color(0xFFFF5A00);
  if (lowerLogo.contains('sada_pay') || lowerLogo.contains('sadapay')) return const Color(0xFF1E88E5);
  if (lowerLogo.contains('jazz_cash') || lowerLogo.contains('jazzcash')) return const Color(0xFFED1C24);
  if (lowerLogo.contains('easy_paisa') || lowerLogo.contains('easypaisa')) return const Color(0xFF00A651);
  if (lowerLogo.contains('standard_chartered')) return const Color(0xFF009EB3);
  if (lowerLogo.contains('samba')) return const Color(0xFFF9A825);
  if (lowerLogo.contains('mashreq')) return const Color(0xFFFF4D4F);
  
  final hash = name.hashCode;
  final r = (hash & 0xFF0000) >> 16;
  final g = (hash & 0x00FF00) >> 8;
  final b = (hash & 0x0000FF);
  
  final adjustedR = (r % 150) + 50;
  final adjustedG = (g % 150) + 50;
  final adjustedB = (b % 150) + 50;
  
  return Color.fromRGBO(adjustedR, adjustedG, adjustedB, 1.0);
}

class NetLiquidityCard extends ConsumerStatefulWidget {
  final String formattedTotal;
  final double totalLiquidity;
  final List<AccountEntity> accounts;
  final String? convertedFromText;

  const NetLiquidityCard({
    super.key,
    required this.formattedTotal,
    required this.totalLiquidity,
    required this.accounts,
    this.convertedFromText,
  });

  @override
  ConsumerState<NetLiquidityCard> createState() => _NetLiquidityCardState();
}

class _NetLiquidityCardState extends ConsumerState<NetLiquidityCard> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  
  int? _selectedAssetAccountId;
  int? _selectedLiabilityAccountId;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Widget _buildPagerIndicator(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(2, (index) {
        final isActive = _currentPage == index;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          margin: const EdgeInsets.symmetric(horizontal: 4),
          height: 6,
          width: isActive ? 24 : 6,
          decoration: BoxDecoration(
            color: isActive 
              ? Theme.of(context).colorScheme.primary 
              : Theme.of(context).colorScheme.primary.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(3),
          ),
        );
      }),
    );
  }

  Widget _buildSelectedDetailsCard(BuildContext context, List<AccountEntity> chartAccounts, Map<int, double> convertedBalances, double totalAssets, double totalLiabilities, bool forAssets) {
    final selectedId = forAssets ? _selectedAssetAccountId : _selectedLiabilityAccountId;
    if (selectedId == null || !chartAccounts.any((a) => a.id == selectedId)) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: Theme.of(context).textTheme.bodyMedium?.color?.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(16),
        ),
        alignment: Alignment.center,
        child: Text(
          'Tap a chart segment to view details',
          style: GoogleFonts.manrope(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: Theme.of(context).textTheme.bodyMedium?.color?.withValues(alpha: 0.5),
          ),
        ),
      );
    }
    final account = chartAccounts.firstWhere((a) => a.id == selectedId);
    final convertedBalance = convertedBalances[account.id!] ?? 0.0;
    
    final baseAmount = forAssets ? totalAssets : totalLiabilities;
    final percentage = baseAmount > 0 ? (convertedBalance.abs() / baseAmount) * 100 : 0.0;
    final percentageText = forAssets ? '% of total assets' : '% of total liabilities';

    final color = getBankColor(account, Theme.of(context).colorScheme.primary);
    final formatPrefs = ref.watch(formatPreferencesProvider);
    final currencyState = ref.watch(currencyNotifierProvider);
    final symbol = CurrencySelector.currencies.firstWhere(
      (c) => c.code == currencyState.primaryCurrency, 
      orElse: () => CurrencySelector.currencies.first
    ).symbol;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.3)),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  account.bankName,
                  style: GoogleFonts.manrope(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Theme.of(context).textTheme.titleLarge?.color,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${percentage.toStringAsFixed(1)}$percentageText',
                  style: GoogleFonts.manrope(
                    fontSize: 11,
                    color: Theme.of(context).textTheme.bodyMedium?.color?.withValues(alpha: 0.5),
                  ),
                ),
              ],
            ),
          ),
          Text(
            FormatUtils.formatCurrency(convertedBalance.abs(), prefs: formatPrefs, symbol: symbol, forceDecimals: false),
            style: GoogleFonts.manrope(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDonutPage(String type, List<AccountEntity> accounts, Map<int, double> convertedBalances, double total) {
    final isAsset = type == 'ASSET';
    final selectedAccountId = isAsset ? _selectedAssetAccountId : _selectedLiabilityAccountId;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              isAsset ? 'Assets Overview' : 'Liabilities Overview',
              style: GoogleFonts.manrope(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Theme.of(context).textTheme.titleLarge?.color,
              ),
            ),
            Icon(
              isAsset ? Icons.arrow_outward_rounded : Icons.south_west_rounded,
              color: isAsset ? Theme.of(context).colorScheme.primary : Colors.orange,
              size: 20,
            )
          ],
        ),
        const SizedBox(height: 24),
        if (total == 0 || accounts.isEmpty)
          Expanded(
            child: Center(
              child: Text(
                'No $type data to display.',
                style: GoogleFonts.manrope(color: Theme.of(context).textTheme.bodyMedium?.color?.withValues(alpha: 0.4)),
              ),
            ),
          )
        else
          Expanded(
            child: Row(
              children: [
                // Left Side: Legend (Weight 1f)
                Expanded(
                  flex: 2,
                  child: ListView.builder(
                    physics: const BouncingScrollPhysics(),
                    itemCount: accounts.length,
                    itemBuilder: (context, index) {
                      final account = accounts[index];
                      final isSelected = selectedAccountId == account.id;
                      final color = getBankColor(account, Theme.of(context).colorScheme.primary);
                      
                      return GestureDetector(
                        onTap: () {
                          setState(() {
                            if (isAsset) {
                              _selectedAssetAccountId = isSelected ? null : account.id;
                            } else {
                              _selectedLiabilityAccountId = isSelected ? null : account.id;
                            }
                          });
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                          margin: const EdgeInsets.only(bottom: 4),
                          decoration: BoxDecoration(
                            color: isSelected ? color.withValues(alpha: 0.1) : Colors.transparent,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 12,
                                height: 12,
                                decoration: BoxDecoration(
                                  color: color,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  account.bankName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.manrope(
                                    fontSize: 13,
                                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                                    color: isSelected ? color : Theme.of(context).textTheme.bodyMedium?.color,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
                // Right Side: Donut Chart (Weight 1.5f -> 3 flex)
                Expanded(
                  flex: 3,
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final size = min(constraints.maxWidth, constraints.maxHeight);
                      return Center(
                        child: SizedBox(
                          width: size,
                          height: size,
                          child: GestureDetector(
                            onTapUp: (details) {
                              final tapPosition = details.localPosition;
                              final centerX = size / 2;
                              final centerY = size / 2;
                              
                              final dx = tapPosition.dx - centerX;
                              final dy = tapPosition.dy - centerY;
                              final distance = sqrt(dx * dx + dy * dy);
                              
                              final strokeWidth = size * 0.25;
                              final outerRadius = size / 2;
                              final innerRadius = outerRadius - strokeWidth;

                              if (distance >= innerRadius && distance <= outerRadius) {
                                var touchAngle = atan2(dy, dx);
                                if (touchAngle < 0) touchAngle += 2 * pi;
                                touchAngle = (touchAngle + pi / 2) % (2 * pi);

                                double currentAngle = 0;
                                int? tappedAccountId;
                                
                                for (var account in accounts) {
                                  final convertedBalance = (convertedBalances[account.id!] ?? 0.0).abs();
                                  final sweepAngle = (convertedBalance / total) * 2 * pi;
                                  if (touchAngle >= currentAngle && touchAngle <= currentAngle + sweepAngle) {
                                    tappedAccountId = account.id;
                                    break;
                                  }
                                  currentAngle += sweepAngle;
                                }

                                if (tappedAccountId != null) {
                                  setState(() {
                                    if (isAsset) {
                                      _selectedAssetAccountId = tappedAccountId;
                                    } else {
                                      _selectedLiabilityAccountId = tappedAccountId;
                                    }
                                  });
                                }
                              } else {
                                setState(() {
                                  if (isAsset) {
                                    _selectedAssetAccountId = null;
                                  } else {
                                    _selectedLiabilityAccountId = null;
                                  }
                                });
                              }
                            },
                            child: CustomPaint(
                              size: Size(size, size),
                              painter: AccountDonutChartPainter(
                                accounts: accounts,
                                convertedBalances: convertedBalances,
                                total: total,
                                selectedAccountId: selectedAccountId,
                                strokeWidth: size * 0.25,
                                context: context,
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        
        const SizedBox(height: 16),
        _buildSelectedDetailsCard(context, accounts, convertedBalances, total, total, isAsset),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final currencyProvider = ref.read(currencyNotifierProvider.notifier);

    final Map<int, double> convertedBalances = {};
    for (var acc in widget.accounts) {
      final liveBalance = ref.watch(accountDetailProvider(acc.id!)).balance;
      convertedBalances[acc.id!] = currencyProvider.convertToPrimary(liveBalance, acc.currencyCode);
    }

    bool isCreditCard(AccountEntity a) => a.accountType == 'CREDIT_CARD';
    bool isAsset(AccountEntity a, double bal) => isCreditCard(a) ? bal <= 0 : bal >= 0;
    bool isLiability(AccountEntity a, double bal) => isCreditCard(a) ? bal > 0 : bal < 0;

    final positiveAccounts = widget.accounts.where((a) => isAsset(a, convertedBalances[a.id!] ?? 0)).toList();
    positiveAccounts.sort((a, b) => (convertedBalances[b.id!] ?? 0).abs().compareTo((convertedBalances[a.id!] ?? 0).abs()));
    
    final negativeAccounts = widget.accounts.where((a) => isLiability(a, convertedBalances[a.id!] ?? 0)).toList();
    negativeAccounts.sort((a, b) => (convertedBalances[a.id!] ?? 0).abs().compareTo((convertedBalances[b.id!] ?? 0).abs()));

    final totalAssets = positiveAccounts.fold(0.0, (sum, a) => sum + (convertedBalances[a.id!] ?? 0).abs());
    final totalLiabilities = negativeAccounts.fold(0.0, (sum, a) => sum + (convertedBalances[a.id!] ?? 0).abs());

    return PremiumCard(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Top: Net Liquidity Header & Total
          Text(
            'Net Liquidity',
            style: GoogleFonts.manrope(
              color: Theme.of(context).textTheme.bodyMedium?.color?.withValues(alpha: 0.6),
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              widget.formattedTotal,
              style: GoogleFonts.manrope(
                fontSize: 32,
                fontWeight: FontWeight.w800,
                height: 1.1,
                color: Theme.of(context).textTheme.bodyLarge?.color,
              ),
            ),
          ),
          if (widget.convertedFromText != null) ...[
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.info_outline_rounded, size: 12, color: Theme.of(context).textTheme.bodyMedium?.color?.withValues(alpha: 0.4)),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    widget.convertedFromText!,
                    style: GoogleFonts.manrope(
                      fontSize: 10,
                      color: Theme.of(context).textTheme.bodyMedium?.color?.withValues(alpha: 0.4),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ],
          
          // Middle/Bottom: Animated Donut Pager Charts
          SizedBox(
            height: 380, // Fixed height specifically supporting Donut and its layout
            child: PageView(
              controller: _pageController,
              onPageChanged: (idx) {
                setState(() => _currentPage = idx);
              },
              children: [
                _buildDonutPage('ASSET', positiveAccounts, convertedBalances, totalAssets),
                _buildDonutPage('LIABILITY', negativeAccounts, convertedBalances, totalLiabilities),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _buildPagerIndicator(context),
        ],
      ),
    );
  }
}

class AccountDonutChartPainter extends CustomPainter {
  final List<AccountEntity> accounts;
  final Map<int, double> convertedBalances;
  final double total;
  final int? selectedAccountId;
  final double strokeWidth;
  final BuildContext context;

  AccountDonutChartPainter({
    required this.accounts,
    required this.convertedBalances,
    required this.total,
    this.selectedAccountId,
    required this.strokeWidth,
    required this.context,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (total == 0 || accounts.isEmpty) return;

    final rect = Rect.fromLTWH(
      strokeWidth / 2, 
      strokeWidth / 2, 
      size.width - strokeWidth, 
      size.height - strokeWidth
    );
    
    double startAngle = -pi / 2; // Start from top
    double gapAngle = 0.05; // Gap between segments

    for (var account in accounts) {
      final convertedBalance = (convertedBalances[account.id!] ?? 0.0).abs();
      final sweepAngle = (convertedBalance / total) * (2 * pi);
      
      final isSelected = selectedAccountId == null || selectedAccountId == account.id;
      final color = getBankColor(account, Theme.of(context).colorScheme.primary);
      
      final paint = Paint()
        ..color = isSelected ? color : color.withValues(alpha: 0.3)
        ..style = PaintingStyle.stroke
        ..strokeWidth = isSelected ? strokeWidth : strokeWidth * 0.85
        ..strokeCap = StrokeCap.round;

      // Ensure minimal visible arc
      final actualSweep = max(0.01, sweepAngle - gapAngle);
      canvas.drawArc(rect, startAngle + (gapAngle / 2), actualSweep, false, paint);

      // (We skip drawing Account Icons as requested; cleanly colored arcs works best for pure data displays here)

      startAngle += sweepAngle;
    }
  }

  @override
  bool shouldRepaint(AccountDonutChartPainter oldDelegate) {
    return oldDelegate.selectedAccountId != selectedAccountId || 
           oldDelegate.accounts != accounts || 
           oldDelegate.total != total;
  }
}
