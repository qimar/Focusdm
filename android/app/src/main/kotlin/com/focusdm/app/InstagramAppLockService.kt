package com.focusdm.app

import android.accessibilityservice.AccessibilityService
import android.content.Context
import android.content.Intent
import android.view.accessibility.AccessibilityEvent

class InstagramAppLockService : AccessibilityService() {

    override fun onAccessibilityEvent(event: AccessibilityEvent?) {
        if (event == null || event.eventType != AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED) {
            return
        }

        val packageName = event.packageName?.toString() ?: return
        if (packageName == "com.instagram.android") {
            checkAndBlockInstagram()
        }
    }

    private fun checkAndBlockInstagram() {
        // Also check if any recurring schedule window is active right now
        ScheduleManager(this).checkCurrentSchedulesAndUpdateLock()

        val prefs = getSharedPreferences("FocusDMPrefs", Context.MODE_PRIVATE)
        val isFocusActive = prefs.getBoolean("is_focus_active", false)
        val focusEndTime = prefs.getLong("focus_end_time", 0L)

        val currentTime = System.currentTimeMillis()

        if (isFocusActive && currentTime < focusEndTime) {
            // Instagram launched during active focus window -> bring existing Focus DM task to front
            val intent = Intent(this, MainActivity::class.java).apply {
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_REORDER_TO_FRONT or Intent.FLAG_ACTIVITY_SINGLE_TOP)
                putExtra("route", "/focus-block")
            }
            startActivity(intent)
        } else if (isFocusActive && currentTime >= focusEndTime) {
            // Session expired naturally
            prefs.edit()
                .putBoolean("is_focus_active", false)
                .putLong("focus_end_time", 0L)
                .apply()
        }
    }

    override fun onInterrupt() {
        // Accessibility service interrupted
    }
}
