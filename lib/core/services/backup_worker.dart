import 'package:workmanager/workmanager.dart';
import 'package:cointally/core/services/drive_service.dart';
import 'package:cointally/core/services/cloud_auth_service.dart';
import 'package:cointally/core/services/currency_sync_service.dart';
import 'dart:developer';

@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    log("BackupWorker: Starting task $task");
    
    if (task == BackupWorkerManager.CURRENCY_SYNC_TASK) {
      final success = await CurrencySyncService().syncRates();
      return Future.value(success);
    }

    try {
      // 1. Check if user is signed in
      final isSignedIn = await CloudAuthService().isSignedIn();
      if (!isSignedIn) {
        log("BackupWorker: User not signed in. Skipping backup.");
        return Future.value(true);
      }

      // 2. Perform upload
      final success = await DriveService().uploadBackup();
      log("BackupWorker: Backup ${success ? 'successful' : 'failed'}");
      
      return Future.value(success);
    } catch (e) {
      log("BackupWorker: Error during backup: $e");
      return Future.value(false);
    }
  });
}

class BackupWorkerManager {
  static const String BACKUP_TASK_NAME = "com.cointally.app.backup_task";
  static const String CURRENCY_SYNC_TASK = "com.cointally.app.currency_sync_task";

  static Future<void> initialize() async {
    await Workmanager().initialize(
      callbackDispatcher,
      isInDebugMode: false,
    );
    // Schedule currency sync on init
    await scheduleDailyCurrencySync();
  }

  static Future<void> scheduleDailyBackup() async {
    await Workmanager().registerPeriodicTask(
      "periodic-backup-task",
      BACKUP_TASK_NAME,
      frequency: const Duration(hours: 24),
      constraints: Constraints(
        networkType: NetworkType.unmetered, // Wi-Fi
        requiresCharging: true,
      ),
      existingWorkPolicy: ExistingPeriodicWorkPolicy.keep,
    );
  }

  static Future<void> scheduleDailyCurrencySync() async {
    await Workmanager().registerPeriodicTask(
      "periodic-currency-sync",
      CURRENCY_SYNC_TASK,
      frequency: const Duration(hours: 24),
      constraints: Constraints(
        networkType: NetworkType.connected, // Any network
      ),
      existingWorkPolicy: ExistingPeriodicWorkPolicy.replace, // Ensure fresh scheduling
    );
  }
}
