import 'package:flutter/foundation.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

/// Pre-warms Android's libwebviewchromium.so and native graphics pipeline
/// during Flutter app initialization without making duplicate network requests.
class WebViewPrewarmer {
  WebViewPrewarmer._();
  static final WebViewPrewarmer instance = WebViewPrewarmer._();

  HeadlessInAppWebView? _headlessWebView;
  bool _isWarmed = false;

  bool get isWarmed => _isWarmed;

  /// Fire-and-forget pre-warming. Called from [main.dart] during bootstrap.
  Future<void> prewarm() async {
    if (_isWarmed || _headlessWebView != null) {
      return;
    }

    try {
      _headlessWebView = HeadlessInAppWebView(
        initialUrlRequest: URLRequest(
          url: WebUri('about:blank'),
        ),
        initialSettings: InAppWebViewSettings(
          cacheMode: CacheMode.LOAD_DEFAULT,
          domStorageEnabled: true,
          databaseEnabled: true,
          offscreenPreRaster: true,
          hardwareAcceleration: true,
          useHybridComposition: true,
        ),
        onLoadStop: (controller, url) {
          _isWarmed = true;
          debugPrint('🚀 [WebViewPrewarmer] Native Chromium engine primed in RAM');
          // Dispose the headless container after warm-up to free memory
          _headlessWebView?.dispose();
          _headlessWebView = null;
        },
      );

      await _headlessWebView?.run();
    } catch (e) {
      debugPrint('⚠️ [WebViewPrewarmer] Failed to prewarm WebView: $e');
    }
  }

  void dispose() {
    _headlessWebView?.dispose();
    _headlessWebView = null;
  }
}
