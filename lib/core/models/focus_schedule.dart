import 'dart:convert';

class FocusSchedule {
  final String id;
  final String title;
  final int startHour;
  final int startMinute;
  final int endHour;
  final int endMinute;
  /// Days of week enabled: Mon=1, Tue=2, Wed=3, Thu=4, Fri=5, Sat=6, Sun=7 (standard DateTime weekday)
  final List<int> days;
  final bool isEnabled;

  const FocusSchedule({
    required this.id,
    required this.title,
    required this.startHour,
    required this.startMinute,
    required this.endHour,
    required this.endMinute,
    required this.days,
    this.isEnabled = true,
  });

  FocusSchedule copyWith({
    String? id,
    String? title,
    int? startHour,
    int? startMinute,
    int? endHour,
    int? endMinute,
    List<int>? days,
    bool? isEnabled,
  }) {
    return FocusSchedule(
      id: id ?? this.id,
      title: title ?? this.title,
      startHour: startHour ?? this.startHour,
      startMinute: startMinute ?? this.startMinute,
      endHour: endHour ?? this.endHour,
      endMinute: endMinute ?? this.endMinute,
      days: days ?? this.days,
      isEnabled: isEnabled ?? this.isEnabled,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'startHour': startHour,
      'startMinute': startMinute,
      'endHour': endHour,
      'endMinute': endMinute,
      'days': days,
      'isEnabled': isEnabled,
    };
  }

  factory FocusSchedule.fromMap(Map<String, dynamic> map) {
    return FocusSchedule(
      id: map['id'] as String,
      title: map['title'] as String? ?? 'Schedule',
      startHour: map['startHour'] as int,
      startMinute: map['startMinute'] as int,
      endHour: map['endHour'] as int,
      endMinute: map['endMinute'] as int,
      days: (map['days'] as List<dynamic>?)?.map((e) => e as int).toList() ?? [1, 2, 3, 4, 5],
      isEnabled: map['isEnabled'] as bool? ?? true,
    );
  }

  String toJson() => json.encode(toMap());

  factory FocusSchedule.fromJson(String source) =>
      FocusSchedule.fromMap(json.decode(source) as Map<String, dynamic>);

  String get timeRangeFormatted {
    final startPeriod = startHour >= 12 ? 'PM' : 'AM';
    final sH = startHour == 0 ? 12 : (startHour > 12 ? startHour - 12 : startHour);
    final sM = startMinute.toString().padLeft(2, '0');

    final endPeriod = endHour >= 12 ? 'PM' : 'AM';
    final eH = endHour == 0 ? 12 : (endHour > 12 ? endHour - 12 : endHour);
    final eM = endMinute.toString().padLeft(2, '0');

    return '$sH:$sM $startPeriod - $eH:$eM $endPeriod';
  }

  String get daysFormatted {
    if (days.length == 7) return 'Every day';
    if (days.length == 5 &&
        days.contains(1) &&
        days.contains(2) &&
        days.contains(3) &&
        days.contains(4) &&
        days.contains(5)) {
      return 'Weekdays';
    }
    if (days.length == 2 && days.contains(6) && days.contains(7)) {
      return 'Weekends';
    }
    const dayNames = {1: 'Mon', 2: 'Tue', 3: 'Wed', 4: 'Thu', 5: 'Fri', 6: 'Sat', 7: 'Sun'};
    final sorted = List<int>.from(days)..sort();
    return sorted.map((d) => dayNames[d] ?? '').join(', ');
  }
}
