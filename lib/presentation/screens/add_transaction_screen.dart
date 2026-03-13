import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cointally/domain/entities/transaction_entity.dart';
import 'package:cointally/presentation/notifiers/transaction_notifier.dart';
import 'package:cointally/presentation/notifiers/account_notifier.dart';
import 'package:cointally/presentation/notifiers/locale_notifier.dart';
import 'package:cointally/presentation/notifiers/category_notifier.dart';
import 'package:cointally/presentation/screens/add_category_screen.dart';
import 'package:cointally/presentation/screens/category_management_screen.dart';
import 'package:cointally/presentation/widgets/sleek_components.dart';
import 'package:cointally/presentation/screens/add_account_screen.dart';
import 'package:cointally/presentation/screens/add_person_screen.dart';
import 'package:cointally/domain/entities/person_entity.dart';
import 'package:cointally/domain/entities/debt_entity.dart';
import 'package:cointally/presentation/notifiers/person_notifier.dart';
import 'package:cointally/presentation/notifiers/debt_notifier.dart';
import 'package:cointally/core/services/notification_service.dart';
import 'package:cointally/data/local/db_helper.dart';
import 'package:intl/intl.dart';
import 'package:cointally/presentation/notifiers/feature_notifier.dart';

class AddTransactionScreen extends ConsumerStatefulWidget {
  final String initialType;
  final TransactionEntity? transaction;
  final Function(TransactionEntity)? onSave;
  
  const AddTransactionScreen({
    super.key, 
    this.initialType = 'EXPENSE', 
    this.transaction,
    this.onSave,
  });

  @override
  ConsumerState<AddTransactionScreen> createState() => _AddTransactionScreenState();
}

class _AddTransactionScreenState extends ConsumerState<AddTransactionScreen> {
  final _amountController = TextEditingController();
  final _merchantController = TextEditingController();

  String _type = 'EXPENSE';
  String _category = 'Other';
  int? _selectedAccountId;
  int? _toAccountId;
  DateTime _selectedDate = DateTime.now();

  // Debt related state
  String _debtType = 'LEND';
  int? _selectedPersonId;
  DateTime? _dueDate;
  bool _remindMe = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _type = widget.initialType;
    
    if (widget.transaction != null) {
      final tx = widget.transaction!;
      _amountController.text = tx.amount.toString();
      _merchantController.text = tx.merchantName ?? '';
      _type = tx.type;
      _category = tx.category;
      _selectedAccountId = tx.accountId;
      _toAccountId = tx.toAccountId;
      _selectedDate = tx.date;
      _isInitialLoad = false; // Prevent overwriting with defaults

      if (tx.debtId != null) {
        _type = 'DEBT'; // Force type if it has a debtId
        final debt = ref.read(debtProvider).debts.firstWhere((d) => d.id == tx.debtId, orElse: () => DebtEntity(personId: -1, amount: 0, type: 'LEND', date: DateTime.now()));
        if (debt.personId != -1) {
          _selectedPersonId = debt.personId;
          _debtType = debt.type;
          _dueDate = debt.dueDate;
          _remindMe = debt.remindMe;
        }
      }
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(accountProvider.notifier).loadAccounts();
    });
  }

  Future<void> _saveTransaction() async {
    final amountText = _amountController.text;
    if (amountText.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter an amount')),
      );
      return;
    }

    final amount = double.tryParse(amountText);
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid amount')),
      );
      return;
    }

    setState(() => _isSaving = true);

    if (_type == 'DEBT') {
      if (_selectedPersonId == null) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select a person')),
        );
        return;
      }

      final debt = DebtEntity(
        id: widget.transaction?.debtId,
        personId: _selectedPersonId!,
        amount: amount,
        type: _debtType,
        description: _merchantController.text.trim().isEmpty ? null : _merchantController.text.trim(),
        date: _selectedDate,
        dueDate: _dueDate,
        remindMe: _remindMe,
        accountId: _selectedAccountId,
      );

      if (widget.transaction?.debtId != null) {
        // Update existing debt
        final db = await DatabaseHelper.instance.database;
        await db.update('debts', debt.toMap(), where: 'id = ?', whereArgs: [debt.id]);
        await ref.read(debtProvider.notifier).loadDebts();
        
        // Also update the linked transaction
        final updatedTx = TransactionEntity(
          id: widget.transaction!.id,
          amount: amount,
          type: _debtType == 'LEND' ? 'EXPENSE' : 'INCOME',
          category: 'Debt: ${_debtType}',
          date: _selectedDate,
          merchantName: _merchantController.text.isNotEmpty ? _merchantController.text : (_debtType == 'LEND' ? 'Lent Money' : 'Borrowed Money'),
          accountId: _selectedAccountId,
          debtId: debt.id,
        );
        await ref.read(transactionProvider.notifier).updateTransaction(updatedTx);
      } else {
        await ref.read(debtProvider.notifier).addDebt(debt);
      }

      if (_remindMe && _dueDate != null) {
        final reminderTime = DateTime(_dueDate!.year, _dueDate!.month, _dueDate!.day, 9, 0);
        if (reminderTime.isAfter(DateTime.now())) {
          final person = ref.read(personProvider).persons.firstWhere((p) => p.id == _selectedPersonId);
          await NotificationService().scheduleNotification(
            id: DateTime.now().millisecondsSinceEpoch.remainder(100000),
            title: _debtType == 'LEND' ? 'Debt Recovery Reminder' : 'Debt Repayment Reminder',
            body: 'Today is the due date for RS. ${amount.toStringAsFixed(0)} with ${person.name}',
            scheduledDate: reminderTime,
          );
        }
      }

      // If opened from pending transactions queue, signal the caller to clear the pending entry.
      // We pass a placeholder transaction — reconcile() in the notifier will mark it as done
      // but since the debt was already permanently saved above, we skip adding a second expense.
      if (widget.onSave != null) {
        final placeholderTx = TransactionEntity(
          amount: amount,
          type: _debtType == 'LEND' ? 'EXPENSE' : 'INCOME',
          category: 'Debt: $_debtType',
          date: _selectedDate,
          merchantName: _merchantController.text.isNotEmpty ? _merchantController.text : (_debtType == 'LEND' ? 'Lent Money' : 'Borrowed Money'),
          accountId: _selectedAccountId,
          isDebtReconcile: true, // Custom marker: notifier should skip addTransaction
        );
        widget.onSave!(placeholderTx);
        return; // Don't fall through to Navigator.pop — onSave handles navigation too
      }
    } else {
      final transaction = TransactionEntity(
        id: widget.transaction?.id,
        amount: amount,
        type: _type,
        category: _type == 'TRANSFER' ? 'Transfer' : _category,
        date: _selectedDate,
        merchantName: _merchantController.text.isNotEmpty ? _merchantController.text : null,
        accountId: _selectedAccountId,
        toAccountId: _type == 'TRANSFER' ? _toAccountId : null,
        isAutoDetected: widget.transaction?.isAutoDetected ?? false,
      );

      if (widget.onSave != null) {
      widget.onSave!(transaction);
      // We don't save to DB here because the caller will handle it (e.g. PendingTransactionsScreen)
      return;
    }

    if (widget.transaction != null) {
        await ref.read(transactionProvider.notifier).updateTransaction(transaction);
      } else {
        await ref.read(transactionProvider.notifier).addTransaction(transaction);
      }
    }

    if (mounted) {
      Navigator.pop(context);
    }
  }

  Future<void> _confirmDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).cardTheme.color,
        title: Text('Delete Transaction?', style: GoogleFonts.manrope(fontWeight: FontWeight.bold)),
        content: Text('This action cannot be undone.', style: GoogleFonts.manrope(color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.7))),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel', style: TextStyle(color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.5))),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      setState(() => _isSaving = true);
      
      if (widget.transaction?.debtId != null) {
        // Delete debt and transaction
        final db = await DatabaseHelper.instance.database;
        await db.delete('debts', where: 'id = ?', whereArgs: [widget.transaction!.debtId]);
        await db.delete('transactions', where: 'id = ?', whereArgs: [widget.transaction!.id]);
        await ref.read(debtProvider.notifier).loadDebts();
        await ref.read(transactionProvider.notifier).loadData();
      } else {
        await ref.read(transactionProvider.notifier).deleteTransaction(widget.transaction!.id!);
      }

      if (mounted) {
        Navigator.pop(context);
      }
    }
  }

  bool _isInitialLoad = true;

  @override
  Widget build(BuildContext context) {
    final accounts = ref.watch(accountProvider).accounts;
    final categoryState = ref.watch(categoryProvider);
    final categories = categoryState.categories;
    final featureState = ref.watch(featureProvider);
    final isZakatEnabled = featureState.isZakatEnabled;
    
    final filteredCategories = categories.where((c) {
      if (c.type != _type) return false;
      if (c.name == 'Zakat' && !isZakatEnabled) return false;
      return true;
    }).toList();

    if (_isInitialLoad && accounts.isNotEmpty && categories.isNotEmpty) {
      _isInitialLoad = false;
      final defaultAccount = accounts.where((a) => a.isDefault).firstOrNull ?? accounts.first;
      _selectedAccountId = defaultAccount.id;
      
      // Initialize category based on current type
      if (filteredCategories.isNotEmpty) {
        _category = filteredCategories.first.name;
      }
    }

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(widget.transaction != null ? 'Edit Transaction' : 'New Transaction', style: GoogleFonts.manrope(fontWeight: FontWeight.w700)),
        actions: [
          if (widget.transaction != null)
            IconButton(
              icon: const Icon(Icons.delete_outline_rounded, color: Colors.red),
              onPressed: () => _confirmDelete(),
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Amount Input Section
            Center(
              child: Column(
                children: [
                  Text(
                    'How much?',
                    style: GoogleFonts.manrope(
                      color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.4),
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _amountController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    textAlign: TextAlign.center,
                    style: GoogleFonts.manrope(
                      fontSize: 42,
                      fontWeight: FontWeight.w800,
                      color: Theme.of(context).textTheme.displayLarge?.color,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Rs. 0',
                      hintStyle: TextStyle(color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.1)),
                      border: InputBorder.none,
                      suffixIcon: IconButton(
                        icon: Icon(Icons.calculate_outlined, color: Theme.of(context).colorScheme.primary),
                        onPressed: _showCalculator,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 40),

            // Type Selector (2x2 Grid)
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              mainAxisSpacing: 8,
              crossAxisSpacing: 12,
              childAspectRatio: 3.0,
              children: [
                _buildTypeToggle('EXPENSE', Icons.remove_rounded, Colors.red),
                _buildTypeToggle('INCOME', Icons.add_rounded, Theme.of(context).colorScheme.primary),
                _buildTypeToggle('TRANSFER', Icons.swap_horiz_rounded, Colors.blue),
                _buildTypeToggle('DEBT', Icons.people_alt_rounded, Colors.orange),
              ],
            ),

            const SizedBox(height: 32),

            // Date Selection
            Text(
              'Date',
              style: GoogleFonts.manrope(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.4),
              ),
            ),
            const SizedBox(height: 8),
            InkWell(
              onTap: () => _selectDate(context),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: Theme.of(context).cardTheme.color,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.05) ?? Colors.white.withOpacity(0.05)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.calendar_today_rounded, size: 20, color: Theme.of(context).colorScheme.primary),
                    const SizedBox(width: 12),
                    Text(
                      DateFormat('MMM dd, yyyy').format(_selectedDate),
                      style: GoogleFonts.manrope(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Theme.of(context).textTheme.bodyLarge?.color,
                      ),
                    ),
                    const Spacer(),
                    Icon(Icons.keyboard_arrow_down_rounded, color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.3)),
                  ],
                ),
              ),
            ),

            if (_type == 'DEBT') ...[
              const SizedBox(height: 32),
              // Person Selection
              Text('Who?', style: GoogleFonts.manrope(fontSize: 14, fontWeight: FontWeight.w600, color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.4))),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: Theme.of(context).cardTheme.color,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.05) ?? Colors.white.withOpacity(0.05)),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<int>(
                    value: _selectedPersonId,
                    isExpanded: true,
                    hint: Text('Select Person', style: TextStyle(color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.3), fontSize: 13)),
                    dropdownColor: Theme.of(context).cardTheme.color,
                    items: [
                      ...ref.watch(personProvider).persons.map((p) => DropdownMenuItem(
                        value: p.id,
                        child: Text(p.name, style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color, fontSize: 14)),
                      )),
                      DropdownMenuItem(
                        value: -1,
                        child: Row(
                          children: [
                            const Icon(Icons.person_add_rounded, color: Color(0xFF109D10), size: 18),
                            const SizedBox(width: 8),
                            Text('Add New Person...', style: GoogleFonts.manrope(color: const Color(0xFF109D10), fontWeight: FontWeight.w700, fontSize: 14)),
                          ],
                        ),
                      ),
                    ],
                    onChanged: (val) async {
                      if (val == -1) {
                        await Navigator.push(context, MaterialPageRoute(builder: (context) => const AddPersonScreen()));
                        // After adding, find the latest person and select it
                        final latestPersons = ref.read(personProvider).persons;
                        if (latestPersons.isNotEmpty) {
                          setState(() => _selectedPersonId = latestPersons.last.id);
                        }
                      } else {
                        setState(() => _selectedPersonId = val);
                      }
                    },
                  ),
                ),
              ),
              const SizedBox(height: 24),
              // Lend/Borrow Toggle
              Row(
                children: [
                  Expanded(
                    child: _buildDebtSubTypeButton('LEND', 'Lending'),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildDebtSubTypeButton('BORROW', 'Borrowing'),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              // Due Date & Reminder
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Due Date', style: GoogleFonts.manrope(fontSize: 12, color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.4))),
                        const SizedBox(height: 8),
                        InkWell(
                          onTap: () => _selectDueDate(context),
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.03), borderRadius: BorderRadius.circular(12)),
                            child: Row(
                              children: [
                                const Icon(Icons.timer_outlined, size: 16, color: Colors.orange),
                                const SizedBox(width: 8),
                                Text(_dueDate == null ? 'Set Due' : DateFormat('MMM dd').format(_dueDate!), style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color, fontSize: 13)),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  if (_dueDate != null)
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                         Text('Remind Me', style: GoogleFonts.manrope(fontSize: 12, color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.4))),
                         Switch(
                          value: _remindMe,
                          onChanged: (val) => setState(() => _remindMe = val),
                          activeColor: Theme.of(context).colorScheme.primary,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ] else if (_type != 'TRANSFER') ...[
              const SizedBox(height: 32),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Select Category',
                    style: GoogleFonts.manrope(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.4),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => AddCategoryScreen()),
                    ),
                    icon: Icon(Icons.add_rounded, size: 18, color: Theme.of(context).colorScheme.primary),
                    label: Text('Manage', style: GoogleFonts.manrope(fontSize: 12, color: Theme.of(context).colorScheme.primary)),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              SizedBox(
                  height: 85,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: filteredCategories.length + 1,
                    itemBuilder: (context, index) {
                      if (index == filteredCategories.length) {
                        // Add New Category Button
                        return Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(builder: (context) => const CategoryManagementScreen()),
                            ),
                            borderRadius: BorderRadius.circular(20),
                            child: Container(
                              width: 70,
                              margin: const EdgeInsets.only(right: 12),
                            decoration: BoxDecoration(
                              color: Theme.of(context).cardTheme.color,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.05) ?? Colors.transparent),
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.add_rounded, color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.2)),
                                const SizedBox(height: 4),
                                Text(
                                  'Add New',
                                  style: GoogleFonts.manrope(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w500,
                                    color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.2),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                      }

                      final cat = filteredCategories[index];
                      final isSelected = _category == cat.name;
                      final categoryColor = cat.color;

                      return Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () => setState(() => _category = cat.name),
                          borderRadius: BorderRadius.circular(20),
                          child: Container(
                            width: 70,
                            margin: const EdgeInsets.only(right: 12),
                            decoration: BoxDecoration(
                              color: isSelected ? categoryColor.withOpacity(0.1) : Theme.of(context).cardTheme.color,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: isSelected ? categoryColor : (Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.05) ?? Colors.transparent),
                              ),
                            ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                cat.icon,
                                color: isSelected ? categoryColor : Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.4),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                cat.name,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.manrope(
                                  fontSize: 12,
                                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                                  color: isSelected ? categoryColor : Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.4),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                    },
                  ),
                ),
            ],

            const SizedBox(height: 16),

            // Merchant / Description
            SleekTextField(
              label: 'Merchant / Description',
              hintText: 'e.g. Whole Foods, Salary...',
              controller: _merchantController,
              prefixIcon: Icons.storefront_rounded,
            ),

            const SizedBox(height: 16),

            // Account Selection
            Text(
              _type == 'TRANSFER' ? 'From Account' : 'Account',
              style: GoogleFonts.manrope(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.6),
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: Theme.of(context).cardTheme.color,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.05) ?? Colors.white.withOpacity(0.05)),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<int>(
                  value: _selectedAccountId,
                  isExpanded: true,
                  hint: Text('Select Source', style: TextStyle(color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.3))),
                  dropdownColor: Theme.of(context).cardTheme.color,
                  icon: Icon(Icons.keyboard_arrow_down_rounded, color: Theme.of(context).colorScheme.primary),
                  items: [
                    ...accounts.map((account) {
                      return DropdownMenuItem<int>(
                        value: account.id,
                        child: Text(account.bankName, style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color)),
                      );
                    }),
                    DropdownMenuItem<int>(
                      value: -1,
                      child: Row(
                        children: [
                          const Icon(Icons.add_circle_outline_rounded, color: Color(0xFF109D10), size: 18),
                          const SizedBox(width: 8),
                          Text('Add New Account...', style: GoogleFonts.manrope(color: const Color(0xFF109D10), fontWeight: FontWeight.w700)),
                        ],
                      ),
                    ),
                  ],
                  onChanged: (val) async {
                    if (val == -1) {
                      await Navigator.push(context, MaterialPageRoute(builder: (context) => const AddAccountScreen()));
                      final latestAccounts = ref.read(accountProvider).accounts;
                      if (latestAccounts.isNotEmpty) {
                        setState(() => _selectedAccountId = latestAccounts.last.id);
                      }
                    } else {
                      setState(() {
                        _selectedAccountId = val;
                        // Avoid conflict: if 'To' account is same as 'From' account, clear 'To'
                        if (_toAccountId == _selectedAccountId) {
                          _toAccountId = null;
                        }
                      });
                    }
                  },
                ),
              ),
            ),

            if (_type == 'TRANSFER') ...[
              const SizedBox(height: 16),
              Text(
                'To Account',
                style: GoogleFonts.manrope(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.6),
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: Theme.of(context).cardTheme.color,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.05) ?? Colors.transparent),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<int>(
                    value: _toAccountId,
                    isExpanded: true,
                    hint: Text('Select Destination', style: TextStyle(color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.3))),
                    dropdownColor: Theme.of(context).cardTheme.color,
                    icon: Icon(Icons.keyboard_arrow_down_rounded, color: Theme.of(context).colorScheme.primary),
                    items: accounts.where((a) => a.id != _selectedAccountId).map((account) {
                      return DropdownMenuItem<int>(
                        value: account.id,
                        child: Text(account.bankName, style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color)),
                      );
                    }).toList(),
                    onChanged: (val) => setState(() => _toAccountId = val),
                  ),
                ),
              ),
            ],

            const SizedBox(height: 16),

            NeonButton(
              text: _isSaving ? 'Processing...' : (widget.transaction != null ? 'Update Transaction' : 'Save Transaction'),
              onPressed: _isSaving ? null : () => _saveTransaction(),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildTypeToggle(String type, IconData icon, Color color) {
    final isSelected = _type == type;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          setState(() {
            _type = type;
            // Filter and select first category of new type
            if (_type != 'TRANSFER' && _type != 'DEBT') {
              final newFiltered = ref.read(categoryProvider).categories.where((c) => c.type == _type).toList();
              if (newFiltered.isNotEmpty) {
                _category = newFiltered.first.name;
              }
            }
          });
        },
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? color.withOpacity(0.1) : Theme.of(context).cardTheme.color,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isSelected ? color : Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.05) ?? Colors.white.withOpacity(0.05),
              width: 1.5,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: isSelected ? color : Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.2), size: 18),
              const SizedBox(width: 8),
              Text(
                type,
                style: GoogleFonts.manrope(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: isSelected ? color : Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.2),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDebtSubTypeButton(String type, String label) {
    final isSelected = _debtType == type;
    final color = type == 'LEND' ? Theme.of(context).colorScheme.primary : Colors.red;
    return InkWell(
      onTap: () => setState(() => _debtType = type),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(0.1) : Theme.of(context).cardTheme.color,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isSelected ? color : (Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.05) ?? Colors.transparent), width: 2),
        ),
        child: Center(
          child: Text(
            label,
            style: GoogleFonts.manrope(
              fontWeight: FontWeight.w700,
              fontSize: 13,
              color: isSelected ? color : Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.4),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            dividerColor: Colors.transparent,
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  Future<void> _selectDueDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _dueDate ?? DateTime.now().add(const Duration(days: 7)),
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            dividerColor: Colors.transparent,
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        _dueDate = picked;
        _remindMe = true;
      });
    }
  }

  void _showCalculator() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => CalculatorSheet(
        initialValue: _amountController.text,
        onDone: (value) {
          setState(() {
            _amountController.text = value;
          });
        },
      ),
    );
  }
}

class CalculatorSheet extends StatefulWidget {
  final String initialValue;
  final Function(String) onDone;

  const CalculatorSheet({
    super.key,
    required this.initialValue,
    required this.onDone,
  });

  @override
  State<CalculatorSheet> createState() => _CalculatorSheetState();
}

class _CalculatorSheetState extends State<CalculatorSheet> {
  String _expression = '';
  String _result = '0';

  @override
  void initState() {
    super.initState();
    _expression = widget.initialValue == '0' ? '' : widget.initialValue;
    _result = widget.initialValue;
  }

  void _onPress(String value) {
    setState(() {
      if (value == 'AC') {
        _expression = '';
        _result = '0';
      } else if (value == 'C') {
        if (_expression.isNotEmpty) {
          _expression = _expression.substring(0, _expression.length - 1);
        }
      } else if (value == '=') {
        _calculate();
        _expression = _result;
      } else {
        _expression += value;
      }
      _calculate();
    });
  }

  void _calculate() {
    if (_expression.isEmpty) {
      _result = '0';
      return;
    }
    
    try {
      // Basic math evaluator for +, -, *, /
      // Using a simple algorithm: split by operators and evaluate
      String exp = _expression.replaceAll('x', '*').replaceAll('÷', '/');
      
      // Handle simple operations without external lib
      // We'll support left-to-right evaluation for simplicity in this helper
      double total = 0;
      List<String> numbers = exp.split(RegExp(r'[+\-*/]'));
      List<String> operators = exp.split(RegExp(r'[0-9.]')).where((s) => s.isNotEmpty).toList();
      
      if (numbers.isNotEmpty && numbers[0].isNotEmpty) {
        total = double.tryParse(numbers[0]) ?? 0;
        for (int i = 0; i < operators.length; i++) {
          if (i + 1 < numbers.length && numbers[i+1].isNotEmpty) {
            double nextVal = double.tryParse(numbers[i+1]) ?? 0;
            switch (operators[i]) {
              case '+': total += nextVal; break;
              case '-': total -= nextVal; break;
              case '*': total *= nextVal; break;
              case '/': if (nextVal != 0) total /= nextVal; break;
            }
          }
        }
      }
      
      if (total == total.toInt()) {
        _result = total.toInt().toString();
      } else {
        _result = total.toStringAsFixed(2);
        if (_result.endsWith('.00')) {
          _result = _result.substring(0, _result.length - 3);
        }
      }
    } catch (e) {
      // If error, just keep current result
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF121212),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 24),
          Container(
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.3),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  _expression.isEmpty ? '0' : _expression,
                  style: GoogleFonts.manrope(
                    fontSize: 24,
                    color: Colors.white.withOpacity(0.5),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Rs. $_result',
                  style: GoogleFonts.manrope(
                    fontSize: 40,
                    fontWeight: FontWeight.w800,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          GridView.count(
            shrinkWrap: true,
            crossAxisCount: 4,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            children: [
              _buildBtn('7'), _buildBtn('8'), _buildBtn('9'), _buildBtn('÷', color: Colors.orange),
              _buildBtn('4'), _buildBtn('5'), _buildBtn('6'), _buildBtn('x', color: Colors.orange),
              _buildBtn('1'), _buildBtn('2'), _buildBtn('3'), _buildBtn('-', color: Colors.orange),
              _buildBtn('AC', color: Colors.red), _buildBtn('0'), _buildBtn('.'), _buildBtn('+', color: Colors.orange),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: NeonButton(
                  text: 'Clear',
                  onPressed: () => _onPress('AC'),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: NeonButton(
                  text: 'Done',
                  onPressed: () {
                    widget.onDone(_result);
                    Navigator.pop(context);
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildBtn(String text, {Color? color}) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _onPress(text),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          decoration: BoxDecoration(
            color: color?.withOpacity(0.1) ?? Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: color?.withOpacity(0.3) ?? Colors.white.withOpacity(0.05)),
          ),
          child: Center(
            child: Text(
              text,
              style: GoogleFonts.manrope(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: color ?? Colors.white,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
