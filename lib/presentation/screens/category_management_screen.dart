import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cointally/presentation/notifiers/category_notifier.dart';
import 'package:cointally/presentation/screens/add_category_screen.dart';
import 'package:cointally/presentation/widgets/sleek_components.dart';

class CategoryManagementScreen extends ConsumerWidget {
  const CategoryManagementScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categoryState = ref.watch(categoryProvider);
    final categories = categoryState.categories;

    final expenseCategories = categories.where((c) => c.type == 'EXPENSE').toList();
    final incomeCategories = categories.where((c) => c.type == 'INCOME').toList();

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text('Manage Categories', style: GoogleFonts.manrope(fontWeight: FontWeight.w700)),
      ),
      body: categoryState.isLoading
          ? Center(child: CircularProgressIndicator(color: Theme.of(context).colorScheme.primary))
          : ListView(
              padding: const EdgeInsets.all(24),
              children: [
                if (incomeCategories.isNotEmpty) ...[
                  _buildSectionHeader(context, 'Income Categories'),
                  const SizedBox(height: 16),
                  ...incomeCategories.map((cat) => _buildCategoryTile(context, ref, cat)).toList(),
                  const SizedBox(height: 32),
                ],
                if (expenseCategories.isNotEmpty) ...[
                  _buildSectionHeader(context, 'Expense Categories'),
                  const SizedBox(height: 16),
                  ...expenseCategories.map((cat) => _buildCategoryTile(context, ref, cat)).toList(),
                ],
                const SizedBox(height: 80),
              ],
            ),
      floatingActionButton: FloatingActionButton(
        heroTag: null,
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const AddCategoryScreen()),
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

  Widget _buildCategoryTile(BuildContext context, WidgetRef ref, dynamic category) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.05) ?? Colors.white.withOpacity(0.05)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: category.color.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(category.icon, color: category.color, size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              category.name,
              style: GoogleFonts.manrope(
                fontWeight: FontWeight.w700,
                color: Theme.of(context).textTheme.bodyLarge?.color,
              ),
            ),
          ),
          if (category.name != 'Zakat')
            IconButton(
              icon: Icon(Icons.delete_outline_rounded, color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.2), size: 20),
              onPressed: () => _showDeleteDialog(context, ref, category.id!, category.name),
            ),
        ],
      ),
    );
  }

  void _showDeleteDialog(BuildContext context, WidgetRef ref, int id, String name) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).cardTheme.color,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Delete Category', style: GoogleFonts.manrope(fontWeight: FontWeight.w700)),
        content: Text('Are you sure you want to delete the "$name" category?', style: GoogleFonts.manrope(color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.6))),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: GoogleFonts.manrope(color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.4))),
          ),
          TextButton(
            onPressed: () {
              ref.read(categoryProvider.notifier).deleteCategory(id);
              Navigator.pop(context);
            },
            child: Text('Delete', style: GoogleFonts.manrope(color: Colors.red, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}
