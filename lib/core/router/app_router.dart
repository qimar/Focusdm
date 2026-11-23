import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../presentation/screens/login/login_screen.dart';
import '../../presentation/screens/login/login_webview_screen.dart';
import '../../presentation/screens/shell/app_shell.dart';
import '../../presentation/screens/focus/focus_block_screen.dart';
import '../../presentation/screens/settings/schedules_screen.dart';
import '../../presentation/screens/paywall/paywall_screen.dart';
import '../utils/auth_state.dart';

// Route path constants
class AppRoutes {
  AppRoutes._();
  static const String login        = '/login';
  static const String loginWebView = '/login/webview';
  static const String app          = '/app';
  static const String paywall      = '/paywall';
  static const String focusBlock   = '/focus-block';
  static const String schedules    = '/schedules';
}

// Custom Page Transition Helpers
CustomTransitionPage<void> _buildSlideTransition({
  required BuildContext context,
  required GoRouterState state,
  required Widget child,
}) {
  return CustomTransitionPage<void>(
    key: state.pageKey,
    child: child,
    transitionDuration: const Duration(milliseconds: 320),
    reverseTransitionDuration: const Duration(milliseconds: 280),
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: Curves.fastOutSlowIn,
        reverseCurve: Curves.fastOutSlowIn,
      );
      return SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(1.0, 0.0),
          end: Offset.zero,
        ).animate(curved),
        child: child,
      );
    },
  );
}

CustomTransitionPage<void> _buildFadeScaleTransition({
  required BuildContext context,
  required GoRouterState state,
  required Widget child,
}) {
  return CustomTransitionPage<void>(
    key: state.pageKey,
    child: child,
    transitionDuration: const Duration(milliseconds: 350),
    reverseTransitionDuration: const Duration(milliseconds: 280),
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      );
      return FadeTransition(
        opacity: Tween<double>(begin: 0.0, end: 1.0).animate(curved),
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.94, end: 1.0).animate(curved),
          child: child,
        ),
      );
    },
  );
}

// Router
// AppShell manages its own tab state via IndexedStack, so we do NOT use
// ShellRoute — just a plain GoRoute for /app.
final GoRouter appRouter = GoRouter(
  initialLocation: AppRoutes.login,

  // Re-evaluates redirect whenever AuthState notifies (login / logout).
  refreshListenable: AuthState.instance,

  redirect: (context, state) {
    final loggedIn = AuthState.instance.isLoggedIn;
    final loc = state.matchedLocation;

    // Login routes are always reachable (includes the WebView login flow).
    if (loc.startsWith('/login')) {
      // Already logged in but stuck on the native login screen → go to app.
      if (loggedIn && loc == AppRoutes.login) {
        return AppRoutes.app;
      }
      return null;
    }

    // Paywall is always reachable (shown before or after login).
    if (loc == AppRoutes.paywall || loc == AppRoutes.focusBlock) {
      return null;
    }

    // Everything else requires an active session.
    if (!loggedIn) {
      return AppRoutes.login;
    }
    return null;
  },

  routes: [
    GoRoute(
      path: AppRoutes.login,
      pageBuilder: (context, state) => _buildFadeScaleTransition(
        context: context,
        state: state,
        child: const LoginScreen(),
      ),
    ),
    GoRoute(
      path: AppRoutes.loginWebView,
      pageBuilder: (context, state) => _buildSlideTransition(
        context: context,
        state: state,
        child: const LoginWebViewScreen(),
      ),
    ),
    GoRoute(
      path: AppRoutes.app,
      pageBuilder: (context, state) => _buildFadeScaleTransition(
        context: context,
        state: state,
        child: const AppShell(),
      ),
    ),
    GoRoute(
      path: AppRoutes.focusBlock,
      pageBuilder: (context, state) => _buildFadeScaleTransition(
        context: context,
        state: state,
        child: const FocusBlockScreen(),
      ),
    ),
    GoRoute(
      path: AppRoutes.schedules,
      pageBuilder: (context, state) => _buildSlideTransition(
        context: context,
        state: state,
        child: const SchedulesScreen(),
      ),
    ),
    GoRoute(
      path: AppRoutes.paywall,
      pageBuilder: (context, state) => _buildSlideTransition(
        context: context,
        state: state,
        child: const PaywallScreen(),
      ),
    ),
  ],
);
