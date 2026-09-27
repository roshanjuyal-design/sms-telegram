package com.example.sms_to_telegram

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Handler
import android.os.Looper
import android.os.PowerManager
import android.provider.Telephony
import android.util.Log

class SmsReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action == Telephony.Sms.Intents.SMS_RECEIVED_ACTION) {
            val powerManager = context.getSystemService(Context.POWER_SERVICE) as? PowerManager
            val wakeLock = powerManager?.newWakeLock(
                PowerManager.PARTIAL_WAKE_LOCK,
                "sms_to_telegram:sms_wake_lock"
            )
            wakeLock?.acquire(15 * 1000L) // Hold wake lock for up to 15 seconds

            val messages = Telephony.Sms.Intents.getMessagesFromIntent(intent)
            if (messages.isNullOrEmpty()) {
                if (wakeLock?.isHeld == true) wakeLock.release()
                return
            }

            val sender = messages[0].displayOriginatingAddress ?: "Unknown"
            val bodyBuilder = StringBuilder()
            for (sms in messages) {
                bodyBuilder.append(sms.displayMessageBody)
            }
            val body = bodyBuilder.toString()

            Log.d("SmsReceiver", "SMS received from $sender: $body")

            val smsData = mapOf(
                "sender" to sender,
                "body" to body
            )

            // Dispatch to Flutter MethodChannel on the main thread
            Handler(Looper.getMainLooper()).post {
                try {
                    MainActivity.methodChannel?.invokeMethod("onSmsReceived", smsData)
                } catch (e: Exception) {
                    Log.e("SmsReceiver", "Error dispatching SMS to Flutter: ${e.message}")
                } finally {
                    if (wakeLock?.isHeld == true) {
                        try {
                            wakeLock.release()
                        } catch (_: Exception) {}
                    }
                }
            }
        }
    }
}
