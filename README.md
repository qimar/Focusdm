<div align="center">

# Focus DM

### Distraction Free Direct Messaging for Instagram

[![Flutter](https://img.shields.io/badge/Flutter-02569B?style=for-the-badge&logo=flutter&logoColor=white)](https://flutter.dev)
[![Dart](https://img.shields.io/badge/Dart-0175C2?style=for-the-badge&logo=dart&logoColor=white)](https://dart.dev)
[![InAppWebView](https://img.shields.io/badge/WebView-InAppWebView-303F9F?style=for-the-badge&logo=googlechrome&logoColor=white)](https://inappwebview.dev)
[![Provider](https://img.shields.io/badge/State-Provider-blue?style=for-the-badge&logo=flutter&logoColor=white)](https://pub.dev/packages/provider)
[![CI/CD](https://img.shields.io/badge/Canary-Playwright_CI-45ba4b?style=for-the-badge&logo=playwright&logoColor=white)](.github/workflows/instagram_canary.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg?style=for-the-badge)](LICENSE)

</div>

---

## Overview

Focus DM is a focused mobile productivity client that isolates direct messaging while stripping away infinite feeds, algorithmic reels, explore pages, and notifications. Designed to eliminate doomscrolling, it delivers a clean, high performance chat environment powered by Flutter and an optimized InAppWebView engine.

---

## Key Features

* **Pure Messaging Interface:** Direct access to Instagram direct messages with zero exposure to algorithmic feeds, stories, or reel recommendations.
* **Native Hybrid Composition:** Bypasses texture layer overhead with Chromium offscreen pre-rastering for smooth 60 FPS scrolling without GPU stalls.
* **Zero Flash Script Injection:** Injects DOM mutation scripts at `AT_DOCUMENT_START` before React client hydration to remove UI clutter without screen flashes.
* **Zero Trust URL Allowlist:** Strictly prevents users or links from breaking out into explore, reel, or profile feed pages.
* **Telemetry and Battery Optimization:** Intercepts and drops background tracking telemetry pings (`/logging_client_events`) to conserve battery and data.
* **Focus Schedules and PIN Lock:** Set timed daily focus sessions and lock direct messages behind a custom PIN code.
* **Automated Canary Monitor:** Runs automated Playwright checks every 6 hours via GitHub Actions to detect Instagram web DOM changes before they affect users.

---

## Tech Stack

| Component | Technology |
|---|---|
| **Framework** | Flutter 3.x (Android) |
| **Language** | Dart |
| **WebView Engine** | flutter_inappwebview (Hybrid Composition) |
| **State & Navigation** | Provider, GoRouter |
| **Security** | Zero Trust Request Interceptor, PIN Lock |
| **Monetization** | RevenueCat (In-App Subscriptions) |
| **Canary CI** | Playwright, GitHub Actions, Discord Webhooks |

---

## Architecture

```text
lib/
├── core/
│   ├── router/            # GoRouter declarative navigation
│   ├── services/          # Canary monitor, WebView prewarmer, and notifications
│   ├── theme/             # Instagram matched dark mode palette
│   └── utils/             # Zero trust URL allowlist and authentication state
└── presentation/
    ├── screens/
    │   ├── inbox/         # Optimized hybrid composition WebView screen
    │   ├── lock/          # Custom PIN lock screen
    │   ├── paywall/       # RevenueCat subscription paywall
    │   └── settings/      # Focus schedules, PIN config, and account options
    └── widgets/           # Animated status icons and custom UI controls
```

---

## Engineering Highlights

### Hybrid Composition with Offscreen Pre-Rastering
Standard Flutter WebViews can stutter during rapid scrolling due to GPU texture buffer copy stalls. Focus DM enforces Native Hybrid Composition and sets `offscreenPreRaster: true`, forcing Chromium to pre-rasterize offscreen tiles and delivering 60 FPS scrolling.

### Early Script Injection at Document Start
Modifying social media DOM elements after page render results in visible screen flashes. Focus DM injects minified CSS and JavaScript at `AT_DOCUMENT_START` before the HTML DOM is parsed or React boots up, removing distraction containers before they ever paint to the screen.

---

## Getting Started

```bash
# Clone the repository
git clone https://github.com/qimar/focusdm.git

# Enter project directory
cd focusdm

# Install packages
flutter pub get

# Run on connected device
flutter run
```

---

## License

Distributed under the MIT License. See `LICENSE` for details.
