import 'package:firebase_analytics/firebase_analytics.dart';
import 'dart:developer';

class TelemetryService {
  static final TelemetryService _instance = TelemetryService._internal();
  factory TelemetryService() => _instance;
  TelemetryService._internal();

  final FirebaseAnalytics _analytics = FirebaseAnalytics.instance;

  /// Prints the app instance ID for identification in Firebase DebugView.
  Future<void> debugInstanceId() async {
    try {
      final id = await _analytics.appInstanceId;
      print("TelemetryService: [FIREBASE_ID] Current App Instance ID: $id");
      print("TelemetryService: If DebugView shows devices, look for this ID: $id");
    } catch (e) {
      print("TelemetryService: Could not fetch App Instance ID: $e");
    }
  }

  /// Logs a 'rule_learned' event to Firebase Analytics.
  /// 
  /// CRITICAL PRIVACY GUARDRAIL: Only the SMS shortcode (or app package name) and mapped bank name are logged.
  /// This method must NEVER accept or log personal data like amounts or full messages.
  Future<void> logRuleLearned({String? shortcode, String? packageName, required String bankName}) async {
    try {
      // Use both log() for developer console and print() for terminal visibility
      final msg = "TelemetryService: Logging learned rule - Shortcode: $shortcode, Package: $packageName, Bank: $bankName";
      log(msg);
      print("Sending Firebase Event [rule_learned]: $msg");
      
      final Map<String, Object> params = {
        'bank_name': bankName,
      };
      
      if (shortcode != null && shortcode.isNotEmpty) {
        params['shortcode'] = shortcode;
      }
      if (packageName != null && packageName.isNotEmpty) {
        // MATCHING USER'S CUSTOM DEFINITION: packageName (camelCase)
        params['packageName'] = packageName;
      }

      // Explicitly ensure collection is on
      await _analytics.setAnalyticsCollectionEnabled(true);

      await _analytics.logEvent(
        name: 'rule_learned',
        parameters: params,
      );
      print("TelemetryService: SUCCESSFULLY sent event to Firebase SDK.");
    } catch (e) {
      log("TelemetryService: Error logging event: $e");
      print("TelemetryService: FAILED to log event: $e");
    }
  }
}
