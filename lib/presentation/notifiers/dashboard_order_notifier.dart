import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DashboardWidgetConfig {
  final String id;
  final String title;
  final bool isVisible;
  final String description;

  const DashboardWidgetConfig({
    required this.id,
    required this.title,
    this.isVisible = true,
    this.description = '',
  });

  DashboardWidgetConfig copyWith({
    String? id,
    String? title,
    bool? isVisible,
    String? description,
  }) {
    return DashboardWidgetConfig(
      id: id ?? this.id,
      title: title ?? this.title,
      isVisible: isVisible ?? this.isVisible,
      description: description ?? this.description,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'isVisible': isVisible,
      'description': description,
    };
  }

  factory DashboardWidgetConfig.fromJson(Map<String, dynamic> json) {
    return DashboardWidgetConfig(
      id: json['id'] as String,
      title: json['title'] as String,
      isVisible: json['isVisible'] as bool? ?? true,
      description: json['description'] as String? ?? '',
    );
  }
}

class DashboardOrderNotifier extends StateNotifier<List<DashboardWidgetConfig>> {
  DashboardOrderNotifier() : super(_defaultWidgets) {
    _loadPreferences();
  }

  static const _prefsKey = 'dashboard_widget_order';

  static const List<DashboardWidgetConfig> _defaultWidgets = [
    DashboardWidgetConfig(id: 'net_liquidity', title: 'Net Liquidity', description: 'Overview of assets and liabilities'),
    DashboardWidgetConfig(id: 'monthly_budget', title: 'Monthly Budget', description: 'Your current monthly budget progress'),
    DashboardWidgetConfig(id: 'cashflow', title: 'Cashflow Overview', description: 'Income vs expense visual breakdown'),
    DashboardWidgetConfig(id: 'accounts', title: 'Accounts Widget', description: 'Quick access to your accounts and balances'),
    DashboardWidgetConfig(id: 'goals', title: 'Goals Preview', description: 'Progress on your top goals'),
    DashboardWidgetConfig(id: 'recent_activity', title: 'Recent Activity', description: 'List of recent transactions'),
  ];

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    final String? data = prefs.getString(_prefsKey);
    
    if (data != null) {
      try {
        final List<dynamic> decoded = jsonDecode(data);
        final loadedWidgets = decoded.map((e) => DashboardWidgetConfig.fromJson(e)).toList();
        
        // Handle potentially new widgets that were added after user saved prefs
        final currentWidgetIds = loadedWidgets.map((w) => w.id).toSet();
        final newWidgets = _defaultWidgets.where((w) => !currentWidgetIds.contains(w.id));
        
        state = [...loadedWidgets, ...newWidgets];
      } catch (e) {
        state = _defaultWidgets;
      }
    } else {
      state = _defaultWidgets;
    }
  }

  Future<void> _savePreferences() async {
    final prefs = await SharedPreferences.getInstance();
    final String encoded = jsonEncode(state.map((e) => e.toJson()).toList());
    await prefs.setString(_prefsKey, encoded);
  }

  void toggleVisibility(String id) {
    state = state.map((w) {
      if (w.id == id) {
        return w.copyWith(isVisible: !w.isVisible);
      }
      return w;
    }).toList();
    _savePreferences();
  }

  void reorder(int oldIndex, int newIndex) {
    if (oldIndex < newIndex) {
      newIndex -= 1;
    }
    final item = state[oldIndex];
    final updatedList = List<DashboardWidgetConfig>.from(state)..removeAt(oldIndex)..insert(newIndex, item);
    state = updatedList;
    _savePreferences();
  }
}

final dashboardOrderProvider = StateNotifierProvider<DashboardOrderNotifier, List<DashboardWidgetConfig>>((ref) {
  return DashboardOrderNotifier();
});
