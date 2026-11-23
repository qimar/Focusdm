import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'app_constants.dart';

// AuthState
// Singleton ChangeNotifier that tracks whether the user has an active Instagram
// session. go_router listens to this via refreshListenable to auto-redirect
// when auth state changes (login or logout).

class AuthState extends ChangeNotifier {
  AuthState._();
  static final AuthState instance = AuthState._();

  bool _isLoggedIn = false;
  bool get isLoggedIn => _isLoggedIn;

  /// Called once from main() to sync in-memory state from SharedPreferences
  /// before runApp(). Does NOT notify listeners (router not attached yet).
  void hydrate(bool value) {
    _isLoggedIn = value;
  }

  /// Mark the user as logged in and persist to SharedPreferences.
  /// Notifying listeners triggers go_router to re-evaluate its redirect.
  Future<void> logIn() async {
    _isLoggedIn = true;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(AppConstants.kIsLoggedIn, true);
    notifyListeners();
  }

  /// Clear the session — wipes prefs flag.
  /// WebView cookies must be cleared separately (done in SettingsScreen).
  Future<void> logOut() async {
    _isLoggedIn = false;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(AppConstants.kIsLoggedIn, false);
    notifyListeners();
  }
}
