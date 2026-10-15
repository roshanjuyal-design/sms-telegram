package com.example.sms_to_telegram

import android.content.Context
import android.speech.tts.TextToSpeech
import android.util.Log
import org.json.JSONArray
import org.json.JSONObject
import java.io.BufferedReader
import java.io.InputStreamReader
import java.net.HttpURLConnection
import java.net.URL
import java.net.URLEncoder
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import java.util.regex.Pattern

/**
 * Native background SMS processor that guarantees SMS forwarding,
 * Duplicate UTR fraud checking, Soundbox voice announcements, and transaction logging
 * even when MainActivity or FlutterEngine is destroyed, paused, or killed by Android OS.
 */
object NativeSmsProcessor {
    private const val TAG = "NativeSmsProcessor"
    private const val PREFS_NAME = "FlutterSharedPreferences"

    // Default Fallbacks
    private const val DEFAULT_BOT_TOKEN = "8814275955:AAF6QXMd26V3f8_-S8x08xV6dkFlAuVKsNQ"
    private val DEFAULT_CHAT_IDS = listOf("616463263", "8976081182")

    private var tts: TextToSpeech? = null
    private var isTtsInitialized = false

    /**
     * Filters SMS messages to ensure only valid UBI credit SMS are forwarded.
     */
    fun shouldForwardSms(body: String, sender: String): Boolean {
        val lowerBody = body.lowercase(Locale.ROOT)
        val lowerSender = sender.lowercase(Locale.ROOT)

        // 1. Blacklist
        val blacklist = listOf(
            "otp", "one time password", "verification code", "secret code",
            "debited", "debit", "withdrawn", "spent", "paid to",
            "sent to", "transfer to", "declined", "failed", "pre-approved", "apply now"
        )
        for (keyword in blacklist) {
            if (lowerBody.contains(keyword)) {
                return false
            }
        }

        // 2. Bank Check: Union Bank of India (UBI)
        val isUbiSender = lowerSender.contains("ubin") ||
                lowerSender.contains("unionb") ||
                lowerSender.contains("ubi")
        val isUbiBody = lowerBody.contains("union bank") ||
                lowerBody.contains("union bank of india") ||
                lowerBody.contains("ubin") ||
                lowerBody.contains("ubi")

        if (!isUbiSender && !isUbiBody) {
            return false
        }

        // 3. Credit Check
        val creditKeywords = listOf("credit", "credited", "received", "deposited")
        var hasCredit = false
        for (keyword in creditKeywords) {
            if (lowerBody.contains(keyword)) {
                hasCredit = true
                break
            }
        }
        if (!hasCredit) return false

        // 4. Amount Check
        val amountPattern = Pattern.compile("(?:rs\\.?|inr|₹)\\s*[\\d,]+", Pattern.CASE_INSENSITIVE)
        return amountPattern.matcher(body).find()
    }

    /**
     * Process an incoming SMS directly in native Kotlin.
     */
    fun process(context: Context, sender: String, body: String) {
        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)

        if (!shouldForwardSms(body, sender)) {
            Log.d(TAG, "Filtered non-credit/non-UBI SMS from $sender: $body")
            saveLogEntry(
                prefs = prefs,
                sender = sender,
                rawBody = body,
                amount = 0.0,
                formattedAmount = "0",
                txnId = "",
                status = "filtered",
                statusReason = "Native Filtered: Non-credit / OTP / Non-UBI message"
            )
            return
        }

        // Extract metadata
        val amountPattern = Pattern.compile("(?:Rs\\.?|INR|₹)\\s*([\\d,]+(?:\\.\\d+)?)", Pattern.CASE_INSENSITIVE)
        val senderPattern = Pattern.compile("(?:received from|from)\\s+([^\\s,:]+)", Pattern.CASE_INSENSITIVE)
        val txnPattern = Pattern.compile("(?:transaction\\s*ID|Txn\\s*ID|Ref(?:\\s*No)?|UPI\\s*Ref)[:\\s]+([a-zA-Z0-9]+)", Pattern.CASE_INSENSITIVE)

        val amountMatcher = amountPattern.matcher(body)
        val senderMatcher = senderPattern.matcher(body)
        val txnMatcher = txnPattern.matcher(body)

        val formattedAmount = if (amountMatcher.find()) amountMatcher.group(1) ?: "0" else "0"
        val cleanAmountStr = formattedAmount.replace(",", "")
        val amountVal = cleanAmountStr.toDoubleOrNull() ?: 0.0
        val extractedSender = if (senderMatcher.find()) senderMatcher.group(1) ?: sender else sender
        val txnId = if (txnMatcher.find()) txnMatcher.group(1) ?: "" else ""

        // Load Bot Token & Chat IDs
        val botToken = prefs.getString("flutter.telegram_bot_token", null)?.trim()
            ?.ifEmpty { DEFAULT_BOT_TOKEN } ?: DEFAULT_BOT_TOKEN
        val chatIds = getActiveChatIds(prefs)

        // 1. Check for Duplicate UTR / Fraud Alert
        if (txnId.isNotEmpty() && isDuplicateTxn(prefs, txnId)) {
            Log.w(TAG, "Duplicate UTR detected: $txnId (Claimed: ₹$formattedAmount from $extractedSender)")
            val alertMessage = buildString {
                append("🚨 *FRAUD / DUPLICATE UTR ALERT!* 🚨\n\n")
                append("⚠️ *Duplicate Transaction Detected!*\n")
                append("🆔 *UTR / Txn ID:* `$txnId`\n")
                append("💵 *Amount Claimed:* ₹$formattedAmount\n")
                append("👤 *Sender:* $extractedSender\n\n")
                append("⛔ *CAUTION:* Do NOT hand over goods/cash without checking bank statement!\n\n")
                append("📩 *Raw SMS:* $body\n\n")
                append("⏰ *Time:* _${getCurrentTimestampString()}_")
            }

            // Announce voice duplicate alert
            speakVoiceAnnouncement(context, "హెచ్చరిక! ఈ లావాదేవీ నెంబర్ ఇంతకుముందే జమ అయ్యింది!", "Warning! Duplicate transaction detected!")

            // Dispatch Fraud Alert to Telegram
            for (chatId in chatIds) {
                sendTelegramMessage(botToken, chatId, alertMessage)
            }

            // Save Duplicate Log
            saveLogEntry(
                prefs = prefs,
                sender = extractedSender,
                rawBody = body,
                amount = amountVal,
                formattedAmount = formattedAmount,
                txnId = txnId,
                status = "duplicate",
                statusReason = "Native Alert: Duplicate UTR $txnId detected!"
            )
            return
        }

        // 2. Normal Valid Payment
        val telegramMessage = buildString {
            append("💰 *UBI Payment Credited!*\n\n")
            if (formattedAmount != "0") {
                append("💵 *Amount:* ₹$formattedAmount\n")
            }
            if (extractedSender.isNotEmpty()) {
                append("👤 *From:* $extractedSender\n")
            }
            if (txnId.isNotEmpty()) {
                append("🆔 *Txn ID:* `$txnId`\n")
            }
            append("\n📩 *Details:* $body\n")
            append("\n⏰ *Time:* _${getCurrentTimestampString()}_\n")
            append("⚡ _(Delivered via InyaTech Background Engine)_")
        }

        var anySuccess = false
        val failedChatIds = mutableListOf<String>()

        for (chatId in chatIds) {
            val sent = sendTelegramMessage(botToken, chatId, telegramMessage)
            if (sent) {
                anySuccess = true
            } else {
                failedChatIds.add(chatId)
            }
        }

        // Speak Voice Soundbox
        if (formattedAmount != "0") {
            speakVoiceAnnouncement(
                context,
                "యూనియన్ బ్యాంక్ ఆఫ్ ఇండియా. $formattedAmount రూపాయలు జమ అయ్యింది.",
                "Payment of rupees $formattedAmount received in Union Bank."
            )
        }

        // If offline / failed, queue for retry
        if (!anySuccess && chatIds.isNotEmpty()) {
            enqueueOfflineMessage(
                prefs = prefs,
                rawSms = body,
                formattedMessage = telegramMessage,
                sender = extractedSender,
                amount = formattedAmount,
                txnId = txnId,
                targetChatIds = chatIds
            )
        }

        // Save Transaction Log
        saveLogEntry(
            prefs = prefs,
            sender = extractedSender,
            rawBody = body,
            amount = amountVal,
            formattedAmount = formattedAmount,
            txnId = txnId,
            status = if (anySuccess) "forwarded" else "failed",
            statusReason = if (anySuccess) "Native Forwarded to Telegram & Voice announced" else "Saved to Offline Queue (No Network)"
        )
    }

    private fun isDuplicateTxn(prefs: android.content.SharedPreferences, txnId: String): Boolean {
        try {
            val jsonStr = prefs.getString("flutter.transaction_history_logs", null) ?: return false
            val array = JSONArray(jsonStr)
            for (i in 0 until array.length()) {
                val item = array.getJSONObject(i)
                val storedTxnId = item.optString("txnId", "")
                if (storedTxnId.equals(txnId, ignoreCase = true)) {
                    return true
                }
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error checking duplicate UTR: ${e.message}")
        }
        return false
    }

    private fun getActiveChatIds(prefs: android.content.SharedPreferences): List<String> {
        try {
            val recipientsJson = prefs.getString("flutter.telegram_recipients", null)
            if (!recipientsJson.isNullOrEmpty()) {
                val array = JSONArray(recipientsJson)
                val activeList = mutableListOf<String>()
                for (i in 0 until array.length()) {
                    val obj = array.getJSONObject(i)
                    val isEnabled = obj.optBoolean("isEnabled", true)
                    val chatId = obj.optString("chatId", "").trim()
                    if (isEnabled && chatId.isNotEmpty()) {
                        activeList.add(chatId)
                    }
                }
                if (activeList.isNotEmpty()) {
                    return activeList
                }
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error reading active chat IDs: ${e.message}")
        }
        return DEFAULT_CHAT_IDS
    }

    private fun sendTelegramMessage(botToken: String, chatId: String, message: String): Boolean {
        var conn: HttpURLConnection? = null
        return try {
            val encodedMsg = URLEncoder.encode(message, "UTF-8")
            val urlStr = "https://api.telegram.org/bot${botToken.trim()}/sendMessage?chat_id=${chatId.trim()}&parse_mode=Markdown&text=$encodedMsg"
            val url = URL(urlStr)
            conn = url.openConnection() as HttpURLConnection
            conn.requestMethod = "GET"
            conn.connectTimeout = 12000
            conn.readTimeout = 12000
            val responseCode = conn.responseCode
            Log.d(TAG, "Telegram dispatch to $chatId response code: $responseCode")
            responseCode in 200..299
        } catch (e: Exception) {
            Log.e(TAG, "Telegram dispatch failed for $chatId: ${e.message}")
            false
        } finally {
            conn?.disconnect()
        }
    }

    private fun saveLogEntry(
        prefs: android.content.SharedPreferences,
        sender: String,
        rawBody: String,
        amount: Double,
        formattedAmount: String,
        txnId: String,
        status: String,
        statusReason: String
    ) {
        try {
            val existingJson = prefs.getString("flutter.transaction_history_logs", "[]") ?: "[]"
            val array = try { JSONArray(existingJson) } catch (_: Exception) { JSONArray() }

            val newLog = JSONObject().apply {
                put("id", System.currentTimeMillis().toString())
                put("sender", sender)
                put("rawBody", rawBody)
                put("amount", amount)
                put("formattedAmount", formattedAmount)
                put("txnId", txnId)
                put("bank", "Union Bank of India")
                put("status", status)
                put("statusReason", statusReason)
                put("timestamp", SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss.SSS", Locale.US).format(Date()))
                put("isCredit", status != "filtered")
            }

            // Prepend newLog
            val updatedArray = JSONArray()
            updatedArray.put(newLog)
            for (i in 0 until minOf(array.length(), 499)) {
                updatedArray.put(array.get(i))
            }

            prefs.edit().putString("flutter.transaction_history_logs", updatedArray.toString()).apply()
            Log.d(TAG, "Saved transaction log natively: $status (₹$formattedAmount)")
        } catch (e: Exception) {
            Log.e(TAG, "Failed to save native transaction log: ${e.message}")
        }
    }

    private fun enqueueOfflineMessage(
        prefs: android.content.SharedPreferences,
        rawSms: String,
        formattedMessage: String,
        sender: String,
        amount: String,
        txnId: String,
        targetChatIds: List<String>
    ) {
        try {
            val existingQueueJson = prefs.getString("flutter.offline_sms_queue", "[]") ?: "[]"
            val array = try { JSONArray(existingQueueJson) } catch (_: Exception) { JSONArray() }

            val targetArray = JSONArray()
            for (id in targetChatIds) targetArray.put(id)

            val queuedItem = JSONObject().apply {
                put("id", System.currentTimeMillis().toString())
                put("rawSms", rawSms)
                put("formattedTelegramMessage", formattedMessage)
                put("sender", sender)
                put("amount", amount)
                put("txnId", txnId)
                put("targetChatIds", targetArray)
                put("deliveredChatIds", JSONArray())
                put("retryCount", 0)
                put("createdAt", SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss.SSS", Locale.US).format(Date()))
                put("lastError", "Offline / Network dispatch failure")
            }

            array.put(queuedItem)
            prefs.edit().putString("flutter.offline_sms_queue", array.toString()).apply()
            Log.d(TAG, "Enqueued message for offline retry natively: ₹$amount")
        } catch (e: Exception) {
            Log.e(TAG, "Failed to enqueue offline message natively: ${e.message}")
        }
    }

    private fun speakVoiceAnnouncement(context: Context, teluguText: String, englishFallbackText: String) {
        try {
            tts = TextToSpeech(context.applicationContext) { status ->
                if (status == TextToSpeech.SUCCESS) {
                    val result = tts?.setLanguage(Locale("te", "IN"))
                    val textToSpeak = if (result == TextToSpeech.LANG_MISSING_DATA || result == TextToSpeech.LANG_NOT_SUPPORTED) {
                        tts?.setLanguage(Locale.US)
                        englishFallbackText
                    } else {
                        teluguText
                    }
                    tts?.speak(textToSpeak, TextToSpeech.QUEUE_FLUSH, null, "NativeSmsTtsId")
                }
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error triggering native TextToSpeech: ${e.message}")
        }
    }

    private fun getCurrentTimestampString(): String {
        return SimpleDateFormat("yyyy-MM-dd HH:mm:ss", Locale.getDefault()).format(Date())
    }
}
