import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:cointally/domain/entities/person_entity.dart';
import 'package:cointally/domain/entities/debt_entity.dart';
import 'package:cointally/presentation/notifiers/account_notifier.dart';
import 'package:cointally/presentation/notifiers/debt_notifier.dart';
import 'package:cointally/presentation/widgets/sleek_components.dart';
import 'package:cointally/core/services/notification_service.dart';

class LendBorrowScreen extends ConsumerStatefulWidget {
  final PersonEntity? person;
  final String initialType; // 'LEND' or 'BORROW'

  const LendBorrowScreen({super.key, this.person, required this.initialType});

  @override
  ConsumerState<LendBorrowScreen> createState() => _LendBorrowScreenState();
}

class _LendBorrowScreenState extends ConsumerState<LendBorrowScreen> {
  late String _type;
  final _amountController = TextEditingController();
  final _descriptionController = TextEditingController();
  DateTime _selectedDate = DateTime.now();
  DateTime? _dueDate;
  int? _selectedAccountId;
  bool _remindMe = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _type = widget.initialType;
  }

  Future<void> _selectDate(BuildContext context, bool isDueDate) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: isDueDate ? (_dueDate ?? DateTime.now().add(const Duration(days: 7))) : _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
      builder: (context, child) {
        return Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: const ColorScheme.dark(
              primary: Color(0xFF13EC13),
              onPrimary: Colors.black,
              surface: Color(0xFF1A1A1A),
              onSurface: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        if (isDueDate) {
          _dueDate = picked;
          _remindMe = true;
        } else {
          _selectedDate = picked;
        }
      });
    }
  }

  Future<void> _save() async {
    if (_amountController.text.isEmpty || widget.person == null) return;
    
    final amount = double.tryParse(_amountController.text) ?? 0;
    if (amount <= 0) return;

    setState(() => _isSaving = true);

    final debt = DebtEntity(
      personId: widget.person!.id!,
      amount: amount,
      type: _type,
      description: _descriptionController.text.trim().isEmpty ? null : _descriptionController.text.trim(),
      date: _selectedDate,
      dueDate: _dueDate,
      remindMe: _remindMe,
      accountId: _selectedAccountId,
    );

    await ref.read(debtProvider.notifier).addDebt(debt);

    if (_remindMe && _dueDate != null) {
      // Schedule notification for 9 AM on the due date
      final reminderTime = DateTime(_dueDate!.year, _dueDate!.month, _dueDate!.day, 9, 0);
      if (reminderTime.isAfter(DateTime.now())) {
        await NotificationService().scheduleNotification(
          id: DateTime.now().millisecondsSinceEpoch.remainder(100000),
          title: _type == 'LEND' ? 'Debt Recovery Reminder' : 'Debt Repayment Reminder',
          body: 'Today is the due date for RS. ${amount.toStringAsFixed(0)} with ${widget.person!.name}',
          scheduledDate: reminderTime,
        );
      }
    }

    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final accountState = ref.watch(accountProvider);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text('${_type == 'LEND' ? 'Lend to' : 'Borrow from'} ${widget.person?.name ?? 'Person'}', 
          style: GoogleFonts.manrope(fontWeight: FontWeight.w700, fontSize: 18)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            PremiumCard(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _buildTypeButton('LEND', 'Lending'),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildTypeButton('BORROW', 'Borrowing'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  SleekTextField(
                    label: 'Amount',
                    controller: _amountController,
                    hintText: '0.00',
                    keyboardType: TextInputType.number,
                    prefix: Text('Rs. ', style: TextStyle(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(height: 20),
                  SleekTextField(
                    label: 'Description',
                    controller: _descriptionController,
                    hintText: 'What is this for?',
                  ),
                  const SizedBox(height: 24),
                  
                  // Account Selection
                  Text('Source/Destination Account', style: GoogleFonts.manrope(fontSize: 12, color: Colors.white.withOpacity(0.4), fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<int>(
                    value: _selectedAccountId,
                    dropdownColor: const Color(0xFF1F1F1F),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: Colors.white.withOpacity(0.05),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    ),
                    items: [
                      const DropdownMenuItem(value: null, child: Text('No Account (Cash/Manual)', style: TextStyle(color: Colors.white70, fontSize: 13))),
                      ...accountState.accounts.map((acc) => DropdownMenuItem(
                        value: acc.id,
                        child: Text(acc.bankName, style: const TextStyle(color: Colors.white, fontSize: 14)),
                      )),
                    ],
                    onChanged: (val) => setState(() => _selectedAccountId = val),
                  ),
                  
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Date', style: GoogleFonts.manrope(fontSize: 12, color: Colors.white.withOpacity(0.4))),
                            const SizedBox(height: 4),
                            InkWell(
                              onTap: () => _selectDate(context, false),
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
                                decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(12)),
                                child: Row(
                                  children: [
                                    Icon(Icons.calendar_today_rounded, size: 16, color: Theme.of(context).colorScheme.primary),
                                    const SizedBox(width: 8),
                                    Text(DateFormat('MMM dd, yyyy').format(_selectedDate), style: const TextStyle(color: Colors.white, fontSize: 13)),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Due Date', style: GoogleFonts.manrope(fontSize: 12, color: Colors.white.withOpacity(0.4))),
                            const SizedBox(height: 4),
                            InkWell(
                              onTap: () => _selectDate(context, true),
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
                                decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(12)),
                                child: Row(
                                  children: [
                                    const Icon(Icons.timer_outlined, size: 16, color: Colors.orange),
                                    const SizedBox(width: 8),
                                    Text(_dueDate == null ? 'Set Due' : DateFormat('MMM dd, yyyy').format(_dueDate!), style: const TextStyle(color: Colors.white, fontSize: 13)),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  
                  if (_dueDate != null) ...[
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Remind Me', style: GoogleFonts.manrope(fontSize: 14, fontWeight: FontWeight.w600)),
                        Switch(
                          value: _remindMe,
                          onChanged: (val) => setState(() => _remindMe = val),
                          activeColor: Theme.of(context).colorScheme.primary,
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 48),
            SleekButton(
              onTap: _isSaving ? null : _save,
              label: _isSaving ? 'Saving...' : 'Confirm Record',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTypeButton(String type, String label) {
    final isSelected = _type == type;
    return InkWell(
      onTap: () => setState(() => _type = type),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? Theme.of(context).colorScheme.primary.withOpacity(0.1) : Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isSelected ? Theme.of(context).colorScheme.primary : Colors.transparent, width: 2),
        ),
        child: Center(
          child: Text(
            label,
            style: GoogleFonts.manrope(
              fontWeight: FontWeight.w700,
              color: isSelected ? Theme.of(context).colorScheme.primary : Colors.white.withOpacity(0.4),
            ),
          ),
        ),
      ),
    );
  }
}
