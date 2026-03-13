import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cointally/domain/entities/category_entity.dart';
import 'package:cointally/domain/repository/category_repository.dart';
import 'package:cointally/data/repository/category_repository_impl.dart';
import 'package:cointally/data/local/db_helper.dart';

// State Class
class CategoryState {
  final bool isLoading;
  final List<CategoryEntity> categories;
  final String? errorMessage;

  const CategoryState({
    this.isLoading = false,
    this.categories = const [],
    this.errorMessage,
  });

  CategoryState copyWith({
    bool? isLoading,
    List<CategoryEntity>? categories,
    String? errorMessage,
  }) {
    return CategoryState(
      isLoading: isLoading ?? this.isLoading,
      categories: categories ?? this.categories,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}

// Notifier Class
class CategoryNotifier extends StateNotifier<CategoryState> {
  final CategoryRepository _repository;

  CategoryNotifier(this._repository) : super(const CategoryState()) {
    loadCategories();
  }

  Future<void> loadCategories() async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      var categories = await _repository.getCategories();
      
      // Ensure Zakat category exists for existing users
      final hasZakat = categories.any((c) => c.name == 'Zakat');
      if (!hasZakat) {
        final zakatCategory = CategoryEntity(
          name: 'Zakat',
          icon: Icons.volunteer_activism,
          color: Color(0xFF4CAF50),
          type: 'EXPENSE'
        );
        await _repository.addCategory(zakatCategory);
        categories = await _repository.getCategories(); // Reload
      }

      state = state.copyWith(isLoading: false, categories: categories);
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: 'Failed to load categories: $e');
    }
  }

  Future<void> addCategory(CategoryEntity category) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      await _repository.addCategory(category);
      await loadCategories();
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: 'Failed to add category: $e');
    }
  }

  Future<void> deleteCategory(int id) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      await _repository.deleteCategory(id);
      await loadCategories();
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: 'Failed to delete category: $e');
    }
  }
}

// Providers
final categoryRepositoryProvider = Provider<CategoryRepository>((ref) {
  return CategoryRepositoryImpl(DatabaseHelper.instance);
});

final categoryProvider = StateNotifierProvider<CategoryNotifier, CategoryState>((ref) {
  final repository = ref.watch(categoryRepositoryProvider);
  return CategoryNotifier(repository);
});
