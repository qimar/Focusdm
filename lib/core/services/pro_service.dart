import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ProService extends ChangeNotifier {
  ProService._();
  static final ProService instance = ProService._();

  static const String _keyIsPro = 'focus_dm_is_pro_user';
  static const int kFreeMaxFocusDurationMinutes = 30;

  bool _isPro = false;
  bool get isPro => _isPro;

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _isPro = prefs.getBool(_keyIsPro) ?? false;
    notifyListeners();
  }

  Future<void> setPro(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyIsPro, value);
    _isPro = value;
    notifyListeners();
  }

  /// Verifies if a requested Focus Mode duration is allowed.
  /// Free tier is limited to [kFreeMaxFocusDurationMinutes] minutes.
  bool isDurationAllowed(Duration duration) {
    if (_isPro) return true;
    return duration.inMinutes <= kFreeMaxFocusDurationMinutes;
  }
}
