import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FocusModeService extends ChangeNotifier {
  FocusModeService._();
  static final FocusModeService instance = FocusModeService._();

  static const MethodChannel _channel = MethodChannel('com.example.focus_dm/focus_mode');

  bool _isActive = false;
  DateTime? _endTime;
  Timer? _ticker;

  bool get isActive => _isActive;
  DateTime? get endTime => _endTime;

  Duration get remainingDuration {
    if (!_isActive || _endTime == null) return Duration.zero;
    final diff = _endTime!.difference(DateTime.now());
    return diff.isNegative ? Duration.zero : diff;
  }

  Future<void> init() async {
    _channel.setMethodCallHandler(_handleNativeCall);
    await syncStatus();
    _startPeriodicSync();
  }

  Timer? _periodicSyncTimer;
  void _startPeriodicSync() {
    _periodicSyncTimer?.cancel();
    // Periodically sync status every 10 seconds to catch schedule transitions automatically
    _periodicSyncTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      syncStatus();
    });
  }

  Future<dynamic> _handleNativeCall(MethodCall call) async {
    if (call.method == 'onNavigateRoute') {
      final route = call.arguments as String?;
      if (route != null && onNavigateRequested != null) {
        onNavigateRequested!(route);
      }
    } else if (call.method == 'onFocusStateChanged') {
      await syncStatus();
    }
  }

  void Function(String route)? onNavigateRequested;

  Future<void> syncStatus() async {
    try {
      final res = await _channel.invokeMethod<Map>('getFocusModeStatus');
      if (res != null) {
        final active = res['isActive'] as bool? ?? false;
        final endMillis = res['endTime'] as int? ?? 0;

        _isActive = active;
        _endTime = endMillis > 0 ? DateTime.fromMillisecondsSinceEpoch(endMillis) : null;

        if (_isActive && remainingDuration > Duration.zero) {
          _startTicker();
        } else {
          _stopTicker();
          _isActive = false;
          _endTime = null;
        }
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error syncing focus mode: $e');
    }
  }

  Future<bool> isAccessibilityGranted() async {
    try {
      final granted = await _channel.invokeMethod<bool>('isAccessibilityPermissionGranted');
      return granted ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<void> openAccessibilitySettings() async {
    try {
      await _channel.invokeMethod('openAccessibilitySettings');
    } catch (_) {}
  }

  Future<bool> startFocusMode(DateTime targetEndTime) async {
    try {
      final endMillis = targetEndTime.millisecondsSinceEpoch;
      await _channel.invokeMethod('startFocusMode', {'endTime': endMillis});

      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('is_focus_active', true);
      await prefs.setInt('focus_end_time', endMillis);

      _isActive = true;
      _endTime = targetEndTime;
      _startTicker();
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Failed to start focus mode: $e');
      return false;
    }
  }

  Future<void> stopFocusMode() async {
    try {
      await _channel.invokeMethod('stopFocusMode');
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('is_focus_active');
      await prefs.remove('focus_end_time');

      _isActive = false;
      _endTime = null;
      _stopTicker();
      notifyListeners();
    } catch (e) {
      debugPrint('Failed to stop focus mode: $e');
    }
  }

  Future<void> minimizeToHome() async {
    try {
      await _channel.invokeMethod('minimizeToHome');
    } catch (_) {}
  }

  void _startTicker() {
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (remainingDuration <= Duration.zero) {
        _stopTicker();
        _isActive = false;
        _endTime = null;
        notifyListeners();
      } else {
        notifyListeners();
      }
    });
  }

  void _stopTicker() {
    _ticker?.cancel();
    _ticker = null;
  }

  @override
  void dispose() {
    _stopTicker();
    super.dispose();
  }
}
