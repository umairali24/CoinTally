import 'package:flutter/material.dart';
import 'package:cointally/domain/entities/account_entity.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cointally/data/services/gold_service.dart';
import 'package:cointally/presentation/notifiers/transaction_notifier.dart';
import 'package:cointally/presentation/notifiers/account_notifier.dart';
import 'package:cointally/presentation/notifiers/locale_notifier.dart';
import 'package:cointally/presentation/widgets/sleek_components.dart';
import 'package:cointally/domain/entities/zakat_models.dart';
import 'package:cointally/presentation/notifiers/zakat_preference_notifier.dart';
import 'package:cointally/domain/entities/transaction_entity.dart';
import 'package:cointally/presentation/screens/add_transaction_screen.dart';
import 'package:cointally/presentation/notifiers/person_notifier.dart';
import 'package:cointally/presentation/notifiers/debt_notifier.dart';
import 'package:cointally/domain/entities/person_entity.dart';
import 'dart:convert';
import 'package:cointally/presentation/screens/notification_settings_screen.dart';

class ZakatScreen extends ConsumerStatefulWidget {
  const ZakatScreen({super.key});

  @override
  ConsumerState<ZakatScreen> createState() => _ZakatScreenState();
}

class _ZakatScreenState extends ConsumerState<ZakatScreen> {
  double _goldRate = 0.0;
  double _silverRate = 0.0;
  double _zakatLiability = 0.0;
  double _netWealth = 0.0;
  double _alreadyPaid = 0.0;
  bool _isLoadingRate = true;

  List<ZakatAsset> activeAssets = [];
  List<ZakatLiability> activeLiabilities = [];

  @override
  void initState() {
    super.initState();
    _loadAssetsAndLiabilities();
    _fetchRateAndInitializeCash();
  }

  Future<void> _loadAssetsAndLiabilities() async {
    final prefRepo = ref.read(preferenceRepositoryProvider);
    final assetsJson = await prefRepo.getZakatAssetsJson();
    final liabilitiesJson = await prefRepo.getZakatLiabilitiesJson();

    if (mounted) {
      setState(() {
        if (assetsJson != null) {
          try {
            final List<dynamic> decoded = jsonDecode(assetsJson);
            activeAssets = decoded.map((e) => ZakatAsset.fromJson(e)).toList();
          } catch (_) {}
        }
        if (liabilitiesJson != null) {
          try {
            final List<dynamic> decoded = jsonDecode(liabilitiesJson);
            activeLiabilities = decoded.map((e) => ZakatLiability.fromJson(e)).toList();
          } catch (_) {}
        }
      });
      _calculateZakat();
    }
  }

  Future<void> _saveAssetsAndLiabilities() async {
    final prefRepo = ref.read(preferenceRepositoryProvider);
    final assetsJson = jsonEncode(activeAssets.map((e) => e.toJson()).toList());
    final liabilitiesJson = jsonEncode(activeLiabilities.map((e) => e.toJson()).toList());
    
    await prefRepo.setZakatAssetsJson(assetsJson);
    await prefRepo.setZakatLiabilitiesJson(liabilitiesJson);
  }

  Future<void> _fetchRateAndInitializeCash() async {
    final service = GoldService();
    final goldRate = await service.fetchLiveGoldRate();
    final silverRate = await service.fetchLiveSilverRate();
    
    // Ensure we have the freshest account and debt data before calculating dynamically linked amounts
    await ref.read(accountProvider.notifier).loadAccounts();
    await ref.read(debtProvider.notifier).loadDebts();

    final totalBalance = ref.read(transactionProvider).totalBalance;
    final transactionRepo = ref.read(transactionRepositoryProvider);
    final paidZakat = await transactionRepo.getPaidZakatForCurrentYear();
    
    if (mounted) {
      setState(() {
        _goldRate = goldRate;
        _silverRate = silverRate;
        _isLoadingRate = false;
        _alreadyPaid = paidZakat;
        
        _calculateZakat();
      });
    }
  }

  Future<void> _syncLiveBalances() async {
    final txNotifier = ref.read(transactionProvider.notifier);
    final debts = ref.read(debtProvider).debts;
    bool hasChanges = false;

    // Sync assets
    for (int i = 0; i < activeAssets.length; i++) {
      final asset = activeAssets[i];
      if (asset.linkedAccountId != null) {
        try {
          final liveBalance = await txNotifier.getAccountBalance(asset.linkedAccountId!);
          final newAmount = liveBalance > 0 ? liveBalance : 0.0;
          if (asset.amount != newAmount) {
            activeAssets[i] = asset.copyWith(amount: newAmount);
            hasChanges = true;
          }
        } catch (_) {}
      }
    }

    // Sync liabilities
    for (int i = 0; i < activeLiabilities.length; i++) {
      final liability = activeLiabilities[i];
      if (liability.linkedAccountId != null) {
        try {
          final liveBalance = await txNotifier.getAccountBalance(liability.linkedAccountId!);
          final acc = ref.read(accountProvider).accounts.firstWhere((a) => a.id == liability.linkedAccountId);
          final isCreditCard = acc.accountType == 'CREDIT_CARD';
          final isLiability = isCreditCard ? liveBalance > 0 : liveBalance < 0;
          
          final newAmount = isLiability ? liveBalance.abs() : 0.0;
          if (liability.amount != newAmount) {
            activeLiabilities[i] = liability.copyWith(amount: newAmount);
            hasChanges = true;
          }
        } catch (_) {}
      } else if (liability.linkedDebtId != null) {
        try {
          final debt = debts.firstWhere((d) => d.id == liability.linkedDebtId);
          final newAmount = debt.isSettled ? 0.0 : debt.amount;
          if (liability.amount != newAmount) {
            activeLiabilities[i] = liability.copyWith(amount: newAmount);
            hasChanges = true;
          }
        } catch (_) {}
      }
    }

    if (hasChanges && mounted) {
      _calculateZakat();
    }
  }

  void _calculateZakat() {
    double totalAssets = 0.0;
    
    for (var asset in activeAssets) {
      if (asset.isPersonalJewelryExempt) continue;

      if (asset.type == ZakatStabilityType.gold) {
        totalAssets += asset.amount * _goldRate;
      } else if (asset.type == ZakatStabilityType.silver) {
        totalAssets += asset.amount * _silverRate;
      } else {
        totalAssets += asset.amount; // Cash or Other
      }
    }

    double totalLiabilities = 0.0;
    for (var liability in activeLiabilities) {
      totalLiabilities += liability.amount;
    }

    _netWealth = totalAssets - totalLiabilities;
    
    final prefs = ref.read(zakatPreferenceProvider);
    final nisabValue = prefs.nisabStandard == NisabStandard.gold 
        ? 7.5 * _goldRate 
        : 52.5 * _silverRate;

    setState(() {
      if (_netWealth >= nisabValue) {
        _zakatLiability = _netWealth * 0.025;
      } else {
        _zakatLiability = 0.0;
      }
    });

    _saveAssetsAndLiabilities();
  }

  void _showAddAssetSheet({ZakatAsset? assetToEdit}) {
    final prefs = ref.read(zakatPreferenceProvider);
    final typeController = ValueNotifier<ZakatStabilityType>(assetToEdit?.type ?? ZakatStabilityType.cash);
    final nameController = TextEditingController(text: assetToEdit?.name ?? '');
    final amountController = TextEditingController(text: assetToEdit?.amount.toString() ?? '');
    final exemptController = ValueNotifier<bool>(assetToEdit?.isPersonalJewelryExempt ?? false);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
            left: 24,
            right: 24,
            top: 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                assetToEdit == null ? 'Add Asset' : 'Edit Asset',
                style: GoogleFonts.manrope(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              const SizedBox(height: 16),
              ValueListenableBuilder<ZakatStabilityType>(
                valueListenable: typeController,
                builder: (context, type, _) {
                  return Container(
                    decoration: BoxDecoration(
                      color: Theme.of(context).cardTheme.color,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                      ),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<ZakatStabilityType>(
                        value: type,
                        isExpanded: true,
                        dropdownColor: Theme.of(context).cardTheme.color,
                        style: GoogleFonts.manrope(
                          color: Theme.of(context).textTheme.bodyLarge?.color,
                          fontWeight: FontWeight.w600,
                        ),
                        onChanged: (val) {
                          if (val != null) {
                            typeController.value = val;
                          }
                        },
                        items: ZakatStabilityType.values.map((t) {
                          String label = t.name.capitalize();
                          if (t == ZakatStabilityType.gold || t == ZakatStabilityType.silver) {
                            label += ' (in Tolas)';
                          } else {
                            label += ' (in Currency)';
                          }
                          return DropdownMenuItem(
                            value: t,
                            child: Text(label),
                          );
                        }).toList(),
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 16),
              SleekTextField(
                label: 'Name / Description',
                hintText: 'e.g., 24K Gold Set',
                controller: nameController,
                prefixIcon: Icons.description_rounded,
              ),
              const SizedBox(height: 16),
              ValueListenableBuilder<ZakatStabilityType>(
                valueListenable: typeController,
                builder: (context, type, _) {
                  final isWeight = type == ZakatStabilityType.gold || type == ZakatStabilityType.silver;
                  final isLinked = assetToEdit?.linkedAccountId != null;
                  
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SleekTextField(
                        label: isWeight ? 'Weight (in Tolas)' : 'Value / Amount',
                        hintText: '0.0',
                        controller: amountController,
                        prefixIcon: isWeight ? Icons.scale_rounded : Icons.numbers_rounded,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        readOnly: isLinked,
                      ),
                      if (isLinked)
                        Padding(
                          padding: const EdgeInsets.only(top: 8.0, left: 4.0),
                          child: Row(
                            children: [
                              Icon(Icons.link_rounded, size: 14, color: Theme.of(context).colorScheme.primary),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  'Amount is dynamically linked to account balance. You cannot edit it manually.',
                                  style: GoogleFonts.manrope(
                                    fontSize: 12,
                                    color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.8),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 16),
              ValueListenableBuilder<ZakatStabilityType>(
                valueListenable: typeController,
                builder: (context, type, _) {
                  if ((type == ZakatStabilityType.gold || type == ZakatStabilityType.silver) && 
                      prefs.fiqhSchool != FiqhSchool.hanafi) {
                    return ValueListenableBuilder<bool>(
                      valueListenable: exemptController,
                      builder: (context, isExempt, _) {
                        return CheckboxListTile(
                          title: Text(
                            'Is this jewelry for personal, daily use?',
                            style: GoogleFonts.manrope(fontSize: 14, fontWeight: FontWeight.w600),
                          ),
                          subtitle: Text(
                            'Your selected Fiqh exempts this from Zakat.',
                            style: GoogleFonts.manrope(fontSize: 12),
                          ),
                          value: isExempt,
                          onChanged: (val) {
                            if (val != null) exemptController.value = val;
                          },
                          activeColor: Theme.of(context).colorScheme.primary,
                          contentPadding: EdgeInsets.zero,
                          controlAffinity: ListTileControlAffinity.leading,
                        );
                      },
                    );
                  }
                  return const SizedBox.shrink();
                },
              ),
              const SizedBox(height: 16),
              const SizedBox(height: 16),
              Row(
                children: [
                  if (assetToEdit != null)
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(right: 12),
                        child: OutlinedButton.icon(
                          onPressed: () {
                            setState(() {
                              activeAssets.removeWhere((a) => a.id == assetToEdit.id);
                            });
                            _calculateZakat();
                            Navigator.pop(context);
                          },
                          icon: const Icon(Icons.delete_outline_rounded, size: 18),
                          label: Text('Delete', style: GoogleFonts.manrope(fontWeight: FontWeight.w700)),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.redAccent,
                            side: const BorderSide(color: Colors.redAccent),
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                    ),
                  Expanded(
                    flex: assetToEdit != null ? 2 : 1,
                    child: NeonButton(
                      text: assetToEdit == null ? 'Save to List' : 'Update',
                      onPressed: () {
                        final amount = double.tryParse(amountController.text) ?? 0.0;
                        final name = nameController.text.trim();
                        
                        if (amount > 0 && name.isNotEmpty) {
                          setState(() {
                            if (assetToEdit != null) {
                              final index = activeAssets.indexWhere((a) => a.id == assetToEdit.id);
                              if (index != -1) {
                                activeAssets[index] = assetToEdit.copyWith(
                                  type: typeController.value,
                                  name: name,
                                  amount: amount,
                                  isPersonalJewelryExempt: exemptController.value,
                                );
                              }
                            } else {
                              activeAssets.add(ZakatAsset(
                                type: typeController.value,
                                name: name,
                                amount: amount,
                                isPersonalJewelryExempt: exemptController.value,
                              ));
                            }
                          });
                          _calculateZakat();
                          Navigator.pop(context);
                        }
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
            ],
          ),
        );
      },
    );
  }

  void _showAddLiabilitySheet({ZakatLiability? liabilityToEdit}) {
    final typeController = ValueNotifier<ZakatLiabilityType>(liabilityToEdit?.type ?? ZakatLiabilityType.borrowedCash);
    final amountController = TextEditingController(text: liabilityToEdit?.amount.toString() ?? '');
    final nameController = TextEditingController(text: liabilityToEdit?.name ?? '');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
            left: 24,
            right: 24,
            top: 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                liabilityToEdit == null ? 'Add Liability' : 'Edit Liability',
                style: GoogleFonts.manrope(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              const SizedBox(height: 16),
              ValueListenableBuilder<ZakatLiabilityType>(
                valueListenable: typeController,
                builder: (context, type, _) {
                  return Container(
                    decoration: BoxDecoration(
                      color: Theme.of(context).cardTheme.color,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                      ),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<ZakatLiabilityType>(
                        value: type,
                        isExpanded: true,
                        dropdownColor: Theme.of(context).cardTheme.color,
                        style: GoogleFonts.manrope(
                          color: Theme.of(context).textTheme.bodyLarge?.color,
                          fontWeight: FontWeight.w600,
                        ),
                        onChanged: (val) {
                          if (val != null) {
                            typeController.value = val;
                          }
                        },
                        items: ZakatLiabilityType.values.map((t) {
                          String label = '';
                          switch (t) {
                            case ZakatLiabilityType.borrowedCash:
                              label = 'Borrowed Cash';
                              break;
                            case ZakatLiabilityType.pendingBills:
                              label = 'Pending Bills';
                              break;
                            case ZakatLiabilityType.businessDebt:
                              label = 'Business Debt';
                              break;
                            case ZakatLiabilityType.installmentDue:
                              label = 'Installment Due';
                              break;
                          }
                          return DropdownMenuItem(
                            value: t,
                            child: Text(label),
                          );
                        }).toList(),
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 16),
              SleekTextField(
                label: 'Name / Description (Optional)',
                hintText: 'e.g., Ali (Brother) or HBL Loan',
                controller: nameController,
                prefixIcon: Icons.description_rounded,
              ),
              const SizedBox(height: 16),
              Builder(
                builder: (context) {
                  final isLinked = liabilityToEdit?.linkedAccountId != null || liabilityToEdit?.linkedDebtId != null;
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SleekTextField(
                        label: 'Rupee Amount',
                        hintText: '0.0',
                        controller: amountController,
                        prefixIcon: Icons.money_off_csred_rounded,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        readOnly: isLinked,
                      ),
                      if (isLinked)
                        Padding(
                          padding: const EdgeInsets.only(top: 8.0, left: 4.0),
                          child: Row(
                            children: [
                              Icon(Icons.link_rounded, size: 14, color: Theme.of(context).colorScheme.primary),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  'Amount is dynamically linked. You cannot edit it manually.',
                                  style: GoogleFonts.manrope(
                                    fontSize: 12,
                                    color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.8),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  );
                }
              ),
              const SizedBox(height: 24),
              const SizedBox(height: 16),
              Row(
                children: [
                  if (liabilityToEdit != null)
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(right: 12),
                        child: OutlinedButton.icon(
                          onPressed: () {
                            setState(() {
                              activeLiabilities.removeWhere((l) => l.id == liabilityToEdit.id);
                            });
                            _calculateZakat();
                            Navigator.pop(context);
                          },
                          icon: const Icon(Icons.delete_outline_rounded, size: 18),
                          label: Text('Delete', style: GoogleFonts.manrope(fontWeight: FontWeight.w700)),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.redAccent,
                            side: const BorderSide(color: Colors.redAccent),
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                    ),
                  Expanded(
                    flex: liabilityToEdit != null ? 2 : 1,
                    child: NeonButton(
                      text: liabilityToEdit == null ? 'Save to List' : 'Update',
                      onPressed: () {
                        final amount = double.tryParse(amountController.text) ?? 0.0;
                        final name = nameController.text.trim();
                        
                        if (amount > 0) {
                          setState(() {
                            if (liabilityToEdit != null) {
                              final index = activeLiabilities.indexWhere((l) => l.id == liabilityToEdit.id);
                              if (index != -1) {
                                activeLiabilities[index] = liabilityToEdit.copyWith(
                                  type: typeController.value,
                                  amount: amount,
                                  name: name.isNotEmpty ? name : null,
                                );
                              }
                            } else {
                              activeLiabilities.add(ZakatLiability(
                                type: typeController.value,
                                amount: amount,
                                name: name.isNotEmpty ? name : null,
                              ));
                            }
                          });
                          _calculateZakat();
                          Navigator.pop(context);
                        }
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
            ],
          ),
        );
      },
    );
  }

  Future<void> _autoAddAssetsFromAccounts() async {
    final accounts = ref.read(accountProvider).accounts;
    final txNotifier = ref.read(transactionProvider.notifier);
    
    // Find eligible assets: Positive balance & not a CREDIT_CARD
    final eligibleAccounts = <AccountEntity>[];
    final liveBalances = <int, double>{};

    for (var account in accounts) {
      if (account.accountType == 'CREDIT_CARD') continue;
      if (activeAssets.any((a) => a.name == account.bankName)) continue;

      final liveBalance = await txNotifier.getAccountBalance(account.id!);
      if (liveBalance > 0) {
        eligibleAccounts.add(account);
        liveBalances[account.id!] = liveBalance;
      }
    }

    if (!mounted) return;

    if (eligibleAccounts.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No new accounts with positive balances found.')),
      );
      return;
    }

    // Keep track of selected accounts in the dialog
    final selectedAccounts = List<AccountEntity>.from(eligibleAccounts);

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              backgroundColor: Theme.of(context).scaffoldBackgroundColor,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: Text(
                'Auto-Add Assets',
                style: GoogleFonts.manrope(fontWeight: FontWeight.bold, fontSize: 18),
              ),
              content: SizedBox(
                width: double.maxFinite,
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: eligibleAccounts.length,
                  itemBuilder: (context, index) {
                    final account = eligibleAccounts[index];
                    final isSelected = selectedAccounts.contains(account);
                    return CheckboxListTile(
                      activeColor: Theme.of(context).colorScheme.primary,
                      title: Text(account.bankName, style: GoogleFonts.manrope(fontWeight: FontWeight.w600)),
                      subtitle: Text('Rs. ${liveBalances[account.id!]?.toStringAsFixed(0)}'),
                      value: isSelected,
                      onChanged: (bool? value) {
                        setStateDialog(() {
                          if (value == true) {
                            selectedAccounts.add(account);
                          } else {
                            selectedAccounts.remove(account);
                          }
                        });
                      },
                    );
                  },
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text('Cancel', style: GoogleFonts.manrope(color: Colors.grey)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () {
                    if (selectedAccounts.isNotEmpty) {
                      setState(() {
                        for (var account in selectedAccounts) {
                          activeAssets.add(ZakatAsset(
                            type: ZakatStabilityType.cash,
                            name: account.bankName,
                            amount: liveBalances[account.id!] ?? 0.0,
                            linkedAccountId: account.id,
                          ));
                        }
                        _calculateZakat();
                      });
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Added ${selectedAccounts.length} assets.')),
                      );
                    }
                    Navigator.pop(context);
                  },
                  child: const Text('Add Selected'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _autoAddLiabilitiesFromAccountsAndDebts() async {
    final accounts = ref.read(accountProvider).accounts;
    final debts = ref.read(debtProvider).debts;
    final persons = ref.read(personProvider).persons;
    final txNotifier = ref.read(transactionProvider.notifier);
    
    // Find eligible liabilities
    final eligibleLiabilities = <ZakatLiability>[];

    // 1. Bank accounts with negative balance OR Credit cards with positive balance (meaning debt)
    for (var account in accounts) {
      final isCreditCard = account.accountType == 'CREDIT_CARD';
      final liveBalance = await txNotifier.getAccountBalance(account.id!);
      final isLiability = isCreditCard ? liveBalance > 0 : liveBalance < 0;
      
      if (isLiability && !activeLiabilities.any((l) => l.name == account.bankName)) {
        eligibleLiabilities.add(ZakatLiability(
          type: isCreditCard ? ZakatLiabilityType.businessDebt : ZakatLiabilityType.borrowedCash,
          name: account.bankName,
          amount: liveBalance.abs(),
          linkedAccountId: account.id,
        ));
      }
    }

    // 2. Unsettled borrowed debts
    for (var debt in debts) {
      if (debt.type == 'BORROW' && !debt.isSettled) {
        final person = persons.firstWhere((p) => p.id == debt.personId, orElse: () => PersonEntity(id: -1, name: 'Unknown', phoneNumber: ''));
        final debtName = 'Debt: ${person.name}';
        if (!activeLiabilities.any((l) => l.name == debtName)) {
          eligibleLiabilities.add(ZakatLiability(
            type: ZakatLiabilityType.borrowedCash,
            name: debtName,
            amount: debt.amount,
            linkedDebtId: debt.id,
          ));
        }
      }
    }

    if (eligibleLiabilities.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No new liabilities found.')),
      );
      return;
    }

    // Keep track of selected liabilities in the dialog
    final selectedLiabilities = List<ZakatLiability>.from(eligibleLiabilities);

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              backgroundColor: Theme.of(context).scaffoldBackgroundColor,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: Text(
                'Auto-Add Liabilities',
                style: GoogleFonts.manrope(fontWeight: FontWeight.bold, fontSize: 18),
              ),
              content: SizedBox(
                width: double.maxFinite,
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: eligibleLiabilities.length,
                  itemBuilder: (context, index) {
                    final liability = eligibleLiabilities[index];
                    final isSelected = selectedLiabilities.contains(liability);
                    return CheckboxListTile(
                      activeColor: Colors.redAccent,
                      title: Text(liability.name ?? 'Unknown', style: GoogleFonts.manrope(fontWeight: FontWeight.w600)),
                      subtitle: Text('Rs. ${liability.amount.toStringAsFixed(0)}'),
                      value: isSelected,
                      onChanged: (bool? value) {
                        setStateDialog(() {
                          if (value == true) {
                            selectedLiabilities.add(liability);
                          } else {
                            selectedLiabilities.remove(liability);
                          }
                        });
                      },
                    );
                  },
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text('Cancel', style: GoogleFonts.manrope(color: Colors.grey)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.redAccent,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () {
                    if (selectedLiabilities.isNotEmpty) {
                      setState(() {
                        activeLiabilities.addAll(selectedLiabilities);
                        _calculateZakat();
                      });
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Added ${selectedLiabilities.length} liabilities.')),
                      );
                    }
                    Navigator.pop(context);
                  },
                  child: const Text('Add Selected'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    // Listen to transaction, account and debt changes to recalculate the dynamic balances!
    ref.listen(transactionProvider, (previous, next) {
      if (!next.isLoading && previous?.isLoading == true) {
        _syncLiveBalances();
      }
    });

    ref.listen(accountProvider, (previous, next) {
      if (previous?.accounts != next.accounts) {
        _syncLiveBalances();
      }
    });

    ref.listen(debtProvider, (previous, next) {
      if (previous?.debts != next.debts) {
        _syncLiveBalances();
      }
    });

    final localeNotifier = ref.read(localeProvider.notifier);
    final prefs = ref.watch(zakatPreferenceProvider);
    
    final bool isGoldNisab = prefs.nisabStandard == NisabStandard.gold;
    final double nisabValue = isGoldNisab ? 7.5 * _goldRate : 52.5 * _silverRate;
    final String goldRateStr = _goldRate > 0 ? _goldRate.toStringAsFixed(0) : '...';
    final String silverRateStr = _silverRate > 0 ? _silverRate.toStringAsFixed(0) : '...';
    final String nisabLabel = isGoldNisab 
        ? 'Nisab (7.5T Gold @ $goldRateStr)' 
        : 'Nisab (52.5T Silver @ $silverRateStr)';
    final Color nisabColor = isGoldNisab ? Colors.amber : Colors.grey;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text('Zakaat Calculator', style: GoogleFonts.manrope(fontWeight: FontWeight.w700)),
      ),
      body: DefaultTabController(
        length: 2,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
              child: PremiumCard(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    Text(
                      'Total Assessed Zakaat',
                      style: GoogleFonts.manrope(
                        color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.5),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Rs. ${_zakatLiability.toStringAsFixed(2)}',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.manrope(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Already Paid: ',
                          style: GoogleFonts.manrope(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.7),
                          ),
                        ),
                        Text(
                          'Rs. ${_alreadyPaid.toStringAsFixed(2)}',
                          style: GoogleFonts.manrope(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.redAccent,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Remaining Due: ',
                          style: GoogleFonts.manrope(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: Theme.of(context).textTheme.bodyMedium?.color,
                          ),
                        ),
                        Text(
                          'Rs. ${(_zakatLiability - _alreadyPaid > 0 ? _zakatLiability - _alreadyPaid : 0).toStringAsFixed(2)}',
                          style: GoogleFonts.manrope(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Net Wealth: Rs. ${_netWealth.toStringAsFixed(2)}',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.manrope(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.5),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: (_zakatLiability > 0 ? Theme.of(context).colorScheme.primary : Colors.orange).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        _zakatLiability > 0 ? 'Nisab Threshold Met' : 'Below Nisab Threshold',
                        style: GoogleFonts.manrope(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: _zakatLiability > 0 ? Theme.of(context).colorScheme.primary : Colors.orange,
                        ),
                      ),
                    ),
                    if (_zakatLiability - _alreadyPaid > 0) ...[
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => AddTransactionScreen(
                                  initialType: 'EXPENSE',
                                  transaction: TransactionEntity(
                                    amount: double.parse((_zakatLiability - _alreadyPaid).toStringAsFixed(2)),
                                    type: 'EXPENSE',
                                    category: 'Zakat',
                                    date: DateTime.now(),
                                  ),
                                ),
                              ),
                            ).then((_) {
                              // Refresh Data when returned
                              _fetchRateAndInitializeCash();
                            });
                          },
                          icon: Icon(Icons.volunteer_activism_rounded, size: 18, color: Theme.of(context).colorScheme.primary),
                          label: Text(
                            'Record Zakaat Payment',
                            style: GoogleFonts.manrope(fontWeight: FontWeight.w700),
                          ),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Theme.of(context).colorScheme.primary,
                            side: BorderSide(color: Theme.of(context).colorScheme.primary.withOpacity(0.5)),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
              child: Row(
                children: [
                  Expanded(
                    child: _buildRateCard('Silver/Tola (${_silverRate > 0 ? 'Loaded' : 'Loading'})', _silverRate, Colors.grey),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildRateCard(nisabLabel, nisabValue, nisabColor),
                  ),
                ],
              ),
            ),

            const TabBar(
              tabs: [
                Tab(text: 'Assets'),
                Tab(text: 'Liabilities (Deductions)'),
              ],
            ),
            Expanded(
              child: TabBarView(
                children: [
                  // Assets Tab
                  _buildAssetsTab(),
                  // Liabilities Tab
                  _buildLiabilitiesTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRateCard(String title, double rate, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.manrope(
              fontSize: 11,
              color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.4),
            ),
          ),
          const SizedBox(height: 6),
          _isLoadingRate 
            ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2))
            : Text(
                'Rs. ${rate.toStringAsFixed(0)}',
                style: GoogleFonts.manrope(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: color,
                ),
              ),
        ],
      ),
    );
  }

  Widget _buildAssetsTab() {
    return Stack(
      children: [
        activeAssets.isEmpty 
          ? Center(child: Text('No assets added yet.', style: GoogleFonts.manrope(color: Colors.grey)))
          : ListView.builder(
              padding: const EdgeInsets.only(bottom: 80, top: 16, left: 16, right: 16),
              itemCount: activeAssets.length,
              itemBuilder: (context, index) {
                final asset = activeAssets[index];
                return Card(
                  color: Theme.of(context).cardTheme.color,
                  margin: const EdgeInsets.only(bottom: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: InkWell(
                    onTap: () => _showAddAssetSheet(assetToEdit: asset),
                    borderRadius: BorderRadius.circular(12),
                    child: ListTile(
                      leading: Icon(
                        asset.type == ZakatStabilityType.gold ? Icons.auto_awesome_rounded :
                        asset.type == ZakatStabilityType.silver ? Icons.blur_on_rounded :
                        Icons.account_balance_wallet_rounded,
                        color: asset.type == ZakatStabilityType.gold ? Colors.amber :
                               asset.type == ZakatStabilityType.silver ? Colors.grey :
                               Theme.of(context).colorScheme.primary,
                      ),
                      title: Text(asset.name, style: GoogleFonts.manrope(fontWeight: FontWeight.w600)),
                      subtitle: Text(asset.type.name.capitalize()),
                      trailing: Text(
                        asset.type == ZakatStabilityType.gold || asset.type == ZakatStabilityType.silver
                            ? '${asset.amount} Tolas'
                            : 'Rs. ${asset.amount.toStringAsFixed(0)}',
                        style: GoogleFonts.manrope(fontWeight: FontWeight.w700, color: Theme.of(context).colorScheme.primary),
                      ),
                    ),
                  ),
                );
              },
            ),
        Positioned(
          bottom: 16,
          right: 16,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              FloatingActionButton.extended(
                heroTag: 'autoAddAssetsFAB',
                onPressed: _autoAddAssetsFromAccounts,
                icon: const Icon(Icons.auto_awesome),
                label: const Text('Auto-add Accounts'),
                backgroundColor: Theme.of(context).colorScheme.secondary,
                foregroundColor: Colors.white,
              ),
              const SizedBox(height: 16),
              FloatingActionButton.extended(
                heroTag: 'addAssetFAB',
                onPressed: _showAddAssetSheet,
                icon: const Icon(Icons.add),
                label: const Text('Add Asset'),
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Colors.white,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildLiabilitiesTab() {
    return Stack(
      children: [
        activeLiabilities.isEmpty 
          ? Center(child: Text('No liabilities added yet.', style: GoogleFonts.manrope(color: Colors.grey)))
          : ListView.builder(
              padding: const EdgeInsets.only(bottom: 80, top: 16, left: 16, right: 16),
              itemCount: activeLiabilities.length,
              itemBuilder: (context, index) {
                final liability = activeLiabilities[index];
                return Card(
                  color: Theme.of(context).cardTheme.color,
                  margin: const EdgeInsets.only(bottom: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: InkWell(
                    onTap: () => _showAddLiabilitySheet(liabilityToEdit: liability),
                    borderRadius: BorderRadius.circular(12),
                    child: ListTile(
                      leading: const Icon(
                        Icons.money_off_csred_rounded,
                        color: Colors.redAccent,
                      ),
                      title: Text(liability.name?.isNotEmpty == true ? liability.name! : liability.typeName, style: GoogleFonts.manrope(fontWeight: FontWeight.w600)),
                      subtitle: liability.name?.isNotEmpty == true ? Text(liability.typeName, style: GoogleFonts.manrope(fontSize: 12)) : null,
                      trailing: Text(
                        'Rs. ${liability.amount.toStringAsFixed(0)}',
                        style: GoogleFonts.manrope(fontWeight: FontWeight.w700, color: Colors.redAccent),
                      ),
                    ),
                  ),
                );
              },
            ),
        Positioned(
          bottom: 16,
          right: 16,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              FloatingActionButton.extended(
                heroTag: 'autoAddLiabilitiesFAB',
                onPressed: _autoAddLiabilitiesFromAccountsAndDebts,
                icon: const Icon(Icons.auto_awesome),
                label: const Text('Auto-add Debts'),
                backgroundColor: Colors.orangeAccent,
                foregroundColor: Colors.white,
              ),
              const SizedBox(height: 16),
              FloatingActionButton.extended(
                heroTag: 'addLiabilityFAB',
                onPressed: _showAddLiabilitySheet,
                icon: const Icon(Icons.remove),
                label: const Text('Add Liability'),
                backgroundColor: Colors.redAccent,
                foregroundColor: Colors.white,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

extension StringExtension on String {
    String capitalize() {
      return "${this[0].toUpperCase()}${substring(1).toLowerCase()}";
    }
}
