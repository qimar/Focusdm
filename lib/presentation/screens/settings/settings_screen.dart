import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:sizer/sizer.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import '../../../core/router/app_router.dart';
import '../../../core/services/focus_mode_service.dart';
import '../../../core/services/notification_service.dart';
import '../../../core/services/schedule_service.dart';
import '../../../core/services/app_lock_service.dart';
import '../../../core/services/pro_service.dart';
import '../lock/pin_lock_screen.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/auth_state.dart';
import '../../widgets/animated_dialog.dart';
import '../../widgets/animated_transitions.dart';

// SettingsScreen
// Focus DM app settings.
// Sections: Account · Subscription · About
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  // Colours — matched to Instagram WebView sampled on device
  static const Color _bg           = Color(0xFF0C1014); // Instagram body bg
  static const Color _cardBg       = Color(0xFF212328); // Instagram card surface
  static const Color _dialogBg     = Color(0xFF25292E); // Instagram bottom-sheet / dialog
  static const Color _surface      = Color(0xFF25292E); // Icon/pill container
  static const Color _outline      = Color(0xFF8A8D92); // Muted labels
  static const Color _onSurface    = Color(0xFFA8A8A8); // Secondary text
  // static const Color _emeraldBg    = Color(0xFF16261E);
  // static const Color _emeraldFg    = Color(0xFF86EFAC);
  static const Color _errorColor   = Color(0xFFED4956); // Instagram red
  static const Color _dividerColor = Color(0xFF2F333A); // Instagram divider

  bool _notificationsEnabled = true;

  @override
  void initState() {
    super.initState();
    FocusModeService.instance.addListener(_onFocusServiceChanged);
    ScheduleService.instance.addListener(_onFocusServiceChanged);
    AppLockService.instance.addListener(_onFocusServiceChanged);
    ProService.instance.addListener(_onFocusServiceChanged);
    _loadNotificationPreference();
  }

  Future<void> _loadNotificationPreference() async {
    final enabled = await NotificationService.isEnabled();
    if (mounted) {
      setState(() => _notificationsEnabled = enabled);
    }
  }

  Future<void> _handleNotificationToggle(bool value) async {
    if (value && !ProService.instance.isPro) {
      context.push(AppRoutes.paywall);
      return;
    }
    setState(() => _notificationsEnabled = value);
    await NotificationService.setEnabled(value);
  }

  void _onFocusServiceChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    FocusModeService.instance.removeListener(_onFocusServiceChanged);
    ScheduleService.instance.removeListener(_onFocusServiceChanged);
    AppLockService.instance.removeListener(_onFocusServiceChanged);
    ProService.instance.removeListener(_onFocusServiceChanged);
    super.dispose();
  }

  // Focus Mode Handlers
  Future<void> _handleFocusToggle(bool enable) async {
    if (!enable) {
      // Locked ON: cannot be disabled while active
      return;
    }

    // 1. Verify accessibility permission
    final hasPermission = await FocusModeService.instance.isAccessibilityGranted();
    if (!mounted) return;
    if (!hasPermission) {
      _showAccessibilityRequiredDialog();
      return;
    }

    // 2. Open Time Picker starting from current time
    final now = TimeOfDay.now();
    final pickedTime = await showTimePicker(
      context: context,
      initialTime: now,
      helpText: 'SELECT FOCUS END TIME',
      builder: (context, child) {
        return Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: const ColorScheme.dark(
              primary: Colors.white,
              onPrimary: Colors.black,
              surface: _dialogBg,
              onSurface: Colors.white,
            ),
            dialogTheme: const DialogThemeData(
              backgroundColor: _dialogBg,
            ),
          ),
          child: child!,
        );
      },
    );

    if (pickedTime == null || !mounted) return;

    // Calculate end DateTime
    final nowDt = DateTime.now();
    var endDt = DateTime(
      nowDt.year,
      nowDt.month,
      nowDt.day,
      pickedTime.hour,
      pickedTime.minute,
    );

    // If selected time is earlier than current time today, treat it as tomorrow
    if (endDt.isBefore(nowDt) || endDt.difference(nowDt).inMinutes < 1) {
      endDt = endDt.add(const Duration(days: 1));
    }

    final diff = endDt.difference(nowDt);
    final hours = diff.inHours;
    final minutes = diff.inMinutes % 60;

    // Check Free Tier Duration Limitation (max 30 mins)
    if (!ProService.instance.isDurationAllowed(diff)) {
      _showDurationLimitDialog(diff);
      return;
    }

    String durationText = '';
    if (hours > 0 && minutes > 0) {
      durationText = '$hours hour${hours > 1 ? 's' : ''} and $minutes minute${minutes > 1 ? 's' : ''}';
    } else if (hours > 0) {
      durationText = '$hours hour${hours > 1 ? 's' : ''}';
    } else {
      durationText = '$minutes minute${minutes > 1 ? 's' : ''}';
    }

    // 3. Confirmation Dialog
    _showFocusConfirmationDialog(endDt, durationText);
  }

  void _showAccessibilityRequiredDialog() {
    showAnimatedDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: _dialogBg,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: _dividerColor, width: 0.5),
        ),
        title: const Text(
          'Permission Required',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        ),
        content: Text(
          'To lock the official Instagram app and keep you focused, Focus DM needs Accessibility permission.\n\nTap "Enable" to open Android Settings and turn on Focus DM Accessibility Service.',
          style: TextStyle(color: _onSurface, fontSize: 13.5.sp, height: 1.4),
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
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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

  void _showDurationLimitDialog(Duration requested) {
    final hours = requested.inHours;
    final mins = requested.inMinutes % 60;
    final formatted = hours > 0 ? '${hours}h ${mins}m' : '${mins}m';

    showAnimatedDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: _dialogBg,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: _dividerColor, width: 0.5),
        ),
        title: Row(
          children: [
            Container(
              padding: EdgeInsets.all(2.w),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF16261E),
                border: Border.all(color: const Color(0xFF34D399)),
              ),
              child: Icon(Icons.timer_outlined, color: const Color(0xFF34D399), size: 5.w),
            ),
            SizedBox(width: 3.w),
            const Expanded(
              child: Text(
                'Duration Limit',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        content: Text(
          'Free sessions are capped at 30 minutes (you requested $formatted).\n\nUnlock Focus DM Pro for unlimited multi-hour and workday locks.',
          style: TextStyle(color: _onSurface, fontSize: 13.sp, height: 1.4),
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
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () {
              Navigator.of(context).pop();
              context.push(AppRoutes.paywall);
            },
            child: const Text('Unlock with Pro', style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  void _showFocusConfirmationDialog(DateTime targetEndTime, String durationText) {
    showAnimatedDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        backgroundColor: _dialogBg,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: _dividerColor, width: 0.5),
        ),
        title: const Text(
          'Are you sure?',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
        ),
        content: Text(
          'Your Instagram app will be locked for $durationText and you will only be able to chat using Focus DM. Once the time is over, you will be able to use your Instagram app normally.',
          style: TextStyle(color: _onSurface, fontSize: 13.5.sp, height: 1.4),
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
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () async {
              Navigator.of(context).pop();
              await FocusModeService.instance.startFocusMode(targetEndTime);
            },
            child: const Text('Apply Focus', style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  String _formatTimeOfDay(DateTime? dt) {
    if (dt == null) return '';
    final hour = dt.hour == 0 ? 12 : (dt.hour > 12 ? dt.hour - 12 : dt.hour);
    final minute = dt.minute.toString().padLeft(2, '0');
    final ampm = dt.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $ampm';
  }

  String _formatRemaining(Duration d) {
    if (d <= Duration.zero) return '0m left';
    final h = d.inHours;
    final m = d.inMinutes % 60;
    if (h > 0) return '${h}h ${m}m left';
    return '${m}m left';
  }

  // Logout
  Future<void> _handleLogout() async {
    // 1. Clear Instagram session cookies from the WebView cookie jar
    await CookieManager.instance().deleteAllCookies();
    // 2. Flip auth state — go_router redirect sends user to /login
    await AuthState.instance.logOut();
  }

  void _confirmLogout() {
    showAnimatedDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: _dialogBg,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: _dividerColor, width: 0.5),
        ),
        title: const Text(
          'Log Out?',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        ),
        content: Text(
          FocusModeService.instance.isActive
              ? 'You\'ll need to sign in with Instagram again.\n\nNote: Focus Mode will remain active on this device until ${_formatTimeOfDay(FocusModeService.instance.endTime)}.'
              : 'You\'ll need to sign in with Instagram again.',
          style: TextStyle(color: _onSurface, fontSize: 13.sp, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel', style: TextStyle(color: _onSurface)),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _handleLogout();
            },
            child: const Text('Log Out',
                style: TextStyle(color: _errorColor, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }


  void _showTermsAndPrivacyDialog() {
    showAnimatedDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: _dialogBg,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: _dividerColor, width: 0.5),
        ),
        title: const Text(
          'Terms & Privacy',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Focus DM Privacy Commitment',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14),
              ),
              SizedBox(height: 0.8.h),
              Text(
                '• Focus DM is a focused client for Instagram Direct Messages designed to eliminate algorithmic feeds and reels.\n'
                '• No personal messages, browsing history, or keystrokes are collected, sold, or sent to external servers.\n'
                '• All Instagram authentication is executed directly inside Instagram\'s official web sandbox.\n'
                '• All preferences and sessions remain stored locally on your device.',
                style: TextStyle(color: _onSurface, fontSize: 12.5.sp, height: 1.4),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: _bg,
      child: SafeArea(
        child: ListView(
          padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 1.5.h),
          children: [
            // Header
            FadeSlideEntrance(
              delay: const Duration(milliseconds: 50),
              child: Padding(
                padding: EdgeInsets.only(left: 1.w, top: 0.5.h, bottom: 2.h),
                child: Text(
                  'Settings',
                  style: TextStyle(
                    fontSize: 22.sp,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    letterSpacing: -0.5,
                  ),
                ),
              ),
            ),

            // PRO SUBSCRIPTION BANNER (Shown to Free Users)
            if (!ProService.instance.isPro) ...[
              FadeSlideEntrance(
                delay: const Duration(milliseconds: 80),
                child: BouncyTap(
                  onTap: () => context.push(AppRoutes.paywall),
                  child: Container(
                    margin: EdgeInsets.only(bottom: 2.5.h),
                    padding: EdgeInsets.all(4.w),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF1E232A), Color(0xFF14171C)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 11.w,
                          height: 11.w,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: const Color(0xFF25292E),
                            border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
                          ),
                          child: Icon(Icons.stars_rounded, color: Colors.white, size: 6.w),
                        ),
                        SizedBox(width: 3.5.w),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Flexible(
                                    child: Text(
                                      'Focus DM Pro',
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 14.5.sp,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                  SizedBox(width: 2.w),
                                  Container(
                                    padding: EdgeInsets.symmetric(horizontal: 2.w, vertical: 0.2.h),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      'LIFETIME',
                                      style: TextStyle(
                                        color: Colors.black,
                                        fontSize: 7.5.sp,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(height: 0.3.h),
                              Text(
                                'Unlock recurring schedules, unlimited focus sessions & biometrics.',
                                style: TextStyle(
                                  color: _onSurface,
                                  fontSize: 11.sp,
                                  height: 1.3,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Icon(Icons.arrow_forward_ios_rounded, size: 4.w, color: Colors.white70),
                      ],
                    ),
                  ),
                ),
              ),
            ],

            // SECTION 1: ACCOUNT
            FadeSlideEntrance(
              delay: const Duration(milliseconds: 120),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _sectionLabel('ACCOUNT'),
                  _card([
                    // Connected Instagram account row
                    _paddedRow(
                      padding: EdgeInsets.all(4.w),
                      child: Row(
                        children: [
                          Container(
                            width: 11.w,
                            height: 11.w,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: _surface,
                              border: Border.all(color: _dividerColor),
                            ),
                            child: Icon(Icons.person_rounded,
                                color: _onSurface, size: 5.5.w),
                          ),
                          SizedBox(width: 3.5.w),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Instagram Account',
                                  style: TextStyle(
                                    fontSize: 15.sp,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                                SizedBox(height: 0.3.h),
                                Row(
                                  children: [
                                    Container(
                                      width: 1.8.w,
                                      height: 1.8.w,
                                      decoration: const BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: Color(0xFF34D399),
                                      ),
                                    ),
                                    SizedBox(width: 1.5.w),
                                    Flexible(
                                      child: Text(
                                        'Connected via Instagram Web',
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 11.sp,
                                          color: _onSurface,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    _divider(),
                    // Log Out row
                    InkWell(
                      onTap: _confirmLogout,
                      child: _paddedRow(
                        padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 1.5.h),
                        child: Row(
                          children: [
                            Icon(Icons.logout_rounded, size: 5.w, color: _errorColor),
                            SizedBox(width: 2.5.w),
                            Text(
                              'Log Out',
                              style: TextStyle(
                                fontSize: 15.sp,
                                fontWeight: FontWeight.w500,
                                color: _errorColor,
                              ),
                            ),
                            const Spacer(),
                            Icon(Icons.chevron_right, color: _outline, size: 5.w),
                          ],
                        ),
                      ),
                    ),
                  ]),
                ],
              ),
            ),

            SizedBox(height: 2.5.h),

            // SECTION: FOCUS MODE
            FadeSlideEntrance(
              delay: const Duration(milliseconds: 200),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _sectionLabel('FOCUS MODE'),
                  _card([
                    _paddedRow(
                      padding: EdgeInsets.all(4.w),
                      child: Row(
                        children: [
                          Container(
                            width: 11.w,
                            height: 11.w,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: FocusModeService.instance.isActive ? const Color(0xFF16261E) : _surface,
                              border: Border.all(
                                color: FocusModeService.instance.isActive ? const Color(0xFF34D399) : _dividerColor,
                              ),
                            ),
                            child: Icon(
                              Icons.lock_clock_rounded,
                              color: FocusModeService.instance.isActive ? const Color(0xFF34D399) : _onSurface,
                              size: 5.5.w,
                            ),
                          ),
                          SizedBox(width: 3.5.w),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Focus Mode',
                                  style: TextStyle(
                                    fontSize: 15.sp,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                                SizedBox(height: 0.3.h),
                                Text(
                                  FocusModeService.instance.isActive
                                      ? 'Locked until ${_formatTimeOfDay(FocusModeService.instance.endTime)} • ${_formatRemaining(FocusModeService.instance.remainingDuration)}'
                                      : (ProService.instance.isPro
                                          ? 'Custom durations & unlimited sessions'
                                          : 'Free tier • Max 30 min sessions'),
                                  style: TextStyle(
                                    fontSize: 11.5.sp,
                                    color: FocusModeService.instance.isActive ? const Color(0xFF86EFAC) : _onSurface,
                                    fontWeight: FocusModeService.instance.isActive ? FontWeight.w500 : FontWeight.w400,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Switch.adaptive(
                            value: FocusModeService.instance.isActive,
                            activeThumbColor: Colors.white,
                            activeTrackColor: const Color(0xFF34D399),
                            inactiveThumbColor: Colors.white70,
                            inactiveTrackColor: _dividerColor,
                            onChanged: FocusModeService.instance.isActive ? null : (val) => _handleFocusToggle(val),
                          ),
                        ],
                      ),
                    ),
                    _divider(),
                    // Scheduled Focus Recurring Rules
                    InkWell(
                      onTap: () {
                        if (!ProService.instance.isPro) {
                          context.push(AppRoutes.paywall);
                        } else {
                          context.push(AppRoutes.schedules);
                        }
                      },
                      child: _paddedRow(
                        padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 1.5.h),
                        child: Row(
                          children: [
                            Container(
                              width: 8.5.w,
                              height: 8.5.w,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: _surface,
                              ),
                              child: Icon(Icons.alarm_rounded, color: Colors.white, size: 4.5.w),
                            ),
                            SizedBox(width: 3.5.w),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Flexible(
                                        child: Text(
                                          'Scheduled Focus',
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            fontSize: 14.sp,
                                            fontWeight: FontWeight.w600,
                                            color: AppColors.textPrimary,
                                          ),
                                        ),
                                      ),
                                      if (!ProService.instance.isPro) ...[
                                        SizedBox(width: 2.w),
                                        Container(
                                          padding: EdgeInsets.symmetric(horizontal: 1.8.w, vertical: 0.2.h),
                                          decoration: BoxDecoration(
                                            color: Colors.white,
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: Text(
                                            'PRO',
                                            style: TextStyle(
                                              color: Colors.black,
                                              fontSize: 7.5.sp,
                                              fontWeight: FontWeight.w800,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                  SizedBox(height: 0.2.h),
                                  Text(
                                    !ProService.instance.isPro
                                        ? 'Auto-lock on weekdays or bedtime • Pro'
                                        : (ScheduleService.instance.schedules.isEmpty
                                            ? 'Auto-lock on weekdays or at bedtime'
                                            : '${ScheduleService.instance.schedules.where((s) => s.isEnabled).length} active recurring schedule(s)'),
                                    style: TextStyle(
                                      fontSize: 11.sp,
                                      color: _onSurface,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Icon(Icons.arrow_forward_ios_rounded, size: 4.w, color: _outline),
                          ],
                        ),
                      ),
                    ),
                  ]),
                ],
              ),
            ),

            SizedBox(height: 2.5.h),

            // SECTION: NOTIFICATIONS
            FadeSlideEntrance(
              delay: const Duration(milliseconds: 280),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _sectionLabel('NOTIFICATIONS'),
                  _card([
                    BouncyTap(
                      onTap: !ProService.instance.isPro ? () => context.push(AppRoutes.paywall) : null,
                      child: _paddedRow(
                        padding: EdgeInsets.all(4.w),
                        child: Row(
                          children: [
                            Container(
                              width: 11.w,
                              height: 11.w,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: (ProService.instance.isPro && _notificationsEnabled) ? const Color(0xFF16261E) : _surface,
                                border: Border.all(
                                  color: (ProService.instance.isPro && _notificationsEnabled) ? const Color(0xFF34D399) : _dividerColor,
                                ),
                              ),
                              child: Icon(
                                (ProService.instance.isPro && _notificationsEnabled) ? Icons.notifications_active_rounded : Icons.notifications_off_rounded,
                                color: (ProService.instance.isPro && _notificationsEnabled) ? const Color(0xFF34D399) : _onSurface,
                                size: 5.5.w,
                              ),
                            ),
                            SizedBox(width: 3.5.w),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Flexible(
                                        child: Text(
                                          'Push Notifications',
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            fontSize: 15.sp,
                                            fontWeight: FontWeight.w600,
                                            color: AppColors.textPrimary,
                                          ),
                                        ),
                                      ),
                                      if (!ProService.instance.isPro) ...[
                                        SizedBox(width: 2.w),
                                        Container(
                                          padding: EdgeInsets.symmetric(horizontal: 1.8.w, vertical: 0.2.h),
                                          decoration: BoxDecoration(
                                            color: Colors.white,
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: Text(
                                            'PRO',
                                            style: TextStyle(
                                              color: Colors.black,
                                              fontSize: 7.5.sp,
                                              fontWeight: FontWeight.w800,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                  SizedBox(height: 0.3.h),
                                  Text(
                                    !ProService.instance.isPro
                                        ? 'Direct message alerts • Pro'
                                        : (_notificationsEnabled
                                            ? 'Alerts for new direct messages'
                                            : 'Direct message alerts are muted'),
                                    style: TextStyle(
                                      fontSize: 11.5.sp,
                                      color: _onSurface,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Switch.adaptive(
                              value: ProService.instance.isPro && _notificationsEnabled,
                              activeThumbColor: Colors.white,
                              activeTrackColor: const Color(0xFF34D399),
                              inactiveThumbColor: Colors.white70,
                              inactiveTrackColor: _dividerColor,
                              onChanged: _handleNotificationToggle,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ]),
                ],
              ),
            ),

            SizedBox(height: 2.5.h),

            // SECTION: APP LOCK & PRIVACY
            FadeSlideEntrance(
              delay: const Duration(milliseconds: 320),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _sectionLabel('PRIVACY & SECURITY'),
                  _card([
                    // Passcode toggle / setup row
                    _paddedRow(
                      padding: EdgeInsets.all(4.w),
                      child: Row(
                        children: [
                          Container(
                            width: 11.w,
                            height: 11.w,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: AppLockService.instance.isLockEnabled ? const Color(0xFF16261E) : _surface,
                              border: Border.all(
                                color: AppLockService.instance.isLockEnabled ? const Color(0xFF34D399) : _dividerColor,
                              ),
                            ),
                            child: Icon(
                              Icons.shield_rounded,
                              color: AppLockService.instance.isLockEnabled ? const Color(0xFF34D399) : _onSurface,
                              size: 5.5.w,
                            ),
                          ),
                          SizedBox(width: 3.5.w),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Flexible(
                                      child: Text(
                                        'App Passcode Lock',
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 15.sp,
                                          fontWeight: FontWeight.w600,
                                          color: AppColors.textPrimary,
                                        ),
                                      ),
                                    ),
                                    if (!ProService.instance.isPro) ...[
                                      SizedBox(width: 2.w),
                                      Container(
                                        padding: EdgeInsets.symmetric(horizontal: 1.8.w, vertical: 0.2.h),
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          'PRO',
                                          style: TextStyle(
                                            color: Colors.black,
                                            fontSize: 7.5.sp,
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                                SizedBox(height: 0.3.h),
                                Text(
                                  AppLockService.instance.isLockEnabled
                                      ? 'PIN lock active on app exit'
                                      : 'Require PIN to open Focus DM',
                                  style: TextStyle(
                                    fontSize: 11.5.sp,
                                    color: _onSurface,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Switch.adaptive(
                            value: AppLockService.instance.isLockEnabled,
                            activeThumbColor: Colors.white,
                            activeTrackColor: const Color(0xFF34D399),
                            inactiveThumbColor: Colors.white70,
                            inactiveTrackColor: _dividerColor,
                            onChanged: (enable) async {
                              if (enable) {
                                if (!ProService.instance.isPro) {
                                  context.push(AppRoutes.paywall);
                                  return;
                                }
                                // Open PIN setup screen
                                Navigator.of(context).push(
                                  MaterialPageRoute<bool>(
                                    builder: (_) => const PinLockScreen(isSetupMode: true),
                                  ),
                                );
                              } else {
                                // Confirm disable
                                await AppLockService.instance.disableAppLock();
                              }
                            },
                          ),
                        ],
                      ),
                    ),
                    if (AppLockService.instance.isLockEnabled) ...[
                      _divider(),
                      // Biometric unlock toggle
                      _paddedRow(
                        padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 1.5.h),
                        child: Row(
                          children: [
                            Icon(Icons.fingerprint_rounded, size: 5.5.w, color: Colors.white),
                            SizedBox(width: 3.5.w),
                            Expanded(
                              child: Text(
                                'Unlock with Biometrics (Fingerprint / Face)',
                                style: TextStyle(
                                  fontSize: 13.5.sp,
                                  color: AppColors.textPrimary,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                            Switch.adaptive(
                              value: AppLockService.instance.isBiometricsEnabled,
                              activeThumbColor: Colors.white,
                              activeTrackColor: const Color(0xFF34D399),
                              inactiveThumbColor: Colors.white70,
                              inactiveTrackColor: _dividerColor,
                              onChanged: (val) {
                                AppLockService.instance.setBiometricsEnabled(val);
                              },
                            ),
                          ],
                        ),
                      ),
                      _divider(),
                      // Change PIN
                      InkWell(
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute<bool>(
                              builder: (_) => const PinLockScreen(isSetupMode: true),
                            ),
                          );
                        },
                        child: _paddedRow(
                          padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 1.5.h),
                          child: Row(
                            children: [
                              Text(
                                'Change Passcode',
                                style: TextStyle(fontSize: 14.sp, color: AppColors.textPrimary),
                              ),
                              const Spacer(),
                              Icon(Icons.arrow_forward_ios_rounded, size: 4.w, color: _outline),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ]),
                ],
              ),
            ),

            SizedBox(height: 2.5.h),

            // SECTION 5: ABOUT
            FadeSlideEntrance(
              delay: const Duration(milliseconds: 360),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _sectionLabel('ABOUT'),
                  _card([
                    InkWell(
                      onTap: _showTermsAndPrivacyDialog,
                      child: _paddedRow(
                        padding: EdgeInsets.symmetric(
                            horizontal: 4.w, vertical: 1.5.h),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                'Terms & Privacy',
                                style: TextStyle(
                                    fontSize: 15.sp, color: AppColors.textPrimary),
                              ),
                            ),
                            Icon(Icons.open_in_new_rounded,
                                size: 4.5.w, color: _outline),
                          ],
                        ),
                      ),
                    ),
                  ]),
                ],
              ),
            ),

            SizedBox(height: 4.h),
          ],
        ),
      ),
    );

  
  }

  // Helper Widgets

  Widget _sectionLabel(String text) => Padding(
        padding: EdgeInsets.only(left: 1.w, bottom: 1.h),
        child: Text(
          text,
          style: TextStyle(
            fontSize: 10.5.sp,
            fontWeight: FontWeight.w600,
            letterSpacing: 1.0,
            color: _outline,
          ),
        ),
      );

  Widget _card(List<Widget> children) => Container(
        decoration: BoxDecoration(
          color: _cardBg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _dividerColor, width: 0.5),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(children: children),
      );

  Widget _divider() => Container(height: 0.5, color: _dividerColor);

  Widget _paddedRow({required Widget child, required EdgeInsetsGeometry padding}) =>
      Padding(padding: padding, child: child);

}

