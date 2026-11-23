import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:device_preview/device_preview.dart';
import 'package:sizer/sizer.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'core/router/app_router.dart';
import 'core/services/app_lock_service.dart';
import 'core/services/focus_mode_service.dart';
import 'core/services/notification_service.dart';
import 'core/services/pro_service.dart';
import 'core/services/purchase_service.dart';
import 'core/services/schedule_service.dart';
import 'core/services/webview_prewarmer.dart';
import 'core/theme/app_theme.dart';
import 'core/utils/app_constants.dart';
import 'core/utils/auth_state.dart';
import 'presentation/screens/lock/pin_lock_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Hydrate auth state from disk before the router starts so the initial
  // redirect is correct without a visible flash to the login screen.
  final prefs = await SharedPreferences.getInstance();
  final isLoggedIn = prefs.getBool(AppConstants.kIsLoggedIn) ?? false;
  AuthState.instance.hydrate(isLoggedIn);

  // Initialize and synchronize Focus Mode service
  await FocusModeService.instance.init();
  FocusModeService.instance.onNavigateRequested = (route) {
    if (route == AppRoutes.focusBlock) {
      appRouter.go(AppRoutes.focusBlock);
    }
  };

  // Initialize notifications & background worker
  await NotificationService.instance.init();

  // Initialize Focus Mode recurring schedule service
  await ScheduleService.instance.init();

  // Initialize App Lock & Biometrics
  await AppLockService.instance.init();

  // Initialize Pro Tier State
  await ProService.instance.init();

  // Initialize RevenueCat Purchase Service
  await PurchaseService.instance.init();

  // Pre-warm the Chromium browser engine in background (0ms stall on inbox open)
  WebViewPrewarmer.instance.prewarm();

  runApp(
    DevicePreview(
      enabled: !kReleaseMode,
      builder: (context) => const FocusDmApp(),
    ),
  );
}

class FocusDmApp extends StatefulWidget {
  const FocusDmApp({super.key});

  @override
  State<FocusDmApp> createState() => _FocusDmAppState();
}

class _FocusDmAppState extends State<FocusDmApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    AppLockService.instance.addListener(_onLockStateChanged);
  }

  void _onLockStateChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    AppLockService.instance.removeListener(_onLockStateChanged);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.hidden) {
      // Re-lock when user backgrounds or switches away
      AppLockService.instance.lockApp();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Sizer(
      builder: (context, orientation, deviceType) {
        return MaterialApp.router(
          title: AppConstants.appName,
          theme: AppTheme.dark,
          themeMode: ThemeMode.dark,
          routerConfig: appRouter,
          debugShowCheckedModeBanner: false,
          locale: DevicePreview.locale(context),
          builder: (context, child) {
            final previewChild = DevicePreview.appBuilder(context, child);
            final requiresUnlock = AppLockService.instance.requiresUnlock;
            return Stack(
              children: [
                previewChild,
                if (requiresUnlock)
                  const Positioned.fill(
                    child: PinLockScreen(),
                  ),
              ],
            );
          },
        );
      },
    );
  }
}
