import 'package:cointally/domain/entities/category_entity.dart';

abstract class CategoryRepository {
  Future<List<CategoryEntity>> getCategories();
  Future<int> addCategory(CategoryEntity category);
  Future<void> deleteCategory(int id);
}
