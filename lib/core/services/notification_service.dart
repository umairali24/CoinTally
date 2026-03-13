import 'dart:developer';
import 'package:flutter/foundation.dart'; // For kIsWeb
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_notification_listener/flutter_notification_listener.dart';
import 'package:cointally/core/utils/transaction_parser.dart';
import 'package:cointally/core/utils/spam_filter.dart';
import 'package:cointally/data/local/db_helper.dart';
import 'package:cointally/domain/entities/transaction_entity.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/services.dart';
import 'package:flutter_app_badger/flutter_app_badger.dart';
import 'dart:io';
import 'dart:isolate';
import 'dart:ui';
import 'dart:math' as math;

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notificationsPlugin = FlutterLocalNotificationsPlugin();
  static const MethodChannel _notifChannel = MethodChannel('com.cointally.app/notifications');

  Future<void> init() async {
    tz.initializeTimeZones();
    
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const DarwinInitializationSettings initializationSettingsIOS = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsIOS,
    );

    await _notificationsPlugin.initialize(initializationSettings);
  }

  /// Request permission to listen to external notifications (Android)
  Future<bool> requestListenerPermission() async {
    if (kIsWeb) return false;

    final bool? isGranted = await NotificationsListener.hasPermission;
    if (isGranted != true) {
      log("Requesting Notification Access Permission...");
      await NotificationsListener.openPermissionSettings();
      return false;
    }
    return true;
  }

  /// Open system notification listener settings
  Future<void> openSettings() async {
    if (kIsWeb) return;
    await NotificationsListener.openPermissionSettings();
  }

  /// Check if listener permission is granted
  Future<bool> isListenerPermissionGranted() async {
    if (kIsWeb) return false;
    return (await NotificationsListener.hasPermission) ?? false;
  }

  /// Initialize the background listener
  Future<void> initListener() async {
    if (kIsWeb) return;

    print("Initializing Notification Listener...");
    try {
      final bool? isGranted = await NotificationsListener.hasPermission;
      print("Notification Listener Permission: $isGranted");
      if (isGranted == true) {
        await NotificationsListener.initialize(callbackHandle: _notificationCallback);
        print("Notification Listener Initialized successfully");
      }
    } catch (e) {
      print("Error initializing Notification Listener: $e");
    }
  }

  Future<void> scheduleNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledDate,
  }) async {
    await _notificationsPlugin.zonedSchedule(
      id,
      title,
      body,
      tz.TZDateTime.from(scheduledDate, tz.local),
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'debt_reminders',
          'Debt Reminders',
          importance: Importance.max,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  Future<void> scheduleMonthlyNotification({
    required int id,
    required String title,
    required String body,
    required int dayOfMonth,
  }) async {
    final now = tz.TZDateTime.now(tz.local);
    // Determine the scheduled date for this month
    // Ensure we don't pick a day > 28 to avoid overflow issues if the current month doesn't have it
    // Or we handle overflow gracefully (tz package handles 'day > month limit' by rolling into next month)
    var scheduledDate = tz.TZDateTime(tz.local, now.year, now.month, dayOfMonth, 10, 0); 
    
    if (scheduledDate.isBefore(now)) {
      scheduledDate = tz.TZDateTime(tz.local, now.year, now.month + 1, dayOfMonth, 10, 0);
    }

    await _notificationsPlugin.zonedSchedule(
      id,
      title,
      body,
      scheduledDate,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'cc_reminders',
          'Credit Card Reminders',
          importance: Importance.max,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.dayOfMonthAndTime,
    );
  }

  Future<void> cancelNotification(int id) async {
    await _notificationsPlugin.cancel(id);
  }

  /// Update the app icon badge count and the Android system notification
  static Future<void> updateBadgeCount() async {
    try {
      final count = await DatabaseHelper.instance.getPendingCount();

      // 1. App Icon Badge
      final bool isSupported = await FlutterAppBadger.isAppBadgeSupported();
      if (isSupported) {
        if (count > 0) {
          FlutterAppBadger.updateBadgeCount(count);
        } else {
          FlutterAppBadger.removeBadge();
        }
      }

      // 2. Android System Notification
      // Use preferences to see if notifications are enabled. 
      // If count is 0, we ALWAYS send the signal so MainActivity can cancel the stuck notification.
      final prefs = await SharedPreferences.getInstance();
      final bool autoNotifEnabled = prefs.getBool('auto_capture_notifications_enabled') ?? true;
      
      if (count == 0 || autoNotifEnabled) {
        await NotificationService().showAutoCaptureNotification(count);
      }

    } catch (e) {
      log("Error updating badge/notification: $e");
    }
  }

  /// Listen for real-time updates from background isolate
  void setupRealTimeListener(VoidCallback onUpdate) {
    if (kIsWeb) return;
    
    // Check if receivePort is established
    final port = NotificationsListener.receivePort;
    port?.listen((message) {
      log("UI Isolate: Received real-time update signal!");
      // Logic to refresh UI
      onUpdate();
    });
  }

  /// Schedule daily reminder via native AlarmManager
  Future<void> scheduleDailyReminder(int hour, int minute) async {
    if (kIsWeb || !Platform.isAndroid) return;
    try {
      await _notifChannel.invokeMethod('scheduleDailyReminder', {'hour': hour, 'minute': minute});
    } catch (e) {
      log("Error scheduling daily reminder: $e");
    }
  }

  /// Cancel daily reminder via native AlarmManager
  Future<void> cancelDailyReminder() async {
    if (kIsWeb || !Platform.isAndroid) return;
    try {
      await _notifChannel.invokeMethod('cancelDailyReminder');
    } catch (e) {
      log("Error canceling daily reminder: $e");
    }
  }

  /// Show or update a grouped notification for auto-captured transactions
  Future<void> showAutoCaptureNotification(int count) async {
    if (kIsWeb || !Platform.isAndroid) return;
    try {
      await _notifChannel.invokeMethod('showAutoCaptureNotification', {'count': count});
    } catch (e) {
      log("Error showing auto-capture notification: $e");
    }
  }
}

/// Static callback function for background isolate execution
@pragma('vm:entry-point')
void _notificationCallback(NotificationEvent evt) async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Stutter Delay: Add a small randomized delay to stagger multiple isolates
  // firing for the same conceptual event (e.g. Bank App + SMS).
  await Future.delayed(Duration(milliseconds: math.Random().nextInt(300)));

  print("!!! _notificationCallback triggered !!!");
  print("Package: ${evt.packageName}");
  print("Title: ${evt.title}");
  print("Text: ${evt.text}");
  
  // 0. Whitelist Filter
  final prefs = await SharedPreferences.getInstance();
  final whitelistedApps = prefs.getStringList('notification_whitelist')?.toSet() ?? {};
  final smsEnabled = prefs.getBool('sms_alerts_enabled') ?? false;
  final defaultSms = prefs.getString('default_sms_package');
  
  bool isAllowed = false;
  if (evt.packageName != null) {
    if (whitelistedApps.contains(evt.packageName)) {
      isAllowed = true;
    } else if (smsEnabled && defaultSms != null && evt.packageName == defaultSms) {
      isAllowed = true;
    }
  }
  
  if (!isAllowed) {
    print("Notification Ignored: ${evt.packageName} is not whitelisted.");
    return;
  }

  // 0.1 Blocked Sender Check (Non-Financial 学習)
  final isBlocked = await DatabaseHelper.instance.isSenderBlocked(evt.title ?? '');
  if (isBlocked) {
    print("Notification Ignored: Sender ${evt.title} is blocked (Non-Financial).");
    return;
  }

  final String? bigText = evt.raw?['bigText'];
  log("Notification Received: Title: ${evt.title}, Body: ${evt.text}, BigText: $bigText, Package: ${evt.packageName}");
  
  if (evt.isGroup == true) {
    log("Notification ignored: Group summary.");
    return;
  }

  DateTime? notificationDate = evt.createAt;
  if (evt.timestamp != null) {
      notificationDate = DateTime.fromMillisecondsSinceEpoch(evt.timestamp!);
  }

  // 1. Primary Parsing (Standard Body or BigText)
  final String contentToParse = (evt.text != null && evt.text!.length > 5) ? evt.text! : (bigText ?? evt.text ?? '');
  var transaction = TransactionParser.parse(evt.title, contentToParse, notificationDate: notificationDate);
  
  // 2. Secondary Parsing (Bundled/Grouped Messages)
  // WhatsApp often bundles messages. We check 'textLines' in the raw data.
  final List<dynamic>? textLines = evt.raw?['textLines'] as List<dynamic>?;
  
  Future<void> processTransaction(TransactionEntity tx, String? originalText) async {
    log("Processing Transaction: ${tx.amount} - ${tx.type}");
    final String cleanBody = originalText ?? '';

    // Spam Check
    if (SpamFilter.isSpam(originalText ?? '')) {
      log("Ignored Spam: $originalText");
      return;
    }
    
    try {
      // 0. Check Learned Rules first (The "Brain")
      final learnedRule = await DatabaseHelper.instance.findLearnedRule(evt.packageName ?? '', cleanBody);
      
      int? targetAccountId;
      String? matchedMerchant = tx.merchantName;

      if (learnedRule != null) {
        log("Learning Engine: Found matching rule! Target Account: ${learnedRule['target_account_id']}");
        targetAccountId = learnedRule['target_account_id'];
        matchedMerchant = learnedRule['target_merchant_name'];
      } 
      
      // If we still don't have a target account (e.g., from a global keyword rule), try to auto-detect
      if (targetAccountId == null) {
        // 1. Identify Bank from Package Name
        var bankName = await DatabaseHelper.instance.getBankNameByPackage(evt.packageName ?? '');
        
        // 2. Identify Bank from title
        if (bankName == null) {
          bankName = await DatabaseHelper.instance.getBankNameBySender(evt.title ?? '');
        }
        
        // 3. Identify Bank from text keywords (Powered by Centralized Alias Engine)
        if (bankName == null) {
          bankName = await DatabaseHelper.instance.getBankNameByKeywords(cleanBody);
        }

        if (bankName != null) {
          targetAccountId = await DatabaseHelper.instance.getAccountIdByBankName(bankName, rawText: cleanBody);
        }
      }

      final int? defaultAccount = await DatabaseHelper.instance.getDefaultAccountId();
      final finalAccountId = targetAccountId ?? defaultAccount ?? 1; // Fallback to 1 if absolutely nothing found

      final pendingTx = {
        'amount': tx.amount,
        'type': tx.type,
        'date': tx.date.millisecondsSinceEpoch,
        'merchant_name': matchedMerchant,
        'raw_title': evt.title,
        'raw_body': cleanBody,
        'package_name': evt.packageName,
        'suggested_account_id': finalAccountId,
        'is_reconciled': 0,
        'notification_key': evt.key, // Pass the unique Android notification key
      };

      final result = await DatabaseHelper.instance.insertPendingUnique(pendingTx);
      if (result == -1) {
        log("Atomic Guard: Successfully blocked duplicate capture of ${tx.amount}");
        return;
      }
      
      log("Saved to Pending Queue: ${tx.amount} (Suggested Account: $finalAccountId)");
      
      // Update badge count in background (which now also updates system notification)
      await NotificationService.updateBadgeCount();
      
      // Signal the UI isolate
      final SendPort? sendPort = IsolateNameServer.lookupPortByName(NotificationsListener.SEND_PORT_NAME);
      sendPort?.send("refresh");
      
    } catch (e) {
      log("Error processing pending transaction: $e");
    }
  }

  // Handle the transactions
  if (transaction != null) {
    await processTransaction(transaction, evt.text);
  } else if (textLines != null && textLines.isNotEmpty) {
    log("Checking bundled messages (${textLines.length} lines)...");
    for (final line in textLines) {
      final lineText = line.toString();
      final lineTx = TransactionParser.parse(evt.title, lineText, notificationDate: notificationDate);
      if (lineTx != null) {
        log("Found transaction in bundled line: $lineText");
        await processTransaction(lineTx, lineText);
      }
    }
  }
}
