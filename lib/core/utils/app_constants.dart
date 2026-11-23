// App-wide constants
// All magic strings and configuration live here — never hardcoded in widgets.

class AppConstants {
  AppConstants._();

  // App Info
  static const String appName = 'Focus DM';
  static const String appVersion = '1.0.0';

  // Instagram WebView URLs
  // The app embeds Instagram's own mobile web — no private API calls.
  static const String instagramInboxUrl =
      'https://www.instagram.com/direct/inbox/';
  static const String instagramLoginUrl =
      'https://www.instagram.com/accounts/login/';

  // WebView User-Agent
  // Pretend to be Chrome on Android so Instagram serves the full mobile web UI
  // instead of a "use the app" redirect page.
  static const String userAgent =
      'Mozilla/5.0 (Linux; Android 14; Pixel 8) '
      'AppleWebKit/537.36 (KHTML, like Gecko) '
      'Chrome/130.0.0.0 Mobile Safari/537.36';

  // Shared Preferences Keys
  static const String kIsLoggedIn = 'is_logged_in';

  // RevenueCat
  // ⚠️  Replace with your RevenueCat API key from the dashboard.
  static const String revenueCatApiKey = 'YOUR_REVENUECAT_API_KEY';
  static const String entitlementPro = 'pro';
}
