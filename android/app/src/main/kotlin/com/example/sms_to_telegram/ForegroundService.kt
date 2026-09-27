package com.example.sms_to_telegram

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.IBinder
import android.util.Log
import androidx.core.app.NotificationCompat

class ForegroundService : Service() {

    companion object {
        const val CHANNEL_ID = "sms_forwarder_channel"
        const val CHANNEL_NAME = "SMS Forwarder Service"
        const val NOTIFICATION_ID = 1001
    }

    override fun onCreate() {
        super.onCreate()
        createNotificationChannel()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        Log.d("ForegroundService", "ForegroundService started")

        val notification = createNotification()
        startForeground(NOTIFICATION_ID, notification)

        return START_STICKY
    }

    private fun createNotification(): Notification {
        val launchIntent = Intent(this, MainActivity::class.java).apply {
            this.flags = Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP
        }

        val pendingIntentFlags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
        } else {
            PendingIntent.FLAG_UPDATE_CURRENT
        }

        val pendingIntent = PendingIntent.getActivity(
            this,
            0,
            launchIntent,
            pendingIntentFlags
        )

        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("InyaTech SMS Forwarder")
            .setContentText("InyaTech SMS Forwarder is active")
            .setSmallIcon(R.mipmap.ic_launcher)
            .setOngoing(true)
            .setContentIntent(pendingIntent)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setCategory(NotificationCompat.CATEGORY_SERVICE)
            .build()
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                CHANNEL_NAME,
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "Keeps SMS listening service active in the background"
                setShowBadge(false)
            }

            val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as? NotificationManager
            notificationManager?.createNotificationChannel(channel)
        }
    }

    override fun onBind(intent: Intent?): IBinder? {
        return null
    }

    override fun onDestroy() {
        Log.d("ForegroundService", "ForegroundService destroyed")
        super.onDestroy()
    }
}
