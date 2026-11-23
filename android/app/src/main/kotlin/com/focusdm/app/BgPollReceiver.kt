package com.focusdm.app

import android.app.AlarmManager
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.os.Build
import android.util.Log
import androidx.core.app.NotificationCompat
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import org.json.JSONObject
import java.net.HttpURLConnection
import java.net.URL

/**
 * BgPollReceiver — AlarmManager-driven background poller.
 *
 * Fires every ~15 minutes to check the Instagram badge count endpoint.
 * If the unread count has grown since last check, posts a local notification.
 * No Flutter/Dart involvement needed — pure native Android.
 */
class BgPollReceiver : BroadcastReceiver() {

    companion object {
        private const val TAG = "FocusDM_BgPoll"
        private const val ACTION = "com.example.focus_dm.BG_POLL"
        private const val CHANNEL_ID = "focus_dm_messages"
        private const val CHANNEL_NAME = "Direct Messages"
        private const val NOTIF_ID = 99998
        private const val INTERVAL_MS = 15 * 60 * 1000L // 15 minutes

        /** Schedule (or reschedule) the recurring alarm. Safe to call multiple times. */
        fun schedule(context: Context) {
            val am = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
            val pi = buildPendingIntent(context)
            val triggerAt = System.currentTimeMillis() + INTERVAL_MS

            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S && !am.canScheduleExactAlarms()) {
                // Fallback to inexact — still fires, just not precisely
                am.setInexactRepeating(
                    AlarmManager.RTC_WAKEUP,
                    triggerAt,
                    INTERVAL_MS,
                    pi
                )
            } else {
                am.setRepeating(
                    AlarmManager.RTC_WAKEUP,
                    triggerAt,
                    INTERVAL_MS,
                    pi
                )
            }
            Log.d(TAG, "Background poll alarm scheduled (interval=${INTERVAL_MS / 60000}min)")
        }

        /** Cancel the alarm (e.g. user logged out / no session). */
        fun cancel(context: Context) {
            val am = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
            am.cancel(buildPendingIntent(context))
            Log.d(TAG, "Background poll alarm cancelled")
        }

        private fun buildPendingIntent(context: Context): PendingIntent {
            val intent = Intent(context, BgPollReceiver::class.java).apply {
                action = ACTION
            }
            return PendingIntent.getBroadcast(
                context, 0, intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
        }

        private fun ensureNotificationChannel(context: Context) {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                val nm = context.getSystemService(NotificationManager::class.java)
                if (nm.getNotificationChannel(CHANNEL_ID) == null) {
                    val channel = NotificationChannel(
                        CHANNEL_ID, CHANNEL_NAME,
                        NotificationManager.IMPORTANCE_HIGH
                    ).apply {
                        description = "Notifications for new Instagram Direct Messages"
                        enableVibration(true)
                    }
                    nm.createNotificationChannel(channel)
                }
            }
        }
    }

    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != ACTION) return
        Log.d(TAG, "BgPollReceiver fired — checking badge count")

        // Run network call off the main thread
        val result = goAsync()
        CoroutineScope(Dispatchers.IO).launch {
            try {
                poll(context)
            } catch (e: Exception) {
                Log.e(TAG, "Poll error: ${e.message}")
            } finally {
                result.finish()
            }
        }
    }

    private fun poll(context: Context) {
        val prefs: SharedPreferences =
            context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)

        // SharedPreferences keys used by Flutter's shared_preferences package are prefixed with "flutter."
        val cookies = prefs.getString("flutter.ig_session_cookies", null)
        if (cookies.isNullOrBlank()) {
            Log.d(TAG, "No cookies stored — skipping poll")
            return
        }
        val lastBadge = prefs.getInt("flutter.ig_last_badge_count", 0)

        val url = URL("https://i.instagram.com/api/v1/direct_v2/get_badge_count/")
        val conn = url.openConnection() as HttpURLConnection
        conn.apply {
            requestMethod = "GET"
            setRequestProperty("Cookie", cookies)
            setRequestProperty(
                "User-Agent",
                "Mozilla/5.0 (Linux; Android 14; Mobile) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0.0.0 Mobile Safari/537.36"
            )
            setRequestProperty("X-IG-App-ID", "936619743392459")
            connectTimeout = 12_000
            readTimeout = 12_000
        }

        val code = conn.responseCode
        Log.d(TAG, "Badge API response: $code")
        if (code != 200) return

        val body = conn.inputStream.bufferedReader().readText()
        val json = JSONObject(body)
        val count = json.optInt("badge_count", 0)
        Log.d(TAG, "Badge count: $count (last: $lastBadge)")

        if (count > lastBadge && count > 0) {
            prefs.edit().putInt("flutter.ig_last_badge_count", count).apply()
            showNotification(context, count)
        } else if (count == 0) {
            prefs.edit().putInt("flutter.ig_last_badge_count", 0).apply()
        }
    }

    private fun showNotification(context: Context, count: Int) {
        ensureNotificationChannel(context)
        val body = if (count == 1)
            "You have a new message on Instagram"
        else
            "You have $count new messages on Instagram"

        val openIntent = Intent(context, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
        }
        val pi = PendingIntent.getActivity(
            context, 0, openIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val notif = NotificationCompat.Builder(context, CHANNEL_ID)
            .setSmallIcon(R.mipmap.ic_launcher)
            .setContentTitle("New Direct Message")
            .setContentText(body)
            .setStyle(NotificationCompat.BigTextStyle().bigText(body))
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setAutoCancel(true)
            .setContentIntent(pi)
            .build()

        val nm = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        nm.notify(NOTIF_ID, notif)
        Log.d(TAG, "Background notification posted (count=$count)")
    }
}
