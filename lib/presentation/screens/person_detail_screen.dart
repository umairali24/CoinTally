import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:cointally/domain/entities/person_entity.dart';
import 'package:cointally/presentation/notifiers/debt_notifier.dart';
import 'package:cointally/presentation/notifiers/person_notifier.dart';
import 'package:cointally/presentation/notifiers/account_notifier.dart';
import 'package:cointally/presentation/screens/lend_borrow_screen.dart';
import 'package:cointally/presentation/widgets/sleek_components.dart';

class PersonDetailScreen extends ConsumerWidget {
  final PersonEntity person;

  const PersonDetailScreen({super.key, required this.person});

  void _showSettleDialog(BuildContext context, WidgetRef ref, int debtId) {
    final accountState = ref.watch(accountProvider);
    int? selectedAccountId;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: Theme.of(context).cardTheme.color,
              title: Text('Settle Up', style: GoogleFonts.manrope(fontWeight: FontWeight.bold)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                   Text('Select account to use for settlement:', style: TextStyle(color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.5), fontSize: 13)),
                   const SizedBox(height: 16),
                   DropdownButtonFormField<int>(
                    value: selectedAccountId,
                    dropdownColor: Theme.of(context).cardTheme.color,
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.05),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    ),
                    items: [
                      DropdownMenuItem(value: null, child: Text('No Account (Cash)', style: TextStyle(color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.7), fontSize: 13))),
                      ...accountState.accounts.map((acc) => DropdownMenuItem(
                        value: acc.id,
                        child: Text(acc.bankName, style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color, fontSize: 13)),
                      )),
                    ],
                    onChanged: (val) => setDialogState(() => selectedAccountId = val),
                  ),
                ],
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: Text('Cancel', style: TextStyle(color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.5)))),
                SleekButton(
                  onTap: () {
                    ref.read(debtProvider.notifier).settleDebt(debtId, accountId: selectedAccountId);
                    Navigator.pop(context);
                  },
                  label: 'Settle',
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final debtState = ref.watch(debtProvider);
    final personDebts = debtState.debts.where((d) => d.personId == person.id).toList();
    final balance = ref.read(debtProvider.notifier).getPersonBalance(person.id!);
    final isOwed = balance > 0;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(person.name, style: GoogleFonts.manrope(fontWeight: FontWeight.w700)),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent),
            onPressed: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  backgroundColor: Theme.of(context).cardTheme.color,
                  title: const Text('Delete Person?'),
                  content: Text('This will delete all debt records for this person. This action cannot be undone.', style: TextStyle(color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.7))),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
                    TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete', style: TextStyle(color: Colors.redAccent))),
                  ],
                ),
              );
              if (confirm == true) {
                ref.read(personProvider.notifier).deletePerson(person.id!);
                Navigator.pop(context);
              }
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Header Balance Card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            child: PremiumCard(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  Text(
                    balance == 0 ? 'Settled Up' : (isOwed ? 'Owes You' : 'You Owe'),
                    style: GoogleFonts.manrope(color: Colors.white.withOpacity(0.4), fontWeight: FontWeight.w600, fontSize: 13),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Rs. ${balance.abs().toStringAsFixed(0)}',
                    style: GoogleFonts.manrope(
                      fontSize: 32,
                      fontWeight: FontWeight.w800,
                      color: balance == 0 ? Colors.grey : (isOwed ? Theme.of(context).colorScheme.primary : Colors.red),
                    ),
                  ),
                ],
              ),
            ),
          ),

          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'History',
                    style: GoogleFonts.manrope(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 16),
                  if (personDebts.isEmpty)
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.only(top: 48),
                        child: Text('No records found.', style: TextStyle(color: Colors.white.withOpacity(0.2))),
                      ),
                    )
                  else
                    Expanded(
                      child: ListView.builder(
                        itemCount: personDebts.length,
                        itemBuilder: (context, index) {
                          final debt = personDebts[index];
                          final isLend = debt.type == 'LEND';
                          
                          return Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            child: PremiumCard(
                              padding: const EdgeInsets.all(16),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: (isLend ? Theme.of(context).colorScheme.primary : Colors.red).withOpacity(0.1),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      isLend ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
                                      size: 16,
                                      color: isLend ? Theme.of(context).colorScheme.primary : Colors.red,
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          debt.description ?? (isLend ? 'Lent Money' : 'Borrowed Money'),
                                          style: GoogleFonts.manrope(fontWeight: FontWeight.w600, fontSize: 14),
                                        ),
                                        Text(
                                          DateFormat('MMM dd, yyyy').format(debt.date),
                                          style: TextStyle(fontSize: 10, color: Colors.white.withOpacity(0.3)),
                                        ),
                                        if (debt.dueDate != null && !debt.isSettled)
                                          Padding(
                                            padding: const EdgeInsets.only(top: 4),
                                            child: Text(
                                              'Due: ${DateFormat('MMM dd').format(debt.dueDate!)}',
                                              style: const TextStyle(fontSize: 10, color: Colors.orange, fontWeight: FontWeight.bold),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text(
                                        'Rs. ${debt.amount.toStringAsFixed(0)}',
                                        style: GoogleFonts.manrope(
                                          fontWeight: FontWeight.w700,
                                          color: isLend ? Theme.of(context).colorScheme.primary : Colors.red,
                                        ),
                                      ),
                                      if (!debt.isSettled)
                                        TextButton(
                                          onPressed: () => _showSettleDialog(context, ref, debt.id!),
                                          style: TextButton.styleFrom(
                                            padding: EdgeInsets.zero,
                                            minimumSize: const Size(0, 0),
                                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                          ),
                                          child: const Text('Settle', style: TextStyle(color: Colors.blueAccent, fontSize: 12, fontWeight: FontWeight.bold)),
                                        )
                                      else
                                        const Text('Settled', style: TextStyle(color: Colors.grey, fontSize: 10)),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          FloatingActionButton.extended(
            heroTag: 'lend',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => LendBorrowScreen(person: person, initialType: 'LEND')),
            ),
            backgroundColor: Theme.of(context).colorScheme.primary,
            foregroundColor: Colors.black,
            icon: const Icon(Icons.upload_rounded),
            label: const Text('Lend'),
          ),
          const SizedBox(height: 12),
          FloatingActionButton.extended(
            heroTag: 'borrow',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => LendBorrowScreen(person: person, initialType: 'BORROW')),
            ),
            backgroundColor: Colors.redAccent,
            foregroundColor: Colors.white,
            icon: const Icon(Icons.download_rounded),
            label: const Text('Borrow'),
          ),
        ],
      ),
    );
  }
}
