import 'package:cointally/data/local/db_helper.dart';
import 'package:cointally/domain/entities/category_entity.dart';
import 'package:cointally/domain/repository/category_repository.dart';

class CategoryRepositoryImpl implements CategoryRepository {
  final DatabaseHelper _dbHelper;

  CategoryRepositoryImpl(this._dbHelper);

  @override
  Future<List<CategoryEntity>> getCategories() async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query('categories');
    return maps.map((map) => CategoryEntity.fromMap(map)).toList();
  }

  @override
  Future<int> addCategory(CategoryEntity category) async {
    final db = await _dbHelper.database;
    return await db.insert('categories', category.toMap());
  }

  @override
  Future<void> deleteCategory(int id) async {
    final db = await _dbHelper.database;
    await db.delete('categories', where: 'id = ?', whereArgs: [id]);
  }
}
