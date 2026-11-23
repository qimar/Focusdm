import 'dart:math';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:sizer/sizer.dart';
import '../../../core/router/app_router.dart';
import '../../../core/services/focus_mode_service.dart';
import '../../widgets/animated_transitions.dart';
import '../../widgets/custom_animated_icons.dart';

class FocusBlockScreen extends StatefulWidget {
  const FocusBlockScreen({super.key});

  @override
  State<FocusBlockScreen> createState() => _FocusBlockScreenState();
}

class _FocusBlockScreenState extends State<FocusBlockScreen> {
  static const Color _bg = Color(0xFF0C1014);
  static const Color _cardBg = Color(0xFF212328);
  static const Color _border = Color(0xFF2F333A);
  static const Color _onSurface = Color(0xFFA8A8A8);

  final List<String> _quotes = const [
    '“Distraction is the enemy of direction. Stay with what matters.”',
    '“You don’t need more time, you just need less distraction.”',
    '“Focus is saying no to what steals your peace.”',
    '“Connect deeply through conversations, not mindless scrolls.”',
    '“One message at a time. Free yourself from the endless loop.”',
  ];

  late final String _currentQuote;

  @override
  void initState() {
    super.initState();
    _currentQuote = _quotes[Random().nextInt(_quotes.length)];
    FocusModeService.instance.addListener(_onServiceUpdate);
  }

  void _onServiceUpdate() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    FocusModeService.instance.removeListener(_onServiceUpdate);
    super.dispose();
  }

  String _formatDuration(Duration duration) {
    if (duration <= Duration.zero) return '00:00:00';
    final hours = duration.inHours.toString().padLeft(2, '0');
    final minutes = (duration.inMinutes % 60).toString().padLeft(2, '0');
    final seconds = (duration.inSeconds % 60).toString().padLeft(2, '0');
    return '$hours:$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    final remaining = FocusModeService.instance.remainingDuration;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          FocusModeService.instance.minimizeToHome();
        }
      },
      child: Scaffold(
        backgroundColor: _bg,
        body: SafeArea(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 6.w),
            child: Column(
              children: [
                // Scrollable center content (prevents overflow on small screens)
                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 3.h),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          FadeSlideEntrance(
                            delay: const Duration(milliseconds: 200),
                            offset: const Offset(0.0, 0.2),
                            child: AnimatedZenLock(size: 46.w),
                          ),
                          SizedBox(height: 2.h),
                          FadeSlideEntrance(
                            delay: const Duration(milliseconds: 300),
                            child: Column(
                              children: [
                                Text(
                                  'Instagram is Locked',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 20.sp,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: -0.5,
                                  ),
                                ),
                                SizedBox(height: 1.h),
                                Text(
                                  'Take a breath. Direct your attention to what truly counts.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: _onSurface,
                                    fontSize: 12.sp,
                                    height: 1.4,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          SizedBox(height: 3.h),

                          // Countdown Timer Box
                          FadeSlideEntrance(
                            delay: const Duration(milliseconds: 400),
                            child: Container(
                              padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
                              decoration: BoxDecoration(
                                color: _cardBg,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: _border),
                              ),
                              child: Column(
                                children: [
                                  Text(
                                    'TIME REMAINING',
                                    style: TextStyle(
                                      color: const Color(0xFF8A8D92),
                                      fontSize: 10.sp,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 1.2,
                                    ),
                                  ),
                                  SizedBox(height: 1.h),
                                  Text(
                                    _formatDuration(remaining),
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 26.sp,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 2.0,
                                      fontFeatures: const [FontFeature.tabularFigures()],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          SizedBox(height: 2.5.h),

                          // Quote Card
                          FadeSlideEntrance(
                            delay: const Duration(milliseconds: 500),
                            child: Container(
                              padding: EdgeInsets.all(4.w),
                              decoration: BoxDecoration(
                                color: const Color(0xFF14171C),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: _border.withValues(alpha: 0.6)),
                              ),
                              child: Text(
                                _currentQuote,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: _onSurface,
                                  fontStyle: FontStyle.italic,
                                  fontSize: 11.5.sp,
                                  height: 1.4,
                                ),
                              ),
                            ),
                          ),
                          SizedBox(height: 3.h),

                          // Bottom Buttons (inside scroll so they never get cut)
                          FadeSlideEntrance(
                            delay: const Duration(milliseconds: 600),
                            child: Column(
                              children: [
                                BouncyTap(
                                  onTap: () {
                                    context.go(AppRoutes.app);
                                  },
                                  child: Container(
                                    width: double.infinity,
                                    height: 6.h,
                                    alignment: Alignment.center,
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      'Open Focus DM',
                                      style: TextStyle(
                                        color: Colors.black,
                                        fontSize: 14.sp,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                ),
                                SizedBox(height: 1.5.h),
                                BouncyTap(
                                  onTap: () {
                                    FocusModeService.instance.minimizeToHome();
                                  },
                                  child: Container(
                                    width: double.infinity,
                                    height: 5.5.h,
                                    alignment: Alignment.center,
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: _border),
                                    ),
                                    child: Text(
                                      'Go Back',
                                      style: TextStyle(
                                        color: _onSurface,
                                        fontSize: 13.5.sp,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
