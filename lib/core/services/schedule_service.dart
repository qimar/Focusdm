import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/focus_schedule.dart';
import 'focus_mode_service.dart';

class ScheduleService extends ChangeNotifier {
  ScheduleService._();
  static final ScheduleService instance = ScheduleService._();

  static const MethodChannel _channel = MethodChannel('com.example.focus_dm/focus_mode');
  static const String _storageKey = 'focus_schedules_list';

  List<FocusSchedule> _schedules = [];
  List<FocusSchedule> get schedules => List.unmodifiable(_schedules);

  Future<void> init() async {
    await loadSchedules();
  }

  Future<void> loadSchedules() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = prefs.getString(_storageKey);
      if (jsonStr != null && jsonStr.isNotEmpty) {
        final List<dynamic> list = json.decode(jsonStr) as List<dynamic>;
        _schedules = list.map((e) => FocusSchedule.fromMap(e as Map<String, dynamic>)).toList();
      } else {
        _schedules = [];
      }
      notifyListeners();
      await _syncWithNative();
    } catch (e) {
      debugPrint('Error loading schedules: $e');
    }
  }

  Future<void> addSchedule(FocusSchedule schedule) async {
    _schedules.add(schedule);
    await _saveAndSync();
  }

  Future<void> updateSchedule(FocusSchedule schedule) async {
    final index = _schedules.indexWhere((s) => s.id == schedule.id);
    if (index != -1) {
      _schedules[index] = schedule;
      await _saveAndSync();
    }
  }

  Future<void> toggleSchedule(String id, bool isEnabled) async {
    final index = _schedules.indexWhere((s) => s.id == id);
    if (index != -1) {
      _schedules[index] = _schedules[index].copyWith(isEnabled: isEnabled);
      await _saveAndSync();
    }
  }

  Future<void> deleteSchedule(String id) async {
    _schedules.removeWhere((s) => s.id == id);
    await _saveAndSync();
  }

  Future<void> _saveAndSync() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonList = _schedules.map((s) => s.toMap()).toList();
      final jsonStr = json.encode(jsonList);
      await prefs.setString(_storageKey, jsonStr);
      notifyListeners();
      await _syncWithNative();
      // Also update FocusModeService in case active state changed right now
      await FocusModeService.instance.syncStatus();
    } catch (e) {
      debugPrint('Error saving schedules: $e');
    }
  }

  Future<void> _syncWithNative() async {
    try {
      final jsonList = _schedules.map((s) => s.toMap()).toList();
      final jsonStr = json.encode(jsonList);
      await _channel.invokeMethod('syncSchedules', {'schedulesJson': jsonStr});
    } catch (e) {
      debugPrint('Error syncing schedules with native: $e');
    }
  }
}
