import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

// CanaryService
// Monitors in-app JS injection health and fires a Discord webhook alert
// when a critical failure is detected across multiple consecutive attempts.
// Zero-cost, silent, anonymous — only fires when things are actually broken.
class CanaryService {
  CanaryService._();
  static final CanaryService instance = CanaryService._();

  static const String _discordWebhookUrl = String.fromEnvironment(
    'DISCORD_WEBHOOK_URL',
    defaultValue: 'https://discord.com/api/webhooks/YOUR_WEBHOOK_ID/YOUR_WEBHOOK_TOKEN',
  );
  static const String _appVersion = '1.0.0';

  // Keys stored in SharedPreferences
  static const String _keyLastAlertSent    = 'canary_last_alert_ts';
  static const String _keyFailureCount     = 'canary_failure_count';
  static const String _keyLastSuccessTs    = 'canary_last_success_ts';
  static const String _keyFirstFailureTs   = 'canary_first_failure_ts';

  // Only alert once per 6 hours maximum (avoid spam)
  static const Duration _alertCooldown = Duration(hours: 6);

  // Number of consecutive failures before alerting
  static const int _failureThreshold = 3;

  // Public API

  /// Call this every time a JS bridge message is received successfully.
  Future<void> recordSuccess() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyLastSuccessTs, DateTime.now().millisecondsSinceEpoch);
    await prefs.setInt(_keyFailureCount, 0);
    await prefs.remove(_keyFirstFailureTs);
  }

  /// Manually trigger a test alert to verify Discord webhook connectivity from device.
  Future<void> sendTestAlert() async {
    await _sendDiscordAlert(
      checkId: 'manual_diagnostics_test',
      detail: 'Diagnostics test triggered directly from device Settings. All systems nominal.',
      failureCount: 1,
      firstFailure: DateTime.now(),
      lastSuccess: DateTime.now().toUtc().toIso8601String(),
    );
  }

  /// Call this when a JS injection or bridge call fails / returns unexpected data.
  /// [checkId] — short identifier like 'bridge_silent', 'xhr_badge_api', etc.
  /// [detail]  — what exactly failed or returned.
  Future<void> recordFailure({
    required String checkId,
    required String detail,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final count = (prefs.getInt(_keyFailureCount) ?? 0) + 1;
    await prefs.setInt(_keyFailureCount, count);

    final now = DateTime.now().millisecondsSinceEpoch;
    if (!prefs.containsKey(_keyFirstFailureTs)) {
      await prefs.setInt(_keyFirstFailureTs, now);
    }

    debugPrint('[Canary] Failure #$count — $checkId: $detail');

    if (count >= _failureThreshold) {
      await _maybeFireAlert(prefs, checkId: checkId, detail: detail, failureCount: count);
    }
  }

  /// Call this when the page URL changes to an unexpected path (blocked/escaped).
  Future<void> recordUnexpectedNavigation(String url) async {
    await recordFailure(
      checkId: 'unexpected_navigation',
      detail: 'Page navigated to unexpected URL: $url',
    );
  }

  /// Call this when the DM badge API returns an unexpected HTTP status.
  Future<void> recordBadgeApiFailure(int statusCode) async {
    if (statusCode != 200 && statusCode != 401) {
      await recordFailure(
        checkId: 'badge_api_status',
        detail: '/api/v1/direct_v2/get_badge_count/ returned HTTP $statusCode',
      );
    }
  }

  // Internal

  Future<void> _maybeFireAlert(
    SharedPreferences prefs, {
    required String checkId,
    required String detail,
    required int failureCount,
  }) async {
    // Enforce cooldown to avoid spamming
    final lastAlertTs = prefs.getInt(_keyLastAlertSent) ?? 0;
    final lastAlert   = DateTime.fromMillisecondsSinceEpoch(lastAlertTs);
    if (DateTime.now().difference(lastAlert) < _alertCooldown) {
      debugPrint('[Canary] Alert suppressed — cooldown active (last: $lastAlert)');
      return;
    }

    final firstFailureTs = prefs.getInt(_keyFirstFailureTs) ?? DateTime.now().millisecondsSinceEpoch;
    final firstFailure   = DateTime.fromMillisecondsSinceEpoch(firstFailureTs);
    final lastSuccessTs  = prefs.getInt(_keyLastSuccessTs) ?? 0;
    final lastSuccess    = lastSuccessTs > 0
        ? DateTime.fromMillisecondsSinceEpoch(lastSuccessTs).toUtc().toIso8601String()
        : 'unknown';

    await prefs.setInt(_keyLastAlertSent, DateTime.now().millisecondsSinceEpoch);

    try {
      await _sendDiscordAlert(
        checkId: checkId,
        detail: detail,
        failureCount: failureCount,
        firstFailure: firstFailure,
        lastSuccess: lastSuccess,
      );
    } catch (e) {
      debugPrint('[Canary] Failed to send Discord alert: $e');
    }
  }

  Future<void> _sendDiscordAlert({
    required String checkId,
    required String detail,
    required int failureCount,
    required DateTime firstFailure,
    required String lastSuccess,
  }) async {
    final now = DateTime.now().toUtc();
    final firstFailureUnix = firstFailure.millisecondsSinceEpoch ~/ 1000;
    final nowUnix = now.millisecondsSinceEpoch ~/ 1000;

    final embed = {
      'title': '🔴 IN-APP ALERT — Focus DM JS Bridge Failure',
      'description':
          'The Focus DM app has detected **$failureCount consecutive JS injection/bridge failures** on a user device. '
          'This indicates Instagram web may have changed in a way that breaks app functionality.',
      'color': 0xFF3B30,
      'timestamp': now.toIso8601String(),
      'fields': [
        {
          'name': '🔍 Failed Check',
          'value': '`$checkId`',
          'inline': true,
        },
        {
          'name': '💥 Failure Detail',
          'value': '```$detail```',
          'inline': false,
        },
        {
          'name': '🔢 Consecutive Failures',
          'value': '**$failureCount** (threshold: $_failureThreshold)',
          'inline': true,
        },
        {
          'name': '📱 Focus DM Version',
          'value': '`v$_appVersion`',
          'inline': true,
        },
        {
          'name': '📍 Platform',
          'value': '`${Platform.operatingSystem} ${Platform.operatingSystemVersion}`',
          'inline': true,
        },
        {
          'name': '⏱️ First Failure Detected',
          'value': '<t:$firstFailureUnix:F> (<t:$firstFailureUnix:R>)',
          'inline': true,
        },
        {
          'name': '✅ Last Successful Bridge Call',
          'value': lastSuccess == 'unknown' ? 'Unknown' : lastSuccess,
          'inline': true,
        },
        {
          'name': '🕐 Alert Fired At',
          'value': '<t:$nowUnix:F>',
          'inline': true,
        },
        {
          'name': '📋 Source',
          'value': '`In-App Telemetry` — reported from a real user device session',
          'inline': false,
        },
        {
          'name': '⚡ What to Do',
          'value':
              '1. Cross-check with the **GitHub Actions Canary** for confirmation\n'
              '2. Open instagram.com/direct/inbox/ on desktop → DevTools\n'
              '3. Inspect if the failing selector/API has changed\n'
              '4. Update `inbox_screen.dart → _blockingScript` accordingly\n'
              '5. Release a hotfix build',
          'inline': false,
        },
      ],
      'footer': {
        'text': 'Focus DM In-App Canary • In-app telemetry alert • Fires after $_failureThreshold consecutive failures',
      },
    };

    if (_discordWebhookUrl.isEmpty) {
      debugPrint('[Canary] DISCORD_WEBHOOK_URL is not configured. Skipping alert.');
      return;
    }

    final payload = jsonEncode({
      'username': 'Focus DM In-App Canary',
      'embeds': [embed],
    });

    final response = await http.post(
      Uri.parse(_discordWebhookUrl),
      headers: {'Content-Type': 'application/json'},
      body: payload,
    );

    debugPrint('[Canary] Discord alert HTTP ${response.statusCode}');
  }
}
