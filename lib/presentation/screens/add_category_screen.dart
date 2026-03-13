import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cointally/domain/entities/category_entity.dart';
import 'package:cointally/presentation/notifiers/category_notifier.dart';
import 'package:cointally/presentation/widgets/sleek_components.dart';
import 'package:cointally/core/constants/app_icons.dart';

class AddCategoryScreen extends ConsumerStatefulWidget {
  const AddCategoryScreen({super.key});

  @override
  ConsumerState<AddCategoryScreen> createState() => _AddCategoryScreenState();
}

class _AddCategoryScreenState extends ConsumerState<AddCategoryScreen> {
  final _nameController = TextEditingController();
  IconData _selectedIcon = AppIcons.expenseGroupedIcons.values.first.first;
  Color _selectedColor = const Color(0xFF13EC13);
  String _selectedType = 'EXPENSE';

  final List<Color> _availableColors = [
    const Color(0xFF13EC13), // Neon Green
    const Color(0xFFFF5252), // Red
    const Color(0xFFFFD740), // Amber
    const Color(0xFF448AFF), // Blue
    const Color(0xFFE040FB), // Purple
    const Color(0xFFFF9100), // Orange
    const Color(0xFF00E5FF), // Cyan
    const Color(0xFFFF4081), // Pink
    const Color(0xFFB2FF59), // Light Green
    const Color(0xFF7C4DFF), // Deep Purple
    const Color(0xFF9E9E9E), // Grey
  ];

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _saveCategory() {
    if (_nameController.text.isEmpty) return;

    final category = CategoryEntity(
      name: _nameController.text.trim(),
      icon: _selectedIcon,
      color: _selectedColor,
      type: _selectedType,
    );

    ref.read(categoryProvider.notifier).addCategory(category);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text('Add Category', style: GoogleFonts.manrope(fontWeight: FontWeight.w700)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SleekTextField(
              label: 'Category Name',
              hintText: 'e.g. Gym, Amazon...',
              controller: _nameController,
              prefixIcon: Icons.label_outline_rounded,
            ),
            const SizedBox(height: 32),
            Text(
              'Category Type',
              style: GoogleFonts.manrope(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).textTheme.bodyMedium?.color?.withValues(alpha: 0.4),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildTypeToggle('EXPENSE', Icons.remove_rounded, Colors.red),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildTypeToggle('INCOME', Icons.add_rounded, Theme.of(context).colorScheme.primary),
                ),
              ],
            ),
            const SizedBox(height: 32),
            Text(
              'Select Icon',
              style: GoogleFonts.manrope(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).textTheme.bodyMedium?.color?.withValues(alpha: 0.4),
              ),
            ),
            const SizedBox(height: 16),
            ...(_selectedType == 'INCOME' ? AppIcons.incomeGroupedIcons : AppIcons.expenseGroupedIcons).entries.map((entry) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 8.0, bottom: 16.0),
                    child: Text(
                      entry.key,
                      style: GoogleFonts.manrope(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Theme.of(context).textTheme.titleLarge?.color,
                      ),
                    ),
                  ),
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 5,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                    ),
                    itemCount: entry.value.length,
                    itemBuilder: (context, index) {
                      final icon = entry.value[index];
                      final isSelected = _selectedIcon == icon;

                      // Fix withValues deprecation dynamically
                      return Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () => setState(() => _selectedIcon = icon),
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            decoration: BoxDecoration(
                              color: isSelected ? _selectedColor.withValues(alpha: 0.1) : Theme.of(context).cardTheme.color,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isSelected 
                                  ? _selectedColor 
                                  : (Theme.of(context).textTheme.bodyMedium?.color?.withValues(alpha: 0.05) ?? Colors.grey.withValues(alpha: 0.05)),
                              ),
                            ),
                            child: Icon(
                              icon,
                              color: isSelected 
                                ? _selectedColor 
                                : Theme.of(context).textTheme.bodyMedium?.color?.withValues(alpha: 0.3),
                              size: 24,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 24),
                ],
              );
            }),
            const SizedBox(height: 32),
            Text(
              'Select Color',
              style: GoogleFonts.manrope(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).textTheme.bodyMedium?.color?.withValues(alpha: 0.4),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 50,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _availableColors.length,
                separatorBuilder: (context, index) => const SizedBox(width: 12),
                itemBuilder: (context, index) {
                  final color = _availableColors[index];
                  final isSelected = _selectedColor == color;

                  return GestureDetector(
                    onTap: () => setState(() => _selectedColor = color),
                    child: Container(
                      width: 50,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isSelected ? (Theme.of(context).textTheme.bodyLarge?.color ?? Colors.white) : Colors.transparent,
                          width: 3,
                        ),
                        boxShadow: isSelected ? [
                          BoxShadow(
                            color: color.withValues(alpha: 0.4),
                            blurRadius: 10,
                            spreadRadius: 2,
                          )
                        ] : null,
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 48),
            NeonButton(
              text: 'Create Category',
              onPressed: _saveCategory,
            ),
            const SizedBox(height: 40),
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
        onTap: () {
          setState(() {
            _selectedType = type;
            // Reset the icon to the first element of the new type's list to avoid invalid icon retention
            _selectedIcon = type == 'INCOME' 
                ? AppIcons.incomeGroupedIcons.values.first.first 
                : AppIcons.expenseGroupedIcons.values.first.first;
          });
        },
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? color.withValues(alpha: 0.1) : Theme.of(context).cardTheme.color,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isSelected ? color : Theme.of(context).textTheme.bodyMedium?.color?.withValues(alpha: 0.05) ?? Colors.white.withValues(alpha: 0.05),
              width: 1.5,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: isSelected ? color : Theme.of(context).textTheme.bodyMedium?.color?.withValues(alpha: 0.2), size: 18),
              const SizedBox(width: 8),
              Text(
                type,
                style: GoogleFonts.manrope(
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                  color: isSelected ? color : Theme.of(context).textTheme.bodyMedium?.color?.withValues(alpha: 0.2),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
