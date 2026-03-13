import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cointally/domain/entities/goal_entity.dart';
import 'package:cointally/presentation/notifiers/goal_notifier.dart';
import 'package:cointally/presentation/notifiers/account_notifier.dart';
import 'package:cointally/presentation/notifiers/category_notifier.dart';
import 'package:cointally/presentation/screens/add_goal_screen.dart';
import 'package:cointally/presentation/widgets/sleek_components.dart';

class GoalListScreen extends ConsumerWidget {
  const GoalListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final goalState = ref.watch(goalProvider);
    final goals = goalState.goals;

    final savingGoals = goals.where((g) => g.type == 'SAVING').toList();
    final debtGoals = goals.where((g) => g.type == 'DEBT').toList();

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text('Financial Goals', style: GoogleFonts.manrope(fontWeight: FontWeight.w700)),
      ),
      body: goalState.isLoading
          ? Center(child: CircularProgressIndicator(color: Theme.of(context).colorScheme.primary))
          : ListView(
              padding: const EdgeInsets.all(24),
              children: [
                if (savingGoals.isNotEmpty) ...[
                  _buildSectionHeader(context, 'Savings Goals'),
                  const SizedBox(height: 16),
                  ...savingGoals.map((goal) => _buildGoalCard(context, ref, goal)).toList(),
                  const SizedBox(height: 32),
                ],
                if (debtGoals.isNotEmpty) ...[
                  _buildSectionHeader(context, 'Debt Payoff'),
                  const SizedBox(height: 16),
                  ...debtGoals.map((goal) => _buildGoalCard(context, ref, goal)).toList(),
                ],
                if (goals.isEmpty)
                  Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const SizedBox(height: 100),
                        Icon(Icons.flag_outlined, size: 64, color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.1)),
                        const SizedBox(height: 16),
                        Text(
                          'No goals yet. Start small!',
                          style: GoogleFonts.manrope(
                            color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.4),
                          ),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 100),
              ],
            ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'add_goal_fab',
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const AddGoalScreen()),
        ),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.black,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: const Icon(Icons.add_rounded, size: 32),
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    return Text(
      title,
      style: GoogleFonts.manrope(
        fontSize: 14,
        fontWeight: FontWeight.w800,
        color: Theme.of(context).colorScheme.primary,
        letterSpacing: 1.2,
      ),
    );
  }

  Widget _buildGoalCard(BuildContext context, WidgetRef ref, GoalEntity goal) {
    final progress = (goal.currentAmount / goal.targetAmount).clamp(0.0, 1.0);
    final progressColor = goal.type == 'SAVING' ? Theme.of(context).colorScheme.primary : Colors.red;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: PremiumCard(
        padding: EdgeInsets.zero,
        onTap: () => _showContributionDialog(context, ref, goal),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (goal.imagePath != null && File(goal.imagePath!).existsSync())
              ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                child: Image.file(
                  File(goal.imagePath!),
                  height: 140,
                  width: double.infinity,
                  fit: BoxFit.cover,
                ),
              ),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        goal.title,
                        style: GoogleFonts.manrope(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Theme.of(context).textTheme.bodyLarge?.color,
                        ),
                      ),
                      IconButton(
                        icon: Icon(Icons.delete_outline_rounded, size: 18, color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.2)),
                        onPressed: () => _confirmDelete(context, ref, goal),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Rs. ${goal.currentAmount.toStringAsFixed(0)}',
                        style: GoogleFonts.manrope(
                          fontWeight: FontWeight.w800,
                          color: progressColor,
                        ),
                      ),
                      Text(
                        'Target: Rs. ${goal.targetAmount.toStringAsFixed(0)}',
                        style: GoogleFonts.manrope(
                          fontSize: 12,
                          color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.4),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: progress,
                      backgroundColor: progressColor.withOpacity(0.1),
                      valueColor: AlwaysStoppedAnimation<Color>(progressColor),
                      minHeight: 8,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerRight,
                    child: Text(
                      '${(progress * 100).toStringAsFixed(0)}%',
                      style: GoogleFonts.manrope(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: progressColor.withOpacity(0.6),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context, WidgetRef ref, GoalEntity goal) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).cardTheme.color,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Delete Goal?', style: GoogleFonts.manrope(fontWeight: FontWeight.w700)),
        content: Text('Are you sure you want to delete "${goal.title}"? This action cannot be undone.', style: GoogleFonts.manrope(color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.6))),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: GoogleFonts.manrope(color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.4))),
          ),
          TextButton(
            onPressed: () {
              ref.read(goalProvider.notifier).deleteGoal(goal.id!);
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Goal "${goal.title}" deleted')),
              );
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showContributionDialog(BuildContext context, WidgetRef ref, GoalEntity goal) {
    final amountController = TextEditingController();
    int? selectedSourceId;
    String? selectedCategoryName;
    
    final accounts = ref.read(accountProvider).accounts;
    final categories = ref.read(categoryProvider).categories.where((c) => c.type == 'INCOME').toList();
    
    if (categories.isNotEmpty) {
      selectedCategoryName = categories.first.name;
    }

    final targetAccount = goal.targetAccountId != null 
        ? (accounts.where((a) => a.id == goal.targetAccountId).firstOrNull ?? accounts.firstOrNull)
        : null;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: Theme.of(context).cardTheme.color,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text('Contribute to Goal', style: GoogleFonts.manrope(fontWeight: FontWeight.w700)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (targetAccount != null) ...[
                  Text(
                    'Destination Account:',
                    style: GoogleFonts.manrope(color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.4), fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    targetAccount.bankName,
                    style: TextStyle(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  const SizedBox(height: 16),
                ],
                Text(
                  'Source (Where it comes from)',
                  style: GoogleFonts.manrope(color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.4), fontSize: 11, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<int>(
                      value: selectedSourceId,
                      hint: Text('Income', style: TextStyle(color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.3), fontSize: 13)),
                      isExpanded: true,
                      dropdownColor: Theme.of(context).cardTheme.color,
                      icon: Icon(Icons.keyboard_arrow_down_rounded, color: Theme.of(context).colorScheme.primary),
                      items: [
                        DropdownMenuItem<int>(
                          value: null,
                          child: Text('Income', style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color?.withOpacity(0.8), fontSize: 13)),
                        ),
                        ...accounts.map((acc) => DropdownMenuItem(
                          value: acc.id,
                          child: Text(acc.bankName, style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color, fontSize: 13)),
                        )),
                      ],
                      onChanged: (val) => setDialogState(() => selectedSourceId = val),
                    ),
                  ),
                ),
                
                if (selectedSourceId == null) ...[
                  const SizedBox(height: 16),
                  Text(
                    'Income Category',
                    style: GoogleFonts.manrope(color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.4), fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: selectedCategoryName,
                        isExpanded: true,
                        dropdownColor: Theme.of(context).cardTheme.color,
                        icon: Icon(Icons.keyboard_arrow_down_rounded, color: Theme.of(context).colorScheme.primary),
                        items: categories.map((cat) => DropdownMenuItem(
                          value: cat.name,
                          child: Text(cat.name, style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color, fontSize: 13)),
                        )).toList(),
                        onChanged: (val) => setDialogState(() => selectedCategoryName = val),
                      ),
                    ),
                  ),
                ],
                
                const SizedBox(height: 16),
                Text(
                  'Amount',
                  style: GoogleFonts.manrope(color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.4), fontSize: 11, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: amountController,
                  keyboardType: TextInputType.number,
                  autofocus: true,
                  style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color),
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.05),
                    hintText: '0.00',
                    hintStyle: TextStyle(color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.2)),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancel', style: GoogleFonts.manrope(color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.4))),
            ),
            TextButton(
              onPressed: () {
                final amount = double.tryParse(amountController.text) ?? 0.0;
                if (amount > 0) {
                  ref.read(goalProvider.notifier).contributeToGoal(
                    goalId: goal.id!,
                    amount: amount,
                    sourceAccountId: selectedSourceId,
                    category: selectedSourceId == null ? selectedCategoryName : null,
                  );
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Contributed Rs. $amount to ${goal.title}')),
                  );
                }
              },
              child: Text('Confirm', style: TextStyle(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }
}
