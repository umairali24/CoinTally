package com.cointally.app

import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.provider.Telephony
import android.app.AlarmManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.app.NotificationChannel
import android.app.NotificationManager
import android.os.Build
import androidx.core.app.NotificationCompat
import java.util.*

class MainActivity : FlutterFragmentActivity() {
    private val CHANNEL_SMS = "com.cointally.app/sms_package"
    private val CHANNEL_NOTIF = "com.cointally.app/notifications"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        // SMS Package Channel
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL_SMS).setMethodCallHandler { call, result ->
            if (call.method == "getDefaultSmsPackage") {
                val packageName = Telephony.Sms.getDefaultSmsPackage(this)
                result.success(packageName)
            } else {
                result.notImplemented()
            }
        }

        // Notifications & Alarms Channel
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL_NOTIF).setMethodCallHandler { call, result ->
            when (call.method) {
                "scheduleDailyReminder" -> {
                    val hour = call.argument<Int>("hour") ?: 20
                    val minute = call.argument<Int>("minute") ?: 0
                    scheduleAlarm(hour, minute)
                    result.success(true)
                }
                "cancelDailyReminder" -> {
                    cancelAlarm()
                    result.success(true)
                }
                "showAutoCaptureNotification" -> {
                    val count = call.argument<Int>("count") ?: 1
                    showGroupedNotification(count)
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun scheduleAlarm(hour: Int, minute: Int) {
        val alarmManager = getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val intent = Intent(this, DailyReminderReceiver::class.java)
        val pendingIntent = PendingIntent.getBroadcast(this, 1001, intent, PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT)

        val calendar = Calendar.getInstance().apply {
            timeInMillis = System.currentTimeMillis()
            set(Calendar.HOUR_OF_DAY, hour)
            set(Calendar.MINUTE, minute)
            set(Calendar.SECOND, 0)
            if (before(Calendar.getInstance())) {
                add(Calendar.DATE, 1)
            }
        }

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            alarmManager.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, calendar.timeInMillis, pendingIntent)
        } else {
            alarmManager.setExact(AlarmManager.RTC_WAKEUP, calendar.timeInMillis, pendingIntent)
        }
    }

    private fun cancelAlarm() {
        val alarmManager = getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val intent = Intent(this, DailyReminderReceiver::class.java)
        val pendingIntent = PendingIntent.getBroadcast(this, 1001, intent, PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_NO_CREATE)
        if (pendingIntent != null) {
            alarmManager.cancel(pendingIntent)
            pendingIntent.cancel()
        }
    }

    private fun showGroupedNotification(count: Int) {
        val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        
        if (count <= 0) {
            notificationManager.cancel(2002)
            return
        }

        val channelId = "auto_capture_channel"
        val groupId = "CAPTURED_TRX"

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(channelId, "Transaction Auto-Capture", NotificationManager.IMPORTANCE_LOW)
            notificationManager.createNotificationChannel(channel)
        }

        val launchIntent = packageManager.getLaunchIntentForPackage(packageName)
        val pendingIntent = PendingIntent.getActivity(this, 0, launchIntent, PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT)

        val contentText = if (count == 1) "1 transaction captured and waiting for review" else "$count transactions waiting for review"

        val notification = NotificationCompat.Builder(this, channelId)
            .setSmallIcon(resources.getIdentifier("ic_launcher", "mipmap", packageName))
            .setContentTitle("Transactions Captured")
            .setContentText(contentText)
            .setGroup(groupId)
            .setOnlyAlertOnce(true)
            .setAutoCancel(true)
            .setContentIntent(pendingIntent)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .build()

        notificationManager.notify(2002, notification)
    }
}
