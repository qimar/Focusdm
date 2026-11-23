package com.focusdm.app

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

class BootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context?, intent: Intent?) {
        if (context == null || intent?.action != Intent.ACTION_BOOT_COMPLETED) {
            return
        }

        val prefs = context.getSharedPreferences("FocusDMPrefs", Context.MODE_PRIVATE)
        val isFocusActive = prefs.getBoolean("is_focus_active", false)
        val focusEndTime = prefs.getLong("focus_end_time", 0L)

        // If phone restarted after expiration, reset state
        if (isFocusActive && System.currentTimeMillis() >= focusEndTime) {
            prefs.edit()
                .putBoolean("is_focus_active", false)
                .putLong("focus_end_time", 0L)
                .apply()
        }
        // If still within focus period, is_focus_active remains true in SharedPreferences
        // and InstagramAppLockService will continue intercepting automatically.

        // Reschedule recurring Focus Mode schedules after reboot
        val scheduleManager = ScheduleManager(context)
        scheduleManager.checkCurrentSchedulesAndUpdateLock()
        scheduleManager.scheduleNextAlarms()

        // Reschedule background DM poll alarm after reboot
        BgPollReceiver.schedule(context)
    }
}
