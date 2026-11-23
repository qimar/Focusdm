import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'pro_service.dart';

class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  static final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  static const MethodChannel _channel =
      MethodChannel('com.example.focus_dm/focus_mode');

  static const String _channelId = 'focus_dm_messages';
  static const String _channelName = 'Direct Messages';
  static const String _channelDesc =
      'Notifications for new Instagram Direct Messages';
  static const int    _dmNotifId = 88888;
  static const String _prefKey   = 'notifications_enabled';

  // Enabled/disabled preference
  static Future<bool> isEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_prefKey) ?? true; // on by default
  }

  static Future<void> setEnabled(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefKey, value);
  }

  Future<void> init() async {
    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidSettings);

    await _notificationsPlugin.initialize(
      settings: initSettings,
      onDidReceiveNotificationResponse: (response) {
        // Notification tapped — app is already open, nothing extra needed
      },
    );

    // Create high-importance notification channel
    final androidChannel = AndroidNotificationChannel(
      _channelId,
      _channelName,
      description: _channelDesc,
      importance: Importance.max,
      playSound: true,
      enableVibration: true,
    );

    await _notificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(androidChannel);

    // Request notification permission for Android 13+
    await _notificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();

    // Kick off the native AlarmManager-based background poll
    try {
      await _channel.invokeMethod('startBgPoll');
    } catch (e) {
      debugPrint('BgPoll start error: $e');
    }
  }

  /// Trigger instant notification when a new DM is detected via JS bridge.
  Future<void> showInstantMessageNotification({
    required String sender,
    required String message,
  }) async {
    // Pro-only feature
    if (!ProService.instance.isPro) return;

    // Respect the user's notifications toggle in Settings
    if (!await NotificationService.isEnabled()) return;

    final androidDetails = AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: _channelDesc,
      importance: Importance.max,
      priority: Priority.high,
      showWhen: true,
      enableVibration: true,
      playSound: true,
      styleInformation: BigTextStyleInformation(
        message,
        contentTitle: sender,
        summaryText: 'Focus DM',
      ),
    );

    final details = NotificationDetails(android: androidDetails);

    // Always use the same ID so the notification is updated in-place,
    // not stacked as a second (or third) entry in the shade.
    await _notificationsPlugin.show(
      id: _dmNotifId,
      title: sender,
      body: message,
      notificationDetails: details,
    );
  }

  /// Show a badge-count notification (called from native Kotlin BgPollReceiver
  /// via MethodChannel, or directly when needed).
  static Future<void> showBackgroundMessageNotification(int count) async {
    // Pro-only feature
    if (!ProService.instance.isPro) return;
    if (!await NotificationService.isEnabled()) return;
    const androidDetails = AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: _channelDesc,
      importance: Importance.max,
      priority: Priority.high,
      showWhen: true,
      enableVibration: true,
      playSound: true,
    );

    const details = NotificationDetails(android: androidDetails);
    final countStr = count > 3 ? '$count+' : '$count';
    final body = count == 1
        ? 'You have a new message on Instagram'
        : 'You have $countStr unread messages on Instagram';

    await _notificationsPlugin.show(
      id: _dmNotifId, // same fixed ID → replaces existing notification in-place
      title: 'Instagram Direct',
      body: body,
      notificationDetails: details,
    );
  }
}
