package com.focusdm.app

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log

class ScheduleAlarmReceiver : BroadcastReceiver() {
    companion object {
        private const val TAG = "FocusDM_ScheduleReceiver"
    }

    override fun onReceive(context: Context?, intent: Intent?) {
        if (context == null || intent == null) return

        val action = intent.action
        Log.d(TAG, "ScheduleAlarmReceiver received action: $action")

        val scheduleManager = ScheduleManager(context)
        scheduleManager.checkCurrentSchedulesAndUpdateLock()
        // Reschedule alarms for next windows
        scheduleManager.scheduleNextAlarms()

        // Inform running Flutter UI to update Focus Mode state live
        MainActivity.notifyFocusStateChanged()
    }
}
