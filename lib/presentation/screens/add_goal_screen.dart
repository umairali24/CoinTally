import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:cointally/domain/entities/goal_entity.dart';
import 'package:cointally/presentation/notifiers/goal_notifier.dart';
import 'package:cointally/presentation/notifiers/account_notifier.dart';
import 'package:cointally/presentation/widgets/sleek_components.dart';

class AddGoalScreen extends ConsumerStatefulWidget {
  const AddGoalScreen({super.key});

  @override
  ConsumerState<AddGoalScreen> createState() => _AddGoalScreenState();
}

class _AddGoalScreenState extends ConsumerState<AddGoalScreen> {
  final _titleController = TextEditingController();
  final _amountController = TextEditingController();
  String _selectedType = 'SAVING';
  String? _imagePath;
  int? _selectedAccountId;

  @override
  void dispose() {
    _titleController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);
    
    if (image != null) {
      final appDir = await getApplicationDocumentsDirectory();
      final fileName = p.basename(image.path);
      final savedImage = await File(image.path).copy('${appDir.path}/$fileName');
      setState(() {
        _imagePath = savedImage.path;
      });
    }
  }

  void _saveGoal() {
    final title = _titleController.text.trim();
    final amount = double.tryParse(_amountController.text) ?? 0.0;

    if (title.isEmpty || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid title and amount')),
      );
      return;
    }

    final goal = GoalEntity(
      title: title,
      targetAmount: amount,
      type: _selectedType,
      imagePath: _imagePath,
      targetAccountId: _selectedAccountId,
      createdAt: DateTime.now(),
    );

    ref.read(goalProvider.notifier).addGoal(goal);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final accounts = ref.watch(accountProvider).accounts;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text('New Goal', style: GoogleFonts.manrope(fontWeight: FontWeight.w700)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: GestureDetector(
                onTap: _pickImage,
                child: Container(
                  width: double.infinity,
                  height: 160,
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardTheme.color,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: Theme.of(context).colorScheme.primary.withOpacity(0.3),
                      width: 1.5,
                      style: BorderStyle.solid,
                    ),
                    image: _imagePath != null
                        ? DecorationImage(
                            image: FileImage(File(_imagePath!)),
                            fit: BoxFit.cover,
                          )
                        : null,
                  ),
                  child: _imagePath == null
                      ? Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.add_a_photo_rounded, color: Theme.of(context).colorScheme.primary, size: 40),
                            const SizedBox(height: 12),
                            Text(
                              'Add Motivator Image',
                              style: GoogleFonts.manrope(
                                color: Theme.of(context).colorScheme.primary,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        )
                      : Align(
                          alignment: Alignment.bottomRight,
                          child: Container(
                            margin: const EdgeInsets.all(12),
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.black54,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(Icons.edit_rounded, color: Colors.white, size: 16),
                          ),
                        ),
                ),
              ),
            ),
            const SizedBox(height: 32),
            SleekTextField(
              label: 'Goal Title',
              hintText: 'e.g. Dream Car, Home Loan...',
              controller: _titleController,
              prefixIcon: Icons.flag_rounded,
            ),
            const SizedBox(height: 24),
            SleekTextField(
              label: 'Target Amount',
              hintText: '0.00',
              controller: _amountController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              prefixIcon: Icons.account_balance_wallet_rounded,
            ),
            const SizedBox(height: 24),
            Text(
              'Target Account (Where savings go)',
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
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<int>(
                  value: _selectedAccountId,
                  hint: Text('Select Account', style: TextStyle(color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.3))),
                  isExpanded: true,
                  icon: Icon(Icons.keyboard_arrow_down_rounded, color: Theme.of(context).colorScheme.primary),
                  dropdownColor: Theme.of(context).cardTheme.color,
                  items: accounts.map((acc) {
                    return DropdownMenuItem(
                      value: acc.id,
                      child: Text(acc.bankName),
                    );
                  }).toList(),
                  onChanged: (val) => setState(() => _selectedAccountId = val),
                ),
              ),
            ),
            const SizedBox(height: 32),
            Text(
              'Goal Type',
              style: GoogleFonts.manrope(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.4),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildTypeToggle('SAVING', Icons.savings_rounded, Theme.of(context).colorScheme.primary),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildTypeToggle('DEBT', Icons.money_off_rounded, Colors.red),
                ),
              ],
            ),
            const SizedBox(height: 48),
            NeonButton(
              text: 'Create Goal',
              onPressed: _saveGoal,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTypeToggle(String type, IconData icon, Color color) {
    final isSelected = _selectedType == type;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => setState(() => _selectedType = type),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
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
              Icon(icon, color: isSelected ? color : Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.2), size: 20),
              const SizedBox(width: 8),
              Text(
                type,
                style: GoogleFonts.manrope(
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                  color: isSelected ? color : Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.2),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
