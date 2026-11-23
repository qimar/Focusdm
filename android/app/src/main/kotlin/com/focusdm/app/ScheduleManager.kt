package com.focusdm.app

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import android.util.Log
import org.json.JSONArray
import org.json.JSONObject
import java.util.Calendar

class ScheduleManager(private val context: Context) {

    companion object {
        private const val TAG = "FocusDM_ScheduleMgr"
        private const val ACTION_SCHEDULE_TRIGGER = "com.example.focus_dm.SCHEDULE_TRIGGER"
        private const val REQUEST_CODE_SCHEDULE = 77701
    }

    private val prefs = context.getSharedPreferences("FocusDMPrefs", Context.MODE_PRIVATE)

    fun saveSchedules(jsonString: String) {
        prefs.edit().putString("saved_schedules_json", jsonString).apply()
        checkCurrentSchedulesAndUpdateLock()
        scheduleNextAlarms()
    }

    fun getSchedules(): JSONArray {
        val jsonString = prefs.getString("saved_schedules_json", "[]") ?: "[]"
        return try {
            JSONArray(jsonString)
        } catch (e: Exception) {
            JSONArray()
        }
    }

    /**
     * Checks if right now matches any active schedule window.
     * If yes, ensures focus mode is active until the schedule's end time.
     * If no schedule is active, and focus mode was started by a schedule, releases it.
     */
    fun checkCurrentSchedulesAndUpdateLock() {
        val schedules = getSchedules()
        val now = Calendar.getInstance()
        // Calendar.DAY_OF_WEEK: Sunday=1, Monday=2, ..., Saturday=7
        // In our Dart model: Mon=1, Tue=2, Wed=3, Thu=4, Fri=5, Sat=6, Sun=7
        val currentDartDay = when (now.get(Calendar.DAY_OF_WEEK)) {
            Calendar.MONDAY -> 1
            Calendar.TUESDAY -> 2
            Calendar.WEDNESDAY -> 3
            Calendar.THURSDAY -> 4
            Calendar.FRIDAY -> 5
            Calendar.SATURDAY -> 6
            Calendar.SUNDAY -> 7
            else -> 1
        }
        val currentMinutes = now.get(Calendar.HOUR_OF_DAY) * 60 + now.get(Calendar.MINUTE)

        var matchingEndTimeMillis: Long? = null

        for (i in 0 until schedules.length()) {
            val s = schedules.optJSONObject(i) ?: continue
            val isEnabled = s.optBoolean("isEnabled", true)
            if (!isEnabled) continue

            val daysArray = s.optJSONArray("days") ?: JSONArray()
            var dayMatches = false
            for (d in 0 until daysArray.length()) {
                if (daysArray.optInt(d) == currentDartDay) {
                    dayMatches = true
                    break
                }
            }
            if (!dayMatches) continue

            val sH = s.optInt("startHour", 0)
            val sM = s.optInt("startMinute", 0)
            val eH = s.optInt("endHour", 0)
            val eM = s.optInt("endMinute", 0)

            val startMin = sH * 60 + sM
            val endMin = eH * 60 + eM

            val isActiveNow = if (startMin < endMin) {
                // Same-day window (e.g., 9:00 -> 17:00)
                currentMinutes in startMin until endMin
            } else if (startMin > endMin) {
                // Overnight window (e.g., 22:00 -> 07:00)
                currentMinutes >= startMin || currentMinutes < endMin
            } else {
                false
            }

            if (isActiveNow) {
                val endCal = Calendar.getInstance().apply {
                    set(Calendar.HOUR_OF_DAY, eH)
                    set(Calendar.MINUTE, eM)
                    set(Calendar.SECOND, 0)
                    set(Calendar.MILLISECOND, 0)
                }
                if (startMin > endMin && currentMinutes >= startMin) {
                    // Ends tomorrow morning
                    endCal.add(Calendar.DAY_OF_YEAR, 1)
                }
                matchingEndTimeMillis = endCal.timeInMillis
                break
            }
        }

        if (matchingEndTimeMillis != null) {
            Log.d(TAG, "Current time matches active schedule! Locking until $matchingEndTimeMillis")
            prefs.edit()
                .putBoolean("is_focus_active", true)
                .putLong("focus_end_time", matchingEndTimeMillis)
                .putBoolean("is_scheduled_session", true)
                .apply()
            // Also write to FlutterSharedPreferences so Flutter UI reflects active lock immediately
            context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE).edit()
                .putBoolean("flutter.is_focus_active", true)
                .putLong("flutter.focus_end_time", matchingEndTimeMillis)
                .apply()
        } else {
            // Check if existing session was a scheduled session that has ended
            val isScheduled = prefs.getBoolean("is_scheduled_session", false)
            if (isScheduled) {
                Log.d(TAG, "Scheduled session window has passed. Releasing focus mode.")
                prefs.edit()
                    .putBoolean("is_focus_active", false)
                    .putLong("focus_end_time", 0L)
                    .putBoolean("is_scheduled_session", false)
                    .apply()
                context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE).edit()
                    .putBoolean("flutter.is_focus_active", false)
                    .putLong("flutter.focus_end_time", 0L)
                    .apply()
            }
        }
    }

    /**
     * Finds the next earliest transition point (start or end of any schedule)
     * and sets an exact AlarmManager alarm.
     */
    fun scheduleNextAlarms() {
        val am = context.getSystemService(Context.ALARM_SERVICE) as? AlarmManager ?: return
        val schedules = getSchedules()

        val intent = Intent(context, ScheduleAlarmReceiver::class.java).apply {
            action = ACTION_SCHEDULE_TRIGGER
        }
        val pi = PendingIntent.getBroadcast(
            context,
            REQUEST_CODE_SCHEDULE,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        if (schedules.length() == 0) {
            am.cancel(pi)
            Log.d(TAG, "No schedules to set alarms for. Alarm cancelled.")
            return
        }

        val nowMillis = System.currentTimeMillis()
        var earliestNextMillis: Long = Long.MAX_VALUE

        // Check next 7 days for every start and end time point
        for (i in 0 until schedules.length()) {
            val s = schedules.optJSONObject(i) ?: continue
            val isEnabled = s.optBoolean("isEnabled", true)
            if (!isEnabled) continue

            val daysArray = s.optJSONArray("days") ?: JSONArray()
            val daySet = mutableSetOf<Int>()
            for (d in 0 until daysArray.length()) {
                daySet.add(daysArray.optInt(d))
            }
            if (daySet.isEmpty()) continue

            val sH = s.optInt("startHour", 0)
            val sM = s.optInt("startMinute", 0)
            val eH = s.optInt("endHour", 0)
            val eM = s.optInt("endMinute", 0)

            for (dayOffset in 0..7) {
                val checkCal = Calendar.getInstance().apply {
                    add(Calendar.DAY_OF_YEAR, dayOffset)
                }
                val dartDay = when (checkCal.get(Calendar.DAY_OF_WEEK)) {
                    Calendar.MONDAY -> 1
                    Calendar.TUESDAY -> 2
                    Calendar.WEDNESDAY -> 3
                    Calendar.THURSDAY -> 4
                    Calendar.FRIDAY -> 5
                    Calendar.SATURDAY -> 6
                    Calendar.SUNDAY -> 7
                    else -> 1
                }

                if (daySet.contains(dartDay)) {
                    // Candidate start time
                    val startCal = (checkCal.clone() as Calendar).apply {
                        set(Calendar.HOUR_OF_DAY, sH)
                        set(Calendar.MINUTE, sM)
                        set(Calendar.SECOND, 0)
                        set(Calendar.MILLISECOND, 0)
                    }
                    if (startCal.timeInMillis > nowMillis && startCal.timeInMillis < earliestNextMillis) {
                        earliestNextMillis = startCal.timeInMillis
                    }

                    // Candidate end time
                    val endCal = (checkCal.clone() as Calendar).apply {
                        set(Calendar.HOUR_OF_DAY, eH)
                        set(Calendar.MINUTE, eM)
                        set(Calendar.SECOND, 0)
                        set(Calendar.MILLISECOND, 0)
                    }
                    if (sH * 60 + sM > eH * 60 + eM) {
                        // Overnight schedule ends on next day
                        endCal.add(Calendar.DAY_OF_YEAR, 1)
                    }
                    if (endCal.timeInMillis > nowMillis && endCal.timeInMillis < earliestNextMillis) {
                        earliestNextMillis = endCal.timeInMillis
                    }
                }
            }
        }

        if (earliestNextMillis != Long.MAX_VALUE) {
            val deltaSec = (earliestNextMillis - nowMillis) / 1000
            Log.d(TAG, "Setting next schedule transition alarm in $deltaSec seconds (at $earliestNextMillis)")
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                am.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, earliestNextMillis, pi)
            } else {
                am.setExact(AlarmManager.RTC_WAKEUP, earliestNextMillis, pi)
            }
        } else {
            am.cancel(pi)
            Log.d(TAG, "No upcoming schedule alarms found.")
        }
    }
}
