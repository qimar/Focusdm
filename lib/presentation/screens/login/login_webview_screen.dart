import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:go_router/go_router.dart';
import 'package:sizer/sizer.dart';
import '../../../core/utils/app_constants.dart';
import '../../../core/utils/auth_state.dart';

// LoginWebViewScreen
// Full-screen high-performance InAppWebView that handles the Instagram login flow.
class LoginWebViewScreen extends StatefulWidget {
  const LoginWebViewScreen({super.key});

  @override
  State<LoginWebViewScreen> createState() => _LoginWebViewScreenState();
}

class _LoginWebViewScreenState extends State<LoginWebViewScreen> {
  InAppWebViewController? _controller;
  bool _isLoading = true;
  bool _loginDetected = false; // guard against calling logIn() multiple times

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) {
          return;
        }
        if (_controller != null && await _controller!.canGoBack()) {
          await _controller!.goBack();
        } else {
          if (context.mounted) {
            context.pop();
          }
        }
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF0C1014),

        // Minimal top bar with back arrow
        appBar: PreferredSize(
          preferredSize: Size.fromHeight(7.h),
          child: Container(
            decoration: const BoxDecoration(
              color: Color(0xFF0C1014),
              border: Border(
                bottom: BorderSide(color: Color(0xFF2F333A), width: 0.5),
              ),
            ),
            child: SafeArea(
              bottom: false,
              child: SizedBox(
                height: 7.h,
                child: Row(
                  children: [
                    IconButton(
                      icon: Icon(Icons.arrow_back_ios_new_rounded,
                          color: Colors.white, size: 4.5.w),
                      onPressed: () async {
                        if (_controller != null &&
                            await _controller!.canGoBack()) {
                          _controller!.goBack();
                        } else {
                          if (context.mounted) {
                            context.pop();
                          }
                        }
                      },
                    ),
                    Expanded(
                      child: Text(
                        'Sign in with Instagram',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14.sp,
                          fontWeight: FontWeight.w600,
                          letterSpacing: -0.3,
                        ),
                      ),
                    ),
                    SizedBox(width: 11.w),
                  ],
                ),
              ),
            ),
          ),
        ),

        body: Stack(
          children: [
            InAppWebView(
              initialUrlRequest: URLRequest(
                url: WebUri(AppConstants.instagramInboxUrl),
              ),
              initialSettings: InAppWebViewSettings(
                useHybridComposition: true,
                hardwareAcceleration: true,
                offscreenPreRaster: true,
                cacheMode: CacheMode.LOAD_DEFAULT,
                domStorageEnabled: true,
                databaseEnabled: true,
                userAgent: AppConstants.userAgent,
                transparentBackground: true,
              ),
              onWebViewCreated: (controller) {
                _controller = controller;
              },
              onLoadStart: (controller, url) {
                if (mounted) {
                  setState(() => _isLoading = true);
                }
              },
              onLoadStop: (controller, url) {
                if (mounted) {
                  setState(() => _isLoading = false);
                }
                final urlString = url?.toString() ?? '';
                if (!_loginDetected && urlString.contains('instagram.com/direct')) {
                  _loginDetected = true;
                  Future.delayed(const Duration(milliseconds: 300), () {
                    if (mounted) {
                      AuthState.instance.logIn();
                    }
                  });
                }
              },
            ),

            if (_isLoading)
              Container(
                color: Colors.black,
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 1.5,
                      ),
                      SizedBox(height: 2.h),
                      Text(
                        'Loading Instagram…',
                        style: TextStyle(
                          color: const Color(0xFF636366),
                          fontSize: 12.sp,
                          letterSpacing: -0.2,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
