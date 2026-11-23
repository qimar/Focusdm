package com.focusdm.app

import android.accessibilityservice.AccessibilityServiceInfo
import android.content.Context
import android.content.Intent
import android.os.Bundle
import android.provider.Settings
import android.view.accessibility.AccessibilityManager
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterFragmentActivity() {
    companion object {
        const val CHANNEL = "com.example.focus_dm/focus_mode"
        var activeEngine: FlutterEngine? = null

        fun notifyFocusStateChanged() {
            activeEngine?.dartExecutor?.binaryMessenger?.let { messenger ->
                MethodChannel(messenger, CHANNEL).invokeMethod("onFocusStateChanged", null)
            }
        }
    }

    private var pendingRoute: String? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        handleIntent(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        handleIntent(intent)
    }

    private fun handleIntent(intent: Intent?) {
        val route = intent?.getStringExtra("route")
        if (route != null) {
            pendingRoute = route
            try {
                flutterEngine?.dartExecutor?.binaryMessenger?.let { messenger ->
                    MethodChannel(messenger, CHANNEL).invokeMethod("onNavigateRoute", route)
                }
            } catch (e: Exception) {
                // FlutterEngine may not be attached yet in onCreate (e.g. cold launch)
                // pendingRoute will be delivered in configureFlutterEngine once attached
            }
        }
    }

    override fun onDestroy() {
        if (activeEngine == flutterEngine) {
            activeEngine = null
        }
        super.onDestroy()
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        activeEngine = flutterEngine

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            val prefs = getSharedPreferences("FocusDMPrefs", Context.MODE_PRIVATE)

            when (call.method) {
                "isAccessibilityPermissionGranted" -> {
                    result.success(isAccessibilityServiceEnabled())
                }
                "openAccessibilitySettings" -> {
                    val intent = Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS).apply {
                        addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                    }
                    startActivity(intent)
                    result.success(true)
                }
                "startFocusMode" -> {
                    val endTime = call.argument<Long>("endTime") ?: 0L
                    prefs.edit()
                        .putBoolean("is_focus_active", true)
                        .putLong("focus_end_time", endTime)
                        .apply()
                    result.success(true)
                }
                "stopFocusMode" -> {
                    prefs.edit()
                        .putBoolean("is_focus_active", false)
                        .putLong("focus_end_time", 0L)
                        .apply()
                    result.success(true)
                }
                "getFocusModeStatus" -> {
                    val isActive = prefs.getBoolean("is_focus_active", false)
                    val endTime = prefs.getLong("focus_end_time", 0L)
                    val map = mapOf(
                        "isActive" to (isActive && System.currentTimeMillis() < endTime),
                        "endTime" to endTime
                    )
                    result.success(map)
                }
                "minimizeToHome" -> {
                    val homeIntent = Intent(Intent.ACTION_MAIN).apply {
                        addCategory(Intent.CATEGORY_HOME)
                        flags = Intent.FLAG_ACTIVITY_NEW_TASK
                    }
                    startActivity(homeIntent)
                    result.success(true)
                }
                "startBgPoll" -> {
                    BgPollReceiver.schedule(applicationContext)
                    result.success(true)
                }
                "stopBgPoll" -> {
                    BgPollReceiver.cancel(applicationContext)
                    result.success(true)
                }
                "syncSchedules" -> {
                    val schedulesJson = call.argument<String>("schedulesJson") ?: "[]"
                    ScheduleManager(applicationContext).saveSchedules(schedulesJson)
                    result.success(true)
                }
                "getPendingRoute" -> {
                    val route = pendingRoute
                    pendingRoute = null
                    result.success(route)
                }
                else -> result.notImplemented()
            }
        }

        // If there was a pending route delivered before engine initialization
        pendingRoute?.let { route ->
            MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).invokeMethod("onNavigateRoute", route)
        }
    }

    private fun isAccessibilityServiceEnabled(): Boolean {
        val am = getSystemService(Context.ACCESSIBILITY_SERVICE) as? AccessibilityManager ?: return false
        val enabledServices = am.getEnabledAccessibilityServiceList(AccessibilityServiceInfo.FEEDBACK_ALL_MASK)
        val expectedServiceId = "$packageName/${InstagramAppLockService::class.java.canonicalName}"
        val expectedSimpleServiceId = "$packageName/.InstagramAppLockService"

        for (service in enabledServices) {
            val id = service.id
            if (id.equals(expectedServiceId, ignoreCase = true) || id.equals(expectedSimpleServiceId, ignoreCase = true)) {
                return true
            }
        }
        return false
    }
}
