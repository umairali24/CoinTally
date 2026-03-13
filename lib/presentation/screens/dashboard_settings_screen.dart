import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cointally/presentation/notifiers/locale_notifier.dart';
import 'package:cointally/presentation/notifiers/dashboard_order_notifier.dart';

class DashboardSettingsScreen extends ConsumerWidget {
  const DashboardSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final localeNotifier = ref.read(localeProvider.notifier);
    final widgets = ref.watch(dashboardOrderProvider);
    final notifier = ref.read(dashboardOrderProvider.notifier);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'Dashboard Layout',
          style: GoogleFonts.manrope(fontWeight: FontWeight.w700),
        ),
      ),
      body: ReorderableListView.builder(
        padding: const EdgeInsets.all(24.0),
        itemCount: widgets.length,
        onReorder: (oldIndex, newIndex) {
          notifier.reorder(oldIndex, newIndex);
        },
        itemBuilder: (context, index) {
          final widgetConfig = widgets[index];
          return Container(
            key: ValueKey(widgetConfig.id),
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: Theme.of(context).cardTheme.color,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                  color: Theme.of(context)
                          .textTheme
                          .bodyMedium
                          ?.color
                          ?.withOpacity(0.05) ??
                      Colors.white.withOpacity(0.05)),
            ),
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              leading: Icon(Icons.drag_indicator_rounded,
                  color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.4)),
              title: Text(
                widgetConfig.title,
                style: GoogleFonts.manrope(
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).textTheme.bodyLarge?.color,
                ),
              ),
              subtitle: Text(
                widgetConfig.description,
                style: GoogleFonts.manrope(
                  fontSize: 12,
                  color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.4),
                ),
              ),
              trailing: Switch(
                value: widgetConfig.isVisible,
                onChanged: (_) => notifier.toggleVisibility(widgetConfig.id),
                activeColor: Theme.of(context).colorScheme.primary,
              ),
            ),
          );
        },
      ),
    );
  }
}
