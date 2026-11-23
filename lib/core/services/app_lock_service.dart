import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppLockService extends ChangeNotifier {
  AppLockService._();
  static final AppLockService instance = AppLockService._();

  final LocalAuthentication _auth = LocalAuthentication();

  static const String _keyAppLockEnabled = 'app_lock_enabled';
  static const String _keyBiometricsEnabled = 'app_lock_biometrics_enabled';
  static const String _keyPinHash = 'app_lock_pin_hash';

  bool _isLockEnabled = false;
  bool _isBiometricsEnabled = true;
  String? _pinHash;

  // Transient in-memory lock state
  bool _isUnlocked = false;
  int _failedAttempts = 0;
  DateTime? _lockoutUntil;

  bool get isLockEnabled => _isLockEnabled;
  bool get isBiometricsEnabled => _isBiometricsEnabled;
  bool get hasPin => _pinHash != null && _pinHash!.isNotEmpty;
  bool get isUnlocked => _isUnlocked;
  bool get isLockedOut => remainingLockoutSeconds > 0;
  int get remainingLockoutSeconds {
    if (_lockoutUntil == null) return 0;
    final diff = _lockoutUntil!.difference(DateTime.now()).inSeconds;
    return diff > 0 ? diff : 0;
  }

  bool get requiresUnlock => _isLockEnabled && !_isUnlocked;

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _isLockEnabled = prefs.getBool(_keyAppLockEnabled) ?? false;
    _isBiometricsEnabled = prefs.getBool(_keyBiometricsEnabled) ?? true;
    _pinHash = prefs.getString(_keyPinHash);
    notifyListeners();
  }

  void lockApp() {
    if (_isLockEnabled && _isUnlocked) {
      _isUnlocked = false;
      notifyListeners();
    }
  }

  void unlockApp() {
    _isUnlocked = true;
    notifyListeners();
  }

  String _hashPin(String pin) {
    final bytes = utf8.encode('focus_dm_salt_$pin');
    return sha256.convert(bytes).toString();
  }

  Future<bool> setPin(String pin) async {
    final hash = _hashPin(pin);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyPinHash, hash);
    await prefs.setBool(_keyAppLockEnabled, true);
    _pinHash = hash;
    _isLockEnabled = true;
    _isUnlocked = true;
    notifyListeners();
    return true;
  }

  bool verifyPin(String pin) {
    if (_pinHash == null || isLockedOut) return false;
    final match = _hashPin(pin) == _pinHash;
    if (match) {
      _failedAttempts = 0;
      _lockoutUntil = null;
      unlockApp();
    } else {
      _failedAttempts++;
      if (_failedAttempts >= 5) {
        _lockoutUntil = DateTime.now().add(const Duration(seconds: 30));
        notifyListeners();
      }
    }
    return match;
  }

  Future<void> disableAppLock() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyAppLockEnabled, false);
    await prefs.remove(_keyPinHash);
    _isLockEnabled = false;
    _pinHash = null;
    _isUnlocked = false;
    notifyListeners();
  }

  Future<void> setBiometricsEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyBiometricsEnabled, enabled);
    _isBiometricsEnabled = enabled;
    notifyListeners();
  }

  Future<bool> canCheckBiometrics() async {
    try {
      final canAuthenticateWithBiometrics = await _auth.canCheckBiometrics;
      final canAuthenticate = canAuthenticateWithBiometrics || await _auth.isDeviceSupported();
      return canAuthenticate;
    } catch (_) {
      return false;
    }
  }

  Future<bool> authenticateWithBiometrics() async {
    if (!_isBiometricsEnabled) return false;
    try {
      final authenticated = await _auth.authenticate(
        localizedReason: 'Scan fingerprint or face to unlock Focus DM',
        biometricOnly: true,
        persistAcrossBackgrounding: true,
      );
      if (authenticated) {
        unlockApp();
      }
      return authenticated;
    } catch (e) {
      debugPrint('Biometric authentication failed: $e');
      return false;
    }
  }
}
