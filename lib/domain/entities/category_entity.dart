import 'package:flutter/material.dart';
import 'package:cointally/core/constants/app_icons.dart';

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
      icon: _iconFromStoredValues(
        map['icon_code'] as int,
        map['icon_family'] as String?,
        map['icon_package'] as String?,
      ),
      color: _parseColor(map['color_hex'] as String?),
      type: map['type'] as String? ?? 'EXPENSE',
    );
  }

  static IconData _iconFromStoredValues(
    int codePoint,
    String? fontFamily,
    String? fontPackage,
  ) {
    for (final icon in _supportedIcons) {
      if (icon.codePoint == codePoint &&
          icon.fontFamily == fontFamily &&
          icon.fontPackage == fontPackage) {
        return icon;
      }
    }

    return Icons.category_rounded;
  }

  static final List<IconData> _supportedIcons = [
    for (final icons in AppIcons.expenseGroupedIcons.values) ...icons,
    for (final icons in AppIcons.incomeGroupedIcons.values) ...icons,
    Icons.category_rounded,
    Icons.help_outline,
    Icons.receipt_long_rounded,
    Icons.volunteer_activism,
  ];

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
