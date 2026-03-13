package com.cointally.app

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.database.sqlite.SQLiteDatabase
import androidx.core.app.NotificationCompat
import java.util.*

class DailyReminderReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (!shouldShowNotification(context)) return

        val notificationManager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        val channelId = "daily_reminders"
        
        if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.O) {
            val channel = NotificationChannel(channelId, "Daily Reminders", NotificationManager.IMPORTANCE_DEFAULT)
            notificationManager.createNotificationChannel(channel)
        }

        val launchIntent = context.packageManager.getLaunchIntentForPackage(context.packageName)
        val pendingIntent = PendingIntent.getActivity(context, 0, launchIntent, PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT)

        val notification = NotificationCompat.Builder(context, channelId)
            .setSmallIcon(context.resources.getIdentifier("ic_launcher", "mipmap", context.packageName))
            .setContentTitle("Forget something?")
            .setContentText("You haven't logged any transactions today. Keep your hisaab up to date!")
            .setAutoCancel(true)
            .setContentIntent(pendingIntent)
            .setPriority(NotificationCompat.PRIORITY_DEFAULT)
            .build()

        notificationManager.notify(1001, notification)
    }

    private fun shouldShowNotification(context: Context): Boolean {
        var db: SQLiteDatabase? = null
        try {
            val dbPath = context.getDatabasePath("hisaabmate.db").path
            db = SQLiteDatabase.openDatabase(dbPath, null, SQLiteDatabase.OPEN_READONLY)
            
            val calendar = Calendar.getInstance()
            calendar.set(Calendar.HOUR_OF_DAY, 0)
            calendar.set(Calendar.MINUTE, 0)
            calendar.set(Calendar.SECOND, 0)
            calendar.set(Calendar.MILLISECOND, 0)
            val startOfToday = calendar.timeInMillis

            val cursor = db.rawQuery("SELECT COUNT(*) FROM transactions WHERE date >= ?", arrayOf(startOfToday.toString()))
            if (cursor.moveToFirst()) {
                val count = cursor.getInt(0)
                cursor.close()
                return count == 0
            }
            cursor.close()
        } catch (e: Exception) {
            e.printStackTrace()
        } finally {
            db?.close()
        }
        return true // Fallback to showing if database check fails
    }
}
