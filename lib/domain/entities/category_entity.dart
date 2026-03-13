import 'package:flutter/material.dart';

class CategoryEntity {
  final int? id;
  final String name;
  final IconData icon;
  final Color color;
  final String type; // 'INCOME' or 'EXPENSE'

  CategoryEntity({
    this.id,
    required this.name,
    required this.icon,
    this.color = const Color(0xFF13EC13),
    this.type = 'EXPENSE',
  });

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'name': name,
      'icon_code': icon.codePoint,
      'icon_family': icon.fontFamily,
      'icon_package': icon.fontPackage,
      'color_hex': '#${color.value.toRadixString(16).padLeft(8, '0').substring(2).toUpperCase()}',
      'type': type,
    };
  }

  factory CategoryEntity.fromMap(Map<String, dynamic> map) {
    return CategoryEntity(
      id: map['id'] as int?,
      name: map['name'] as String,
      icon: IconData(
        map['icon_code'] as int,
        fontFamily: map['icon_family'] as String?,
        fontPackage: map['icon_package'] as String?,
      ),
      color: _parseColor(map['color_hex'] as String?),
      type: map['type'] as String? ?? 'EXPENSE',
    );
  }

  static Color _parseColor(String? hex) {
    if (hex == null || hex.isEmpty) return const Color(0xFF13EC13);
    try {
      final buffer = StringBuffer();
      if (hex.length == 6 || hex.length == 7) buffer.write('ff');
      buffer.write(hex.replaceFirst('#', ''));
      return Color(int.parse(buffer.toString(), radix: 16));
    } catch (e) {
      return const Color(0xFF13EC13);
    }
  }

  CategoryEntity copyWith({
    int? id,
    String? name,
    IconData? icon,
    Color? color,
    String? type,
  }) {
    return CategoryEntity(
      id: id ?? this.id,
      name: name ?? this.name,
      icon: icon ?? this.icon,
      color: color ?? this.color,
      type: type ?? this.type,
    );
  }
}
