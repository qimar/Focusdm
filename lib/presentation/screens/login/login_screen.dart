import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:sizer/sizer.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../widgets/animated_transitions.dart';
import '../../widgets/custom_animated_icons.dart';

// LoginScreen
// Native welcome/onboarding screen shown to unauthenticated users.
// Tapping "Continue with Instagram" pushes LoginWebViewScreen which handles
// the actual Instagram login flow.
class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0C1014),
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 6.w),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Spacer(flex: 3),

              // Animated App Icon
              FadeSlideEntrance(
                delay: const Duration(milliseconds: 100),
                offset: const Offset(0.0, 0.2),
                child: AnimatedLoginChatGraphic(size: 24.w),
              ),
              SizedBox(height: 2.5.h),

              // Headline
              FadeSlideEntrance(
                delay: const Duration(milliseconds: 200),
                child: Column(
                  children: [
                    Text(
                      'Focus DM',
                      style: AppTextStyles.headlineXl.copyWith(
                        color: Colors.white,
                        letterSpacing: -0.5,
                      ),
                    ),
                    SizedBox(height: 1.h),
                    Text(
                      'Your Instagram DMs.\nNo feed. No reels. Just messages.',
                      textAlign: TextAlign.center,
                      style: AppTextStyles.bodyLg.copyWith(
                        color: const Color(0xFFA8A8A8),
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),

              const Spacer(flex: 4),

              // Feature List
              FadeSlideEntrance(
                delay: const Duration(milliseconds: 320),
                child: _Feature(
                  icon: Icons.block_rounded,
                  text: 'Feed, Reels & Explore completely blocked',
                ),
              ),
              SizedBox(height: 1.8.h),
              FadeSlideEntrance(
                delay: const Duration(milliseconds: 400),
                child: _Feature(
                  icon: Icons.chat_bubble_outline_rounded,
                  text: 'Pure, distraction-free DM inbox',
                ),
              ),
              SizedBox(height: 1.8.h),
              FadeSlideEntrance(
                delay: const Duration(milliseconds: 480),
                child: _Feature(
                  icon: Icons.lock_outline_rounded,
                  text: 'No data stored — uses Instagram\'s own secure login',
                ),
              ),

              const Spacer(flex: 2),

              // CTA
              FadeSlideEntrance(
                delay: const Duration(milliseconds: 560),
                child: BouncyTap(
                  onTap: () => context.push(AppRoutes.loginWebView),
                  child: Container(
                    width: double.infinity,
                    padding: EdgeInsets.symmetric(vertical: 1.8.h),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(width: 2.w),
                        Text(
                          'Continue with Instagram',
                          style: AppTextStyles.bodyLg.copyWith(
                            color: Colors.black,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              SizedBox(height: 2.h),

              // Legal
              FadeSlideEntrance(
                delay: const Duration(milliseconds: 620),
                child: Text(
                  'By continuing you agree to our Terms of Service and Privacy Policy',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.labelSm.copyWith(
                    color: const Color(0xFF737373),
                  ),
                ),
              ),
              SizedBox(height: 3.h),
            ],
          ),
        ),
      ),
    );
  }
}

// Feature Row
class _Feature extends StatelessWidget {
  final IconData icon;
  final String text;

  const _Feature({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 9.w,
          height: 9.w,
          decoration: BoxDecoration(
            color: const Color(0xFF212328),
            borderRadius: BorderRadius.circular(2.2.w),
          ),
          child: Icon(icon, size: 4.5.w, color: Colors.white),
        ),
        SizedBox(width: 3.5.w),
        Expanded(
          child: Padding(
            padding: EdgeInsets.only(top: 0.5.h),
            child: Text(
              text,
              style: TextStyle(
                fontSize: 13.5.sp,
                color: const Color(0xFFA8A8A8),
                height: 1.4,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
