import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cointally/domain/entities/budget_entity.dart';
import 'package:cointally/presentation/notifiers/budget_notifier.dart';
import 'package:cointally/presentation/notifiers/category_notifier.dart';
import 'package:cointally/presentation/screens/add_category_screen.dart';
import 'package:cointally/presentation/widgets/sleek_components.dart';

class BudgetCreationScreen extends ConsumerStatefulWidget {
  final BudgetEntity? existingBudget;

  const BudgetCreationScreen({super.key, this.existingBudget});

  @override
  ConsumerState<BudgetCreationScreen> createState() => _BudgetCreationScreenState();
}

class _BudgetCreationScreenState extends ConsumerState<BudgetCreationScreen> {
  late String _selectedCategory;
  late TextEditingController _limitController;
  late bool _isOverall;

  @override
  void initState() {
    super.initState();
    _isOverall = widget.existingBudget?.isOverall ?? false;
    _selectedCategory = widget.existingBudget?.category ?? 'Food';
    _limitController = TextEditingController(
      text: widget.existingBudget?.monthlyLimit.toStringAsFixed(0) ?? '',
    );
  }

  @override
  void dispose() {
    _limitController.dispose();
    super.dispose();
  }

  void _saveBudget() {
    if (_limitController.text.isEmpty) return;

    final limit = double.tryParse(_limitController.text) ?? 0.0;
    if (limit <= 0) return;

    final budgets = ref.read(budgetProvider).budgets;

    // Enforcement: Only one overall budget
    if (_isOverall && widget.existingBudget == null) {
      if (budgets.any((b) => b.isOverall)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('An overall budget already exists.')),
        );
        return;
      }
    }

    // Intelligent Validation Scenarios
    final overallBudget = budgets.where((b) => b.isOverall).firstOrNull;
    final categoryBudgets = budgets.where((b) => !b.isOverall).toList();
    
    // Calculate total of existing category budgets (excluding the one being edited)
    double totalCategoryBudget = categoryBudgets
        .where((b) => b.id != widget.existingBudget?.id)
        .fold(0, (sum, b) => sum + b.monthlyLimit);

    if (_isOverall) {
      // Scenario: New overall budget is less than total categories
      if (limit < totalCategoryBudget) {
        _showExceedWarning(
          title: 'Lower than Categories',
          message: 'Your new overall limit (Rs. ${limit.toStringAsFixed(0)}) is lower than the total of your category budgets (Rs. ${totalCategoryBudget.toStringAsFixed(0)}).',
          onConfirm: () => _performSave(limit),
        );
        return;
      }
    } else {
      // Scenario: Category budget + others exceeds overall limit
      if (overallBudget != null) {
        final newTotalCategories = totalCategoryBudget + limit;
        if (newTotalCategories > overallBudget.monthlyLimit) {
          _showExceedWarning(
            title: 'Exceeding Overall Limit',
            message: 'Setting this category budget to Rs. ${limit.toStringAsFixed(0)} will bring your total category limit to Rs. ${newTotalCategories.toStringAsFixed(0)}, which exceeds your overall monthly budget of Rs. ${overallBudget.monthlyLimit.toStringAsFixed(0)}.',
            onConfirm: () => _performSave(limit),
          );
          return;
        }
      }
    }

    _performSave(limit);
  }

  void _performSave(double limit) {
    final budget = BudgetEntity(
      id: widget.existingBudget?.id,
      category: _isOverall ? 'Total' : _selectedCategory,
      monthlyLimit: limit,
      period: 'MONTHLY',
      isOverall: _isOverall,
    );

    if (widget.existingBudget == null) {
      ref.read(budgetProvider.notifier).addBudget(budget);
    } else {
      ref.read(budgetProvider.notifier).updateBudget(budget);
    }

    Navigator.pop(context);
  }

  void _showExceedWarning({required String title, required String message, required VoidCallback onConfirm}) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).cardTheme.color,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.orange[400]),
            const SizedBox(width: 12),
            Text(title, style: GoogleFonts.manrope(fontWeight: FontWeight.w700, fontSize: 18)),
          ],
        ),
        content: Text(
          message,
          style: GoogleFonts.manrope(
            color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.7),
            fontSize: 14,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Stay in Budget', style: GoogleFonts.manrope(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.bold)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              onConfirm();
            },
            child: Text('Exceed Budget', style: GoogleFonts.manrope(color: Colors.red[400], fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final categories = ref.watch(categoryProvider).categories;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(widget.existingBudget == null ? 'New Budget' : 'Edit Budget', 
          style: GoogleFonts.manrope(fontWeight: FontWeight.w700)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Budget Type Toggle
            PremiumCard(
              padding: const EdgeInsets.all(8),
              child: Row(
                children: [
                  Expanded(
                    child: _buildTypeButton('Overall', _isOverall, () => setState(() => _isOverall = true)),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildTypeButton('Category', !_isOverall, () => setState(() => _isOverall = false)),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 20),

            if (!_isOverall) ...[
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
              const SizedBox(height: 12),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 4,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                  childAspectRatio: 1.0,
                ),
                itemCount: categories.length,
                itemBuilder: (context, index) {
                  final cat = categories[index];
                  final isSelected = _selectedCategory == cat.name;

                  return Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () => setState(() => _selectedCategory = cat.name),
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        decoration: BoxDecoration(
                          color: isSelected ? Theme.of(context).colorScheme.primary.withOpacity(0.1) : Theme.of(context).cardTheme.color,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isSelected ? Theme.of(context).colorScheme.primary : (Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.05) ?? Colors.white.withOpacity(0.05)),
                          ),
                        ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            cat.icon,
                            color: isSelected ? Theme.of(context).colorScheme.primary : (Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.3) ?? Colors.white.withOpacity(0.3)),
                            size: 20,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            cat.name,
                            textAlign: TextAlign.center,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.manrope(
                              fontSize: 11,
                              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                              color: isSelected ? Theme.of(context).colorScheme.primary : (Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.3) ?? Colors.white.withOpacity(0.3)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
                },
              ),
              const SizedBox(height: 20),
            ],

            SleekTextField(
              label: _isOverall ? 'Total Monthly Limit (Rs.)' : 'Monthly Limit (Rs.)',
              hintText: 'e.g. 50000',
              controller: _limitController,
              prefixIcon: Icons.account_balance_wallet_outlined,
            ),
            
            const SizedBox(height: 32),

            NeonButton(
              text: widget.existingBudget == null ? 'Create Budget' : 'Update Budget',
              onPressed: _saveBudget,
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildTypeButton(String label, bool isSelected, VoidCallback onTap) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? Theme.of(context).colorScheme.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: GoogleFonts.manrope(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: isSelected ? Colors.black : Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.4),
            ),
          ),
        ),
      ),
    );
  }
}
