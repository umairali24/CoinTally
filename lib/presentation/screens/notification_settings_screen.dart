import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cointally/domain/repository/preference_repository.dart';
import 'package:cointally/presentation/notifiers/locale_notifier.dart';
import 'package:cointally/data/repository/preference_repository_impl.dart';
import 'package:cointally/core/services/notification_service.dart';
import 'package:permission_handler/permission_handler.dart';

class NotificationSettingsState {
  final bool isDailyReminderEnabled;
  final String dailyReminderTime;
  final bool isAutoCaptureNotificationsEnabled;

  NotificationSettingsState({
    required this.isDailyReminderEnabled,
    required this.dailyReminderTime,
    required this.isAutoCaptureNotificationsEnabled,
  });

  NotificationSettingsState copyWith({
    bool? isDailyReminderEnabled,
    String? dailyReminderTime,
    bool? isAutoCaptureNotificationsEnabled,
  }) {
    return NotificationSettingsState(
      isDailyReminderEnabled: isDailyReminderEnabled ?? this.isDailyReminderEnabled,
      dailyReminderTime: dailyReminderTime ?? this.dailyReminderTime,
      isAutoCaptureNotificationsEnabled: isAutoCaptureNotificationsEnabled ?? this.isAutoCaptureNotificationsEnabled,
    );
  }
}

class NotificationSettingsNotifier extends StateNotifier<NotificationSettingsState> {
  final PreferenceRepository _prefRepo;

  NotificationSettingsNotifier(this._prefRepo)
      : super(NotificationSettingsState(
          isDailyReminderEnabled: false,
          dailyReminderTime: '20:00',
          isAutoCaptureNotificationsEnabled: false,
        )) {
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final enabled = await _prefRepo.isDailyReminderEnabled();
    final time = await _prefRepo.getDailyReminderTime();
    final autoNotify = await _prefRepo.isAutoCaptureNotificationsEnabled();
    state = NotificationSettingsState(
      isDailyReminderEnabled: enabled,
      dailyReminderTime: time,
      isAutoCaptureNotificationsEnabled: autoNotify,
    );
  }

  Future<bool> _requestPermission() async {
    if (await Permission.notification.isGranted) return true;
    final status = await Permission.notification.request();
    return status.isGranted;
  }

  Future<void> toggleDailyReminder(bool value) async {
    if (value) {
      final granted = await _requestPermission();
      if (!granted) return;
      
      final timeParts = state.dailyReminderTime.split(':');
      await NotificationService().scheduleDailyReminder(
        int.parse(timeParts[0]),
        int.parse(timeParts[1]),
      );
    } else {
      await NotificationService().cancelDailyReminder();
    }
    await _prefRepo.setDailyReminderEnabled(value);
    state = state.copyWith(isDailyReminderEnabled: value);
  }

  Future<void> updateReminderTime(String time) async {
    await _prefRepo.setDailyReminderTime(time);
    state = state.copyWith(dailyReminderTime: time);
    
    if (state.isDailyReminderEnabled) {
      final timeParts = time.split(':');
      await NotificationService().scheduleDailyReminder(
        int.parse(timeParts[0]),
        int.parse(timeParts[1]),
      );
    }
  }

  Future<void> toggleAutoCaptureNotifications(bool value) async {
    if (value) {
      final granted = await _requestPermission();
      if (!granted) return;
    }
    await _prefRepo.setAutoCaptureNotificationsEnabled(value);
    state = state.copyWith(isAutoCaptureNotificationsEnabled: value);
  }
}

final preferenceRepositoryProvider = Provider<PreferenceRepository>((ref) => PreferenceRepositoryImpl());

final notificationSettingsProvider = StateNotifierProvider<NotificationSettingsNotifier, NotificationSettingsState>((ref) {
  final repo = ref.watch(preferenceRepositoryProvider);
  return NotificationSettingsNotifier(repo);
});

class NotificationSettingsScreen extends ConsumerWidget {
  const NotificationSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(notificationSettingsProvider);
    final notifier = ref.read(notificationSettingsProvider.notifier);
    final localeNotifier = ref.read(localeProvider.notifier);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          localeNotifier.translate('notifications'),
          style: GoogleFonts.manrope(fontWeight: FontWeight.w700),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionHeader(context, localeNotifier.translate('daily_reminder')),
            const SizedBox(height: 16),
            _buildFeatureSwitch(
              context,
              localeNotifier.translate('daily_reminder'),
              localeNotifier.translate('daily_reminder_desc'),
              Icons.notifications_active_rounded,
              state.isDailyReminderEnabled,
              (val) => notifier.toggleDailyReminder(val),
            ),
            if (state.isDailyReminderEnabled) ...[
              const SizedBox(height: 12),
              _buildSettingTile(
                context,
                localeNotifier.translate('reminder_time'),
                state.dailyReminderTime,
                Icons.access_time_filled_rounded,
                () => _selectTime(context, ref, state.dailyReminderTime),
              ),
            ],
            const SizedBox(height: 32),
            _buildSectionHeader(context, localeNotifier.translate('smart_capture_alerts')),
            const SizedBox(height: 16),
            _buildFeatureSwitch(
              context,
              localeNotifier.translate('notify_on_auto_capture'),
              localeNotifier.translate('smart_capture_desc'),
              Icons.auto_awesome_rounded,
              state.isAutoCaptureNotificationsEnabled,
              (val) => notifier.toggleAutoCaptureNotifications(val),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _selectTime(BuildContext context, WidgetRef ref, String currentTime) async {
    final parts = currentTime.split(':');
    final initialTime = TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
    
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: initialTime,
    );

    if (picked != null) {
      final formattedTime = '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
      ref.read(notificationSettingsProvider.notifier).updateReminderTime(formattedTime);
    }
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

  Widget _buildFeatureSwitch(
    BuildContext context,
    String title,
    String subtitle,
    IconData icon,
    bool value,
    Function(bool) onChanged,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.05) ?? Colors.white.withOpacity(0.05)),
      ),
      child: SwitchListTile(
        value: value,
        onChanged: onChanged,
        secondary: Icon(icon, color: Theme.of(context).colorScheme.primary, size: 24),
        title: Text(
          title,
          style: GoogleFonts.manrope(
            fontWeight: FontWeight.w600,
            color: Theme.of(context).textTheme.bodyLarge?.color,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: GoogleFonts.manrope(
            fontSize: 12,
            color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.4),
          ),
        ),
        activeColor: Theme.of(context).colorScheme.primary,
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      ),
    );
  }

  Widget _buildSettingTile(
    BuildContext context,
    String title,
    String value,
    IconData icon,
    VoidCallback? onTap,
  ) {
    return Container(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Theme.of(context).cardTheme.color,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.05) ?? Colors.white.withOpacity(0.05)),
            ),
            child: Row(
              children: [
                Icon(icon, color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.4), size: 24),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    title,
                    style: GoogleFonts.manrope(
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).textTheme.bodyLarge?.color,
                    ),
                  ),
                ),
                Text(
                  value,
                  style: GoogleFonts.manrope(
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(width: 8),
                Icon(Icons.chevron_right_rounded, color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.2), size: 18),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
