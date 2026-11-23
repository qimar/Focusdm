import 'package:flutter/material.dart';
import 'package:sizer/sizer.dart';
import '../../../core/models/focus_schedule.dart';
import '../../../core/services/schedule_service.dart';
import '../../../core/services/focus_mode_service.dart';
import '../../widgets/animated_transitions.dart';
import '../../widgets/animated_dialog.dart';

class SchedulesScreen extends StatefulWidget {
  const SchedulesScreen({super.key});

  @override
  State<SchedulesScreen> createState() => _SchedulesScreenState();
}

class _SchedulesScreenState extends State<SchedulesScreen> {
  static const Color _bg = Color(0xFF0C1014);
  static const Color _cardBg = Color(0xFF212328);
  static const Color _surface = Color(0xFF25292E);
  static const Color _outline = Color(0xFF8A8D92);
  static const Color _onSurface = Color(0xFFA8A8A8);
  static const Color _dividerColor = Color(0xFF2F333A);
  static const Color _accent = Color(0xFF34D399);

  @override
  void initState() {
    super.initState();
    ScheduleService.instance.addListener(_onServiceChanged);
  }

  void _onServiceChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    ScheduleService.instance.removeListener(_onServiceChanged);
    super.dispose();
  }

  void _openScheduleEditor([FocusSchedule? existing]) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: _surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _ScheduleEditorSheet(schedule: existing),
    );
  }

  void _confirmDelete(FocusSchedule schedule) {
    showAnimatedDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: _cardBg,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: _dividerColor, width: 0.5),
        ),
        title: const Text(
          'Delete Schedule?',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        ),
        content: Text(
          'Are you sure you want to remove "${schedule.title}"?',
          style: TextStyle(color: _onSurface, fontSize: 13.sp),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel', style: TextStyle(color: _onSurface)),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              ScheduleService.instance.deleteSchedule(schedule.id);
            },
            child: const Text('Delete',
                style: TextStyle(color: Color(0xFFED4956), fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final schedules = ScheduleService.instance.schedules;

    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 4.5.w),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Scheduled Focus',
          style: TextStyle(
            color: Colors.white,
            fontSize: 16.sp,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.3,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.add_rounded, color: Colors.white, size: 6.5.w),
            tooltip: 'Add Schedule',
            onPressed: () async {
              final hasPerm = await FocusModeService.instance.isAccessibilityGranted();
              if (!mounted) return;
              if (!hasPerm) {
                _showAccessibilityPrompt();
                return;
              }
              _openScheduleEditor();
            },
          ),
        ],
      ),
      body: schedules.isEmpty
          ? _buildEmptyState()
          : ListView.builder(
              padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 2.h),
              itemCount: schedules.length,
              itemBuilder: (ctx, index) {
                final schedule = schedules[index];
                return FadeSlideEntrance(
                  delay: Duration(milliseconds: 60 * index),
                  child: Container(
                    margin: EdgeInsets.only(bottom: 1.5.h),
                    decoration: BoxDecoration(
                      color: _cardBg,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: _dividerColor, width: 0.5),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: InkWell(
                      onTap: () => _openScheduleEditor(schedule),
                      child: Padding(
                        padding: EdgeInsets.all(4.w),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          schedule.title,
                                          overflow: TextOverflow.ellipsis,
                                          maxLines: 1,
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 14.sp,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  SizedBox(height: 0.5.h),
                                  Text(
                                    schedule.timeRangeFormatted,
                                    style: TextStyle(
                                      color: _accent,
                                      fontSize: 13.sp,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 0.3,
                                    ),
                                  ),
                                  SizedBox(height: 0.3.h),
                                  Text(
                                    schedule.daysFormatted,
                                    style: TextStyle(
                                      color: _outline,
                                      fontSize: 11.5.sp,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Switch.adaptive(
                              value: schedule.isEnabled,
                              activeThumbColor: Colors.white,
                              activeTrackColor: _accent,
                              inactiveThumbColor: Colors.white70,
                              inactiveTrackColor: _dividerColor,
                              onChanged: (val) {
                                ScheduleService.instance.toggleSchedule(schedule.id, val);
                              },
                            ),
                            IconButton(
                              icon: Icon(Icons.delete_outline_rounded,
                                  color: _outline, size: 5.w),
                              onPressed: () => _confirmDelete(schedule),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
    );
  }

  void _showAccessibilityPrompt() {
    showAnimatedDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: _cardBg,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: _dividerColor, width: 0.5),
        ),
        title: const Text(
          'Permission Required',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        ),
        content: Text(
          'Scheduled Focus requires Accessibility permission to lock the Instagram app on time.\n\nPlease enable it in Settings.',
          style: TextStyle(color: _onSurface, fontSize: 13.sp),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel', style: TextStyle(color: _onSurface)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: Colors.black,
            ),
            onPressed: () {
              Navigator.of(context).pop();
              FocusModeService.instance.openAccessibilitySettings();
            },
            child: const Text('Enable', style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 8.w),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 18.w,
              height: 18.w,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _cardBg,
                border: Border.all(color: _dividerColor),
              ),
              child: Icon(Icons.alarm_on_rounded, color: _outline, size: 9.w),
            ),
            SizedBox(height: 2.h),
            Text(
              'No Active Schedules',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16.sp,
                fontWeight: FontWeight.w700,
              ),
            ),
            SizedBox(height: 1.h),
            Text(
              'Automatically lock Instagram during your regular work hours or bedtime.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: _onSurface,
                fontSize: 12.sp,
                height: 1.4,
              ),
            ),
            SizedBox(height: 3.h),
            BouncyTap(
              onTap: () async {
                final hasPerm = await FocusModeService.instance.isAccessibilityGranted();
                if (!mounted) return;
                if (!hasPerm) {
                  _showAccessibilityPrompt();
                  return;
                }
                _openScheduleEditor();
              },
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 1.5.h),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'Add First Schedule',
                  style: TextStyle(
                    color: Colors.black,
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ScheduleEditorSheet extends StatefulWidget {
  final FocusSchedule? schedule;

  const _ScheduleEditorSheet({this.schedule});

  @override
  State<_ScheduleEditorSheet> createState() => _ScheduleEditorSheetState();
}

class _ScheduleEditorSheetState extends State<_ScheduleEditorSheet> {
  late TextEditingController _titleController;
  late TimeOfDay _startTime;
  late TimeOfDay _endTime;
  late Set<int> _selectedDays;

  @override
  void initState() {
    super.initState();
    final s = widget.schedule;
    _titleController = TextEditingController(text: s?.title ?? 'Work Focus');
    _startTime = s != null
        ? TimeOfDay(hour: s.startHour, minute: s.startMinute)
        : const TimeOfDay(hour: 9, minute: 0);
    _endTime = s != null
        ? TimeOfDay(hour: s.endHour, minute: s.endMinute)
        : const TimeOfDay(hour: 17, minute: 0);
    _selectedDays = s != null ? s.days.toSet() : {1, 2, 3, 4, 5};
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  Future<void> _pickTime(bool isStart) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: isStart ? _startTime : _endTime,
      builder: (ctx, child) {
        return Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: const ColorScheme.dark(
              primary: Colors.white,
              onPrimary: Colors.black,
              surface: Color(0xFF25292E),
              onSurface: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        if (isStart) {
          _startTime = picked;
        } else {
          _endTime = picked;
        }
      });
    }
  }

  String _formatTime(TimeOfDay t) {
    final period = t.period == DayPeriod.am ? 'AM' : 'PM';
    final h = t.hourOfPeriod == 0 ? 12 : t.hourOfPeriod;
    final m = t.minute.toString().padLeft(2, '0');
    return '$h:$m $period';
  }

  void _save() async {
    if (_selectedDays.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least one day.')),
      );
      return;
    }

    final id = widget.schedule?.id ?? DateTime.now().millisecondsSinceEpoch.toString();
    final schedule = FocusSchedule(
      id: id,
      title: _titleController.text.trim().isEmpty ? 'Focus Schedule' : _titleController.text.trim(),
      startHour: _startTime.hour,
      startMinute: _startTime.minute,
      endHour: _endTime.hour,
      endMinute: _endTime.minute,
      days: _selectedDays.toList()..sort(),
      isEnabled: widget.schedule?.isEnabled ?? true,
    );

    if (widget.schedule == null) {
      await ScheduleService.instance.addSchedule(schedule);
    } else {
      await ScheduleService.instance.updateSchedule(schedule);
    }
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    const dayLabels = {1: 'M', 2: 'T', 3: 'W', 4: 'T', 5: 'F', 6: 'S', 7: 'S'};

    return Padding(
      padding: EdgeInsets.only(
        left: 5.w,
        right: 5.w,
        top: 3.h,
        bottom: MediaQuery.of(context).viewInsets.bottom + 3.h,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                widget.schedule == null ? 'New Focus Schedule' : 'Edit Schedule',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16.sp,
                  fontWeight: FontWeight.w700,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded, color: Colors.white70),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
          SizedBox(height: 2.h),

          // Title input
          TextField(
            controller: _titleController,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              labelText: 'Schedule Name',
              labelStyle: const TextStyle(color: Color(0xFF8A8D92)),
              filled: true,
              fillColor: const Color(0xFF212328),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFF2F333A)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFF2F333A)),
              ),
            ),
          ),
          SizedBox(height: 2.h),

          // Time range pickers
          Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: () => _pickTime(true),
                  child: Container(
                    padding: EdgeInsets.all(3.5.w),
                    decoration: BoxDecoration(
                      color: const Color(0xFF212328),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFF2F333A)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('START TIME',
                            style: TextStyle(
                                color: const Color(0xFF8A8D92),
                                fontSize: 9.5.sp,
                                fontWeight: FontWeight.w700)),
                        SizedBox(height: 0.5.h),
                        Text(_formatTime(_startTime),
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 15.sp,
                                fontWeight: FontWeight.w700)),
                      ],
                    ),
                  ),
                ),
              ),
              SizedBox(width: 3.w),
              Expanded(
                child: InkWell(
                  onTap: () => _pickTime(false),
                  child: Container(
                    padding: EdgeInsets.all(3.5.w),
                    decoration: BoxDecoration(
                      color: const Color(0xFF212328),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFF2F333A)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('END TIME',
                            style: TextStyle(
                                color: const Color(0xFF8A8D92),
                                fontSize: 9.5.sp,
                                fontWeight: FontWeight.w700)),
                        SizedBox(height: 0.5.h),
                        Text(_formatTime(_endTime),
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 15.sp,
                                fontWeight: FontWeight.w700)),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 2.5.h),

          // Days of week
          Text('REPEAT DAYS',
              style: TextStyle(
                  color: const Color(0xFF8A8D92),
                  fontSize: 10.sp,
                  fontWeight: FontWeight.w700)),
          SizedBox(height: 1.h),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [1, 2, 3, 4, 5, 6, 7].map((day) {
              final isSelected = _selectedDays.contains(day);
              return InkWell(
                onTap: () {
                  setState(() {
                    if (isSelected) {
                      _selectedDays.remove(day);
                    } else {
                      _selectedDays.add(day);
                    }
                  });
                },
                child: Container(
                  width: 10.w,
                  height: 10.w,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isSelected ? Colors.white : const Color(0xFF212328),
                    border: Border.all(
                      color: isSelected ? Colors.white : const Color(0xFF2F333A),
                    ),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    dayLabels[day]!,
                    style: TextStyle(
                      color: isSelected ? Colors.black : Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 11.5.sp,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          SizedBox(height: 3.h),

          // Save button
          BouncyTap(
            onTap: _save,
            child: Container(
              width: double.infinity,
              height: 6.h,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                'Save Schedule',
                style: TextStyle(
                  color: Colors.black,
                  fontSize: 13.5.sp,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
