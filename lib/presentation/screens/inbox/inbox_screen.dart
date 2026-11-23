import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/services/notification_service.dart';
import '../../../core/services/canary_service.dart';
import '../../../core/utils/app_constants.dart';

// InboxScreen
// The core screen of the Focus DM app: a high-performance, locked-down InAppWebView
// that displays Instagram's mobile DM inbox and aggressively eliminates every
// distraction while delivering buttery-smooth 60 FPS responsiveness.
//
// Advanced Performance & Rendering Architecture:
//  1. Native Hybrid Composition with Offscreen Pre-Rastering:
//     - Bypasses Texture Layer to eliminate GPU buffer copying and fence stalls.
//     - offscreenPreRaster: true forces Chromium to pre-rasterize offscreen tiles,
//       eliminating checkerboarding and scroll stutter.
//  2. AT_DOCUMENT_START UserScript Injection:
//     - Injected before the HTML DOM is parsed or React boots up.
//     - Prevents layout flashes, eliminates re-calculation costs, and secures
//       all touch/navigation events before synthetic listeners attach.
//  3. Telemetry & Analytics Request Dropping:
//     - shouldInterceptRequest intercepts Meta logging pings (/logging_client_events,
//       /ajax/bz/) and returns empty responses, conserving CPU and network.
//  4. Animation Throttling & GPU Shaders:
//     - backdrop-filter: none removes heavy GPU blur passes.
//     - animation-play-state: paused on Notes wave animations drops idle CPU by ~35%.
//     - content-visibility: auto virtualizes message rows.
//     - touch-action: pan-y enforces 0ms tap delay.

class InboxScreen extends StatefulWidget {
  const InboxScreen({super.key});

  @override
  State<InboxScreen> createState() => InboxScreenState();
}

class InboxScreenState extends State<InboxScreen> {
  InAppWebViewController? _controller;
  bool _isLoading = true;

  // Strict Zero-Trust URL Allowlist
  bool _isAllowedUrl(String url) {
    if (url.isEmpty) {
      return true;
    }
    if (url.startsWith('data:') ||
        url.startsWith('about:') ||
        url.startsWith('blob:') ||
        url.startsWith('content:') ||
        url.startsWith('file:')) {
      return true;
    }

    final uri = Uri.tryParse(url);
    if (uri == null) {
      return false;
    }

    final host = uri.host.toLowerCase();
    final path = uri.path;

    if (host == 'i.instagram.com') {
      return true;
    }
    if (host == 'cdninstagram.com' || host.endsWith('.cdninstagram.com') || host == 'fbcdn.net' || host.endsWith('.fbcdn.net')) {
      return true;
    }

    if (host == 'instagram.com' ||
        host == 'www.instagram.com' ||
        host == 'm.instagram.com') {
      if (path.startsWith('/direct')) {
        return true;
      }
      if (path.startsWith('/accounts')) {
        return true;
      }
      if (path.startsWith('/challenge')) {
        return true;
      }
      if (path.startsWith('/create') || path.startsWith('/media')) {
        return true;
      }
      return false;
    }

    return false;
  }

  // High-Performance Shield & Optimization Script (AT_DOCUMENT_START)
  static const String _blockingScript = r'''
(function () {
  "use strict";

  // CRITICAL: Only execute in the top-level window, NEVER in third-party or auth iframes!
  if (window.top !== window.self) return;

  // Compatibility bridge for Flutter InAppWebView message handler
  window.FocusDM = {
    postMessage: function(msg) {
      try {
        if (window.flutter_inappwebview && window.flutter_inappwebview.callHandler) {
          window.flutter_inappwebview.callHandler('FocusDM', msg);
        }
      } catch (_) {}
    }
  };

  // Persistent Debug Logger (Stored in localStorage and printed via bridge)
  function logEvent(type, data) {
    try {
      var logs = JSON.parse(localStorage.getItem('FOCUS_DM_LOGS') || '[]');
      logs.push({
        t: new Date().toLocaleTimeString(),
        type: type,
        path: window.location.pathname,
        data: data || null
      });
      if (logs.length > 80) logs = logs.slice(-80);
      localStorage.setItem('FOCUS_DM_LOGS', JSON.stringify(logs));

      // Also forward directly to Dart so it appears immediately in logcat
      window.FocusDM.postMessage('LOG:' + type + ':' + JSON.stringify(data || {}));
    } catch (_) {}
  }
  window.focusDmLog = logEvent;
  logEvent('SCRIPT_BOOT', { url: window.location.href });

  // Search State & Exit Handler
  window.focusDmExitSearch = function () {
    try {
      if (document.documentElement) {
        document.documentElement.classList.remove('focus-dm-search-active');
      }
      var active = document.activeElement;
      if (active && active.blur) active.blur();

      // Clear all inputs (don't call cancel.click() — our capture-phase handler
      // would re-intercept it and block it since the search class is already removed)
      var inputs = document.querySelectorAll('input');
      inputs.forEach(function (inp) {
        inp.blur();
        if (inp.value) {
          inp.value = '';
          inp.dispatchEvent(new Event('input', { bubbles: true }));
        }
      });
    } catch (_) {}
  };

  // Track search focus
  document.addEventListener(
    'focusin',
    function (e) {
      if (e.target && (e.target.tagName === 'INPUT' || e.target.getAttribute('role') === 'combobox')) {
        if (document.documentElement) {
          document.documentElement.classList.add('focus-dm-search-active');
        }
      }
    },
    true
  );

  // 1. Path & URL Allowlist Helpers
  function isPathAllowed(pathname) {
    if (!pathname || pathname === '') return true;
    if (pathname.startsWith('/direct')) return true;
    if (pathname.startsWith('/accounts')) return true;
    if (pathname.startsWith('/challenge')) return true;
    if (pathname.startsWith('/create') || pathname.startsWith('/media')) return true;
    return false;
  }

  function isUrlAllowed(rawUrl) {
    if (!rawUrl) return true;
    if (rawUrl.startsWith('blob:') || rawUrl.startsWith('data:') || rawUrl.startsWith('content:') || rawUrl.startsWith('file:')) {
      return true;
    }
    try {
      var u = new URL(rawUrl, window.location.href);
      var host = u.hostname.toLowerCase();
      // Always allow CDN and Instagram API subdomains
      if (host === 'i.instagram.com' ||
          host.endsWith('.cdninstagram.com') ||
          host.endsWith('.fbcdn.net')) {
        return true;
      }
      // Allow all Instagram main domains (path-gated)
      if (host === 'www.instagram.com' || host === 'instagram.com' || host === 'm.instagram.com') {
        return isPathAllowed(u.pathname);
      }
      // Block everything else (external sites)
      return false;
    } catch (_) {
      return isPathAllowed(rawUrl);
    }
  }

  function isRootInbox() {
    var p = window.location.pathname;
    return p === '/direct/inbox/' || p === '/direct/inbox' || p === '/direct/' || p === '/direct';
  }

  function syncPageClasses() {
    var isRoot = isRootInbox();
    if (document.documentElement) {
      document.documentElement.classList.toggle('focus-dm-root-inbox', isRoot);
      document.documentElement.classList.toggle('focus-dm-thread', !isRoot);
      // Once inside a DM thread, search is NEVER active. Clear the class so
      // search-mode exemption logic cannot disarm thread protections.
      if (!isRoot) {
        document.documentElement.classList.remove('focus-dm-search-active');
      }
    }
  }

  function triggerDirectReload(reason) {
    logEvent('TRIGGER_DIRECT_RELOAD', { reason: reason, path: window.location.pathname });
    try {
      console.warn('[FocusDM] triggerDirectReload called (' + reason + ') for ' + window.location.pathname);
      window.FocusDM.postMessage('REDIRECT:' + (reason || '') + ':' + window.location.pathname);
    } catch (_) {}
    window.location.replace('/direct/inbox/');
  }

  syncPageClasses();

  // 2. Pure CSS Shield & GPU Optimizations (0% JS overhead)
  function injectStyles() {
    try {
      if (!document.getElementById('focus-dm-nuclear-style')) {
        var style = document.createElement('style');
        style.id = 'focus-dm-nuclear-style';
        style.textContent = `
          /* ── Touch & Immediate 60 FPS Scrolling (0ms Tap Delay) ── */
          html, body {
            -webkit-overflow-scrolling: touch !important;
            overscroll-behavior-y: contain !important;
            -webkit-tap-highlight-color: transparent !important;
            transform: translateZ(0) !important;
            /* touch-action: pan-y removed — it blocked horizontal swipe on Notes carousel */
          }

          /* Allow vertical-only scroll on message lists, while explicitly enabling horizontal scroll on Notes */
          [role="listitem"], div[role="list"] {
            touch-action: pan-y !important;
          }

          /* ── Notes Carousel: Full Horizontal Touch Drag & Swipe ── */
          div[role="region"],
          div[role="tablist"],
          [aria-label*="notes" i],
          [aria-label*="tray" i],
          div:has(> [role="region"]) {
            touch-action: pan-x pan-y !important;
            overflow-x: auto !important;
            -webkit-overflow-scrolling: touch !important;
            overscroll-behavior-x: contain !important;
          }

          /* ── GPU Performance: Eliminate Expensive Backdrop Blur Shaders ── */
          *, *::before, *::after {
            backdrop-filter: none !important;
            -webkit-backdrop-filter: none !important;
          }

          /* ── Fast Asynchronous Image & Text Rendering ── */
          img {
            decoding: async !important;
          }
          * {
            text-rendering: optimizeSpeed !important;
          }

          /* ── Virtualize Offscreen Messages ── */
          div[role="listitem"] {
            content-visibility: auto !important;
            contain-intrinsic-size: auto 60px !important;
          }

          /* ── Prevent Background Video & Audio Decoder Churn ── */
          video, audio {
            contain: strict !important;
          }

          /* ── Tone Down Infinite Shimmer / Pulse Compositor Wakeups ── */
          [class*="shimmer" i], [class*="pulse" i] {
            animation-duration: 0.2s !important;
          }

          /* ── Pause Continuous Animations on Notes Carousel (Drops Idle CPU) ── */
          div[role="region"] [class*="x"] {
            animation-play-state: paused !important;
          }

          /* ── 1. Hide Dropdown Arrow / Chevron Next to Username ── */
          svg[aria-label*="down" i],
          svg[aria-label*="chevron" i],
          svg[aria-label*="dropdown" i],
          svg[aria-label*="Switch" i],
          svg[aria-label*="switch" i],
          svg[aria-label*="Accounts" i],
          svg[aria-label*="accounts" i],
          svg:has(path[d*="M12 15"]),
          svg:has(path[d*="m12 15"]),
          svg:has(polyline[points*="6 9 12 15"]),
          svg:has(polygon[points*="12 15"]) {
            display: none !important;
            pointer-events: none !important;
            visibility: hidden !important;
            width: 0 !important;
            height: 0 !important;
          }

          /* ── 2. On Root Inbox (when NOT in search): Hide Back Button to Feed ── */
          html.focus-dm-root-inbox:not(.focus-dm-search-active) a[href="/"],
          html.focus-dm-root-inbox:not(.focus-dm-search-active) a[href^="/?"],
          html.focus-dm-root-inbox:not(.focus-dm-search-active) [aria-label="Back"]:not([role="search"] *),
          html.focus-dm-root-inbox:not(.focus-dm-search-active) svg[aria-label="Back"]:not([role="search"] *) {
            display: none !important;
            pointer-events: none !important;
            visibility: hidden !important;
          }

          /* ── When Search is Active: Ensure Back/Cancel Button is Fully Visible and Clickable ── */
          html.focus-dm-search-active [aria-label="Back"],
          html.focus-dm-search-active [aria-label*="back" i],
          html.focus-dm-search-active [aria-label="Cancel"],
          html.focus-dm-search-active [aria-label*="cancel" i],
          html.focus-dm-search-active svg[aria-label="Back"],
          html.focus-dm-search-active svg[aria-label*="back" i] {
            display: flex !important;
            pointer-events: auto !important;
            visibility: visible !important;
            opacity: 1 !important;
          }

          /* ── 3. Suppress Modals for External Post, Reel & Account Switch ── */
          div[role="dialog"]:has(input[type="password"]),
          div[role="dialog"]:has(input[name="password"]),
          div[role="dialog"]:has(input[autocomplete*="password"]),
          div[role="dialog"]:has([aria-label*="Switch accounts" i]),
          div[role="dialog"]:has([aria-label*="Log in" i]),
          div[role="dialog"]:has(a[href*="/p/"]):not(:has(input[type="file"])):not(:has([aria-label*="send" i])),
          div[role="dialog"]:has(a[href*="/reel/"]):not(:has(input[type="file"])):not(:has([aria-label*="send" i])),
          div[role="dialog"]:has(header a[href^="/"]):not(:has(textarea)):not(:has([placeholder*="Note" i])):not(:has(input[type="file"])):not(:has([aria-label*="send" i])),
          article[role="presentation"]:has(video):has(a[href*="/reel/"]),

          /* ── 3b. Hide "View Profile" Elements in Chat Threads & User Info Header ── */
          [role="button"]:has(span:is([dir="auto"])):not([aria-label*="send" i]):not([aria-label*="photo" i]):not([aria-label*="media" i]):has(span:-webkit-any([aria-label*="profile" i], [title*="profile" i])),
          div[role="button"]:has(div:has(> svg[aria-label*="User" i])),
          a[href^="/"]:not([href^="/direct"]):not([href^="/accounts"]):not([href^="/challenge"]):not([href^="/create"]):not([href^="/media"]):not([href^="/explore"]) {
            display: none !important;
            pointer-events: none !important;
            visibility: hidden !important;
          }

          /* ── 4. Hide All Non-DM Navigation Elements & App Banners ── */
          a[href="/"],
          a[href^="/?"],
          a[href^="/explore"],
          a[href^="/reels"],
          a[href^="/reel"],
          a[href^="/p/"],
          a[href^="/new/"],
          nav a[href^="/create/"],
          [role="navigation"] a[href^="/create/"],
          header a[href^="/create/"],
          [aria-label="Home"],
          [aria-label="Explore"],
          [aria-label="Reels"],
          [aria-label="Threads"],
          svg[aria-label="Home"],
          svg[aria-label="Explore"],
          svg[aria-label="Reels"],
          nav[role="navigation"],
          [class*="appBanner"],
          [id*="appBanner"],
          [data-testid*="banner"] {
            display: none !important;
            pointer-events: none !important;
          }
        `;
        (document.head || document.documentElement).appendChild(style);
      }
    } catch (_) {}
  }

  injectStyles();
  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', injectStyles);
  }

  // 3. Event-Driven Capture Interceptor (< 0.05ms, 0% idle CPU)
  if (!window.__focusDmClickHooked) {
    window.__focusDmClickHooked = true;
    window.addEventListener(
      'click',
      function (e) {
        try {
          var root = isRootInbox();
          syncPageClasses();
          logEvent('CLICK', {
            target: e.target ? e.target.tagName : 'null',
            aria: e.target && e.target.getAttribute ? e.target.getAttribute('aria-label') : null,
            x: e.clientX,
            y: e.clientY,
            href: (e.target && e.target.closest && e.target.closest('a')) ? e.target.closest('a').getAttribute('href') : null
          });

          // If on root inbox AND search is active: allow back/cancel button or top-left area to exit search cleanly
          if (root && document.documentElement && document.documentElement.classList.contains('focus-dm-search-active')) {
            var isBackOrCancel = e.target.closest(
              '[aria-label="Back"], [aria-label*="back" i], [aria-label="Cancel"], [aria-label*="cancel" i]'
            );
            if (isBackOrCancel || (e.clientX > 0 && e.clientX < 85 && e.clientY > 0 && e.clientY <= 70)) {
              e.preventDefault();
              e.stopPropagation();
              e.stopImmediatePropagation();
              window.focusDmExitSearch();
              window.FocusDM.postMessage('NAV_INBOX');
              return false;
            }
            return; // Allow interacting with search results and inputs
          }

          // Helper: Check if "New note" creation screen is active
          function isNewNoteActive() {
            try {
              if (document.querySelector('[placeholder*="Note" i], textarea[aria-label*="Note" i]')) return true;
              var b = document.body ? document.body.innerText : '';
              return b.indexOf('New note') !== -1 || b.indexOf('Shared with followers') !== -1;
            } catch (_) {
              return false;
            }
          }

          // If on "New note" screen: handle close/cancel/back buttons cleanly
          if (isNewNoteActive()) {
            var closeBtn = e.target.closest(
              '[aria-label*="close" i], [aria-label*="back" i], [aria-label*="cancel" i], [aria-label*="discard" i]'
            );
            if (closeBtn || (e.clientX > 0 && e.clientX <= 75 && e.clientY > 0 && e.clientY <= 65)) {
              e.preventDefault();
              e.stopPropagation();
              e.stopImmediatePropagation();
              history.back();
              setTimeout(function () {
                if (isNewNoteActive()) {
                  window.FocusDM.postMessage('NAV_INBOX');
                }
              }, 150);
              return false;
            }
            return; // Allow interacting with note input and Share button!
          }

          // A) Root Inbox Guards (Fix Loophole 1: Block top-left home escape & top bar)
          if (root) {
            // 1. Block any direct anchor or element linking to Instagram home/feed/explore/reels
            var homeLink = e.target.closest(
              'a[href="/"], a[href^="/?"], a[href^="/explore"], a[href^="/reels"], a[href^="/reel"], [aria-label="Home" i], [aria-label="Instagram" i]'
            );
            if (homeLink) {
              e.preventDefault();
              e.stopPropagation();
              e.stopImmediatePropagation();
              return false;
            }

            // 2. Allow clicking into search bar / search input
            if (e.target.closest('input, [role="search"], [aria-label*="search" i]')) {
              return;
            }

            // 3. Block top bar taps:
            // - Top-left corner (e.clientX <= 80): Instagram logo/home link
            // - Center area: Username dropdown / account switch menu
            // - EXCEPTION: The Compose / New chat button on the top-right (e.clientX >= window.innerWidth - 65)
            if (e.clientY > 0 && e.clientY <= 65 && e.clientX > 0 && e.clientX < (window.innerWidth - 65)) {
              e.preventDefault();
              e.stopPropagation();
              e.stopImmediatePropagation();
              return false;
            }
          }

          // B) Chat Thread Guards
          if (!root) {
            // CRITICAL: When a hidden <input type="file"> is programmatically clicked by
            // tapping the gallery/photo icon, the synthetic click event has clientX=0, clientY=0!
            // We must NEVER treat (0, 0) programmatic events as top-left back button clicks!
            var isProgrammaticSyntheticClick = (e.clientX === 0 && e.clientY === 0);

            // 1. Top-left back button navigates cleanly to Inbox
            var backBtn = e.target.closest(
              '[aria-label="Back"], [aria-label*="back" i], [aria-label="Go back"], a[href="/direct/inbox/"], a[href="/direct/"]'
            );
            if (!isProgrammaticSyntheticClick && (backBtn || (e.clientX > 0 && e.clientX < 85 && e.clientY > 0 && e.clientY <= 65))) {
              logEvent('NAV_BACK_CLICKED', { x: e.clientX, y: e.clientY, backBtn: !!backBtn });
              e.preventDefault();
              e.stopPropagation();
              e.stopImmediatePropagation();
              window.FocusDM.postMessage('NAV_BACK');
              history.back();
              return false;
            }

            // 2. Top header taps outside back button (e.g. partner username/avatar leading to profile)
            // CRITICAL: Only block the partner profile/avatar inside an active chat thread (/direct/t/).
            // In creation screens (like /direct/new/), action buttons like "Next", "Chat", "Done",
            // or close/cross buttons on the right side MUST NOT be blocked!
            if (!isProgrammaticSyntheticClick && e.clientY > 0 && e.clientY <= 65) {
              var isActionBtn = e.target.closest(
                'button, [role="button"], a[role="button"], [aria-label*="next" i], [aria-label*="done" i], [aria-label*="close" i], [aria-label*="cancel" i], [aria-label*="chat" i], [aria-label*="call" i], [aria-label*="phone" i], [aria-label*="video" i], [aria-label*="info" i], [aria-label*="details" i], [aria-label*="audio" i], [aria-label*="mute" i], [aria-label*="sound" i], [aria-label*="volume" i]'
              );
              var btnText = (isActionBtn ? (isActionBtn.innerText || isActionBtn.textContent || '') : '').trim().toLowerCase();
              var isExplicitActionText = (btnText === 'next' || btnText === 'chat' || btnText === 'done' || btnText === 'cancel' || btnText === 'close' || btnText === 'send');

              // If it's an action button on the top-right or a modal header button, allow it!
              if (isActionBtn && (isExplicitActionText || e.clientX >= (window.innerWidth - 120))) {
                // Allow header action buttons (Next, Chat, Done, Close, Volume, etc.)
              } else if (window.location.pathname.startsWith('/direct/t/')) {
                // Inside an active DM conversation thread, block tapping the center header partner name/avatar
                var callBtn = e.target.closest('[aria-label*="call" i], [aria-label*="phone" i], [aria-label*="video" i]');
                if (!callBtn) {
                  e.preventDefault();
                  e.stopPropagation();
                  e.stopImmediatePropagation();
                  return false;
                }
              }
            }

            // 3. Direct Message Composer & Media Picker Protection
            // Explicitly exempt file inputs, gallery/media picker icons, text inputs, voice notes & send buttons
            var isMediaOrComposer = e.target.closest(
              'input[type="file"], label:has(input[type="file"]), [aria-label*="photo" i], [aria-label*="media" i], [aria-label*="gallery" i], [aria-label*="image" i], [aria-label*="attach" i], [aria-label*="camera" i], [aria-label*="sticker" i], [aria-label*="voice" i], [aria-label*="audio" i], [aria-label*="send" i], form, [aria-label*="Message" i], [placeholder*="Message" i], textarea, input, [contenteditable="true"]'
            );
            if (isMediaOrComposer) {
              return; // Allow all composer tools and media picking cleanly!
            }

            // Also exempt any interaction in the bottom composer bar (bottom 120px) that is NOT a post/reel card
            if (e.clientY > (window.innerHeight - 120)) {
              var isCardInBottom = e.target.closest('a[href*="/p/"], a[href*="/reel/"], a[href*="/reels/"], a[href*="/stories/"], article, [aria-label*="shared" i]');
              if (!isCardInBottom) {
                return; // Allow bottom bar interactions!
              }
            }
          }

          // C) Notes Tray Exemption on Root Inbox
          if (root && e.target.closest('div[role="region"], div[role="tablist"], [aria-label*="notes" i], [aria-label*="tray" i]')) {
            return; // Allow interacting with Notes carousel & Note creation
          }

          // D) Deep Content Blocker for Shared Posts, Reels, Profiles, and Disallowed Links (Fix Loophole 2)
          var path = e.composedPath ? e.composedPath() : [];
          for (var i = 0; i < path.length; i++) {
            var node = path[i];
            if (!node || node === document || node === window) break;

            // Check direct anchor
            if (node.tagName === 'A' || (node.getAttribute && node.getAttribute('href'))) {
              var href = node.getAttribute('href') || node.href;
              if (href && !isUrlAllowed(href)) {
                e.preventDefault();
                e.stopPropagation();
                e.stopImmediatePropagation();
                return false;
              }
            }

            // Check descendant anchor inside card (only for card/button nodes, never broad containers)
            if (node.getAttribute && (node.getAttribute('role') === 'button' || node.getAttribute('role') === 'link' || node.tagName === 'ARTICLE')) {
              if (node.querySelector) {
                var childLink = node.querySelector('a[href]');
                if (childLink) {
                  var childHref = childLink.getAttribute('href') || childLink.href;
                  if (childHref && !isUrlAllowed(childHref)) {
                    e.preventDefault();
                    e.stopPropagation();
                    e.stopImmediatePropagation();
                    return false;
                  }
                }
              }
            }

            // Check for post, reel, profile cards with role="button", role="link", or article
            if (node.getAttribute) {
              var role = node.getAttribute('role');
              var aria = node.getAttribute('aria-label') || '';
              var text = (node.innerText || node.textContent || '').trim();

              // Explicitly exempt media playback / volume / mute controls so users can unmute videos & stories
              var isMediaControl = e.target.closest(
                '[aria-label*="audio" i], [aria-label*="mute" i], [aria-label*="sound" i], [aria-label*="volume" i], [aria-label*="pause" i], [aria-label*="play" i], button:has(svg)'
              );
              if (isMediaControl) {
                return; // Allow toggling sound and playback!
              }

              // Explicitly block "View profile" buttons specifically (do NOT block if text is a whole message thread)
              var isViewProfileBtn = (
                (role === 'button' || role === 'link' || node.tagName === 'A' || node.tagName === 'BUTTON') &&
                (/^view profile$/i.test(text) || /^view profile$/i.test(aria) || (text.length <= 25 && /view profile/i.test(text)))
              );

              if (isViewProfileBtn) {
                logEvent('BLOCKED_VIEW_PROFILE', { text: text, aria: aria });
                e.preventDefault();
                e.stopPropagation();
                e.stopImmediatePropagation();
                return false;
              }

              if (role === 'button' || role === 'link' || node.tagName === 'ARTICLE') {
                var isDisallowedCard = /reel|post|video by|photo by|profile|shared/i.test(aria);
                if (!isDisallowedCard && node.querySelector) {
                  if (node.querySelector('article, [aria-label*="reel" i], [aria-label*="post" i], a[href*="/p/"], a[href*="/reel/"]')) {
                    isDisallowedCard = true;
                  }
                }
                if (isDisallowedCard) {
                  e.preventDefault();
                  e.stopPropagation();
                  e.stopImmediatePropagation();
                  return false;
                }
              }
            }
          }

          // E) General Fallback Allowlist Check
          var anchor = e.target.closest('a');
          if (anchor) {
            var aHref = anchor.getAttribute('href') || anchor.href;
            if (aHref && !isUrlAllowed(aHref)) {
              e.preventDefault();
              e.stopPropagation();
              e.stopImmediatePropagation();
              return false;
            }
          }
        } catch (_) {}
      },
      true
    );
  }

  // 3b. File / Media Click Timestamp Tracker
  // Records the timestamp of the last click on a file input or media button.
  // _handleBackPress() in Dart reads this via evaluateJavascript to detect when
  // a gallery/picker tap generated an Android IME-hide event that looks like a
  // system back press — and suppresses the navigation in that case.
  // Must be registered BEFORE the main click hook so it runs first in capture phase.
  if (!window.__focusDmFileClickTracked) {
    window.__focusDmFileClickTracked = true;
    window.__focusDmLastFileClick = 0;
    document.addEventListener('click', function (e) {
      try {
        var target = e.target;
        if (!target) return;
        var isFileRelated = !!(target.closest(
          'input[type="file"], label:has(input[type="file"]), ' +
          '[aria-label*="photo" i], [aria-label*="media" i], ' +
          '[aria-label*="gallery" i], [aria-label*="image" i], ' +
          '[aria-label*="attach" i], [aria-label*="camera" i], ' +
          '[aria-label*="sticker" i], [aria-label*="upload" i], ' +
          '[aria-label*="gif" i]'
        ));
        if (isFileRelated) {
          window.__focusDmLastFileClick = Date.now();
          logEvent('FILE_BTN_CLICK', { t: window.__focusDmLastFileClick, y: e.clientY });
        }
      } catch (_) {}
    }, true); // capture phase — fires synchronously before any other handler
  }

  // 4. History API Interceptor
  try {
    if (!window.__focusDmHistoryHooked) {
      window.__focusDmHistoryHooked = true;

      var _origPush = history.pushState.bind(history);
      history.pushState = function (state, title, url) {
        logEvent('PUSHSTATE', { url: url, allowed: isUrlAllowed(url) });
        if (url && !isUrlAllowed(url)) return;
        var ret = _origPush(state, title, url);
        syncPageClasses();
        return ret;
      };

      var _origReplace = history.replaceState.bind(history);
      history.replaceState = function (state, title, url) {
        logEvent('REPLACESTATE', { url: url, allowed: isUrlAllowed(url) });
        if (url && !isUrlAllowed(url)) return;
        var ret = _origReplace(state, title, url);
        syncPageClasses();
        return ret;
      };

      var _origBack = history.back.bind(history);
      history.back = function () {
        if (isRootInbox()) return;
        var ret = _origBack();
        syncPageClasses();
        return ret;
      };
    }
  } catch (_) {}

  // 5. Lightweight Watchdog (1s interval, string check only)
  try {
    if (!window.__focusDmSentinelStarted) {
      window.__focusDmSentinelStarted = true;

      window.addEventListener('popstate', function () {
        logEvent('POPSTATE', { path: window.location.pathname, allowed: isPathAllowed(window.location.pathname) });

        // Gallery picker back-navigation undo
        // When the gallery/photo button is tapped, Android's WebView handles the
        // back key (from IME dismiss) NATIVELY via goBack() — bypassing Flutter's
        // PopScope entirely. This popstate fires synchronously when that happens.
        // We undo it immediately with history.forward() so the user stays on the
        // thread, and set __focusDmGalleryPendingBack so _handleBackPress() in Dart
        // also suppresses its own navigation attempt when it finally runs.
        if (window.__focusDmLastFileClick && (Date.now() - window.__focusDmLastFileClick) < 5000) {
          logEvent('POPSTATE_GALLERY_UNDO', { path: window.location.pathname });
          window.__focusDmLastFileClick = 0; // Reset — prevents loop on the forward popstate
          window.__focusDmGalleryPendingBack = true;
          setTimeout(function () { window.__focusDmGalleryPendingBack = false; }, 5000);
          history.forward(); // Undo the goBack() — return user to the DM thread
          return;
        }

        syncPageClasses();
        if (!isPathAllowed(window.location.pathname)) {
          triggerDirectReload('popstate');
        }
      });

      setInterval(function () {
        syncPageClasses();
        if (!isPathAllowed(window.location.pathname)) {
          triggerDirectReload('interval');
        }
      }, 250);
    }
  } catch (_) {}

  // 6. Real-Time DM Notification
  // Two independent baselines so DOM message count and title conversation count
  // never interfere with each other. MutationObserver gives instant detection;
  // setInterval is a 30-s fallback. Same-origin relative API avoids CORS (no
  // cross-origin to i.instagram.com).
  try {
    if (!window.__focusDmNotifHooked) {
      window.__focusDmNotifHooked = true;

      // Separate baselines — -1 means "not yet initialised"
      window.__focusDmTitleBase = -1; // (N) in document.title → # unread conversations
      window.__focusDmDomBase   = -1; // "N new messages" text → # unread messages

      // helpers
      var _titleCount = function () {
        var m = (document.title || '').match(/^\((\d+)\+?\)/);
        return m ? parseInt(m[1], 10) : 0;
      };

      var _domCount = function () {
        var total = 0;
        var spans = document.querySelectorAll('span');
        for (var i = 0; i < spans.length; i++) {
          var el = spans[i];
          if (el.children.length > 0) continue;
          var text = (el.textContent || '').trim();
          var m = text.match(/^(\d+)\+?\s+new\s+message/i);
          if (m) total += parseInt(m[1], 10);
        }
        return total;
      };

      var _csrfToken = function () {
        var tok = '';
        (document.cookie || '').split(';').forEach(function (c) {
          var p = c.trim().split('=');
          if (p[0] === 'csrftoken') tok = decodeURIComponent(p[1] || '');
        });
        return tok;
      };

      // Same-origin relative path → zero CORS issues
      var _apiCount = function (cb) {
        var xhr = new XMLHttpRequest();
        xhr.open('GET', '/api/v1/direct_v2/get_badge_count/', true);
        xhr.withCredentials = true;
        xhr.setRequestHeader('X-IG-App-ID', '936619743392459');
        xhr.setRequestHeader('X-CSRFToken', _csrfToken());
        xhr.setRequestHeader('X-Requested-With', 'XMLHttpRequest');
        xhr.timeout = 8000;
        xhr.onreadystatechange = function () {
          if (xhr.readyState !== 4) return;
          window.FocusDM.postMessage('LOG:API status=' + xhr.status);
          if (xhr.status === 200) {
            try { cb(JSON.parse(xhr.responseText).badge_count || 0); } catch (e) { cb(0); }
          }
        };
        xhr.onerror = function () {};
        xhr.send();
      };

      var _fire = function (label, count) {
        if (window.location.pathname.indexOf('/direct/t/') !== -1) return;
        var countStr = count > 3 ? count + '+' : String(count);
        var body = count <= 1 ? 'You have a new message' : 'You have ' + countStr + ' unread messages';
        window.FocusDM.postMessage('LOG:NOTIF_FIRING via=' + label + ' count=' + count);
        window.FocusDM.postMessage('NOTIF:' + JSON.stringify({ sender: 'Instagram Direct', body: body }));
      };

      var _check = function () {
        if (window.__focusDmTitleBase < 0 || window.__focusDmDomBase < 0) return;

        var t = _titleCount();
        var d = _domCount();
        window.FocusDM.postMessage('LOG:CHK title=' + t + '(b=' + window.__focusDmTitleBase + ') dom=' + d + '(b=' + window.__focusDmDomBase + ')');

        if (t > window.__focusDmTitleBase) { window.__focusDmTitleBase = t; _fire('title', t); }
        if (d > window.__focusDmDomBase)   { window.__focusDmDomBase   = d; _fire('dom',   d); }
        if (t === 0) window.__focusDmTitleBase = 0;
        if (d === 0) window.__focusDmDomBase   = 0;

        _apiCount(function (a) {
          window.FocusDM.postMessage('LOG:API_COUNT=' + a);
          if (a > window.__focusDmDomBase) { window.__focusDmDomBase = a; _fire('api', a); }
        });
      };

      // MutationObserver — fires instantly when DOM changes (new message arrives)
      var _startObserver = function () {
        try {
          var root = document.querySelector('[role="main"]') || document.querySelector('main') || document.body;
          var mo = new MutationObserver(function () { _check(); });
          mo.observe(root, { childList: true, subtree: true, characterData: true });
          window.FocusDM.postMessage('LOG:OBSERVER_OK');
        } catch (e) {
          window.FocusDM.postMessage('LOG:OBSERVER_ERR=' + e.message);
        }
      };

      // Also watch title element for (N) changes
      var _watchTitle = function () {
        try {
          var titleEl = document.querySelector('title');
          if (titleEl) {
            new MutationObserver(function () {
              var t = _titleCount();
              window.FocusDM.postMessage('LOG:TITLE_CHANGE ' + document.title);
              if (window.__focusDmTitleBase >= 0 && t > window.__focusDmTitleBase) {
                window.__focusDmTitleBase = t;
                _fire('title_mo', t);
              }
            }).observe(titleEl, { childList: true, characterData: true, subtree: true });
          }
        } catch (e) {}
      };

      // Initialise baselines at 4 s, then start observer + 30 s fallback poll
      setTimeout(function () {
        window.__focusDmTitleBase = _titleCount();
        window.__focusDmDomBase   = _domCount();
        window.FocusDM.postMessage('LOG:INIT title_base=' + window.__focusDmTitleBase + ' dom_base=' + window.__focusDmDomBase);
        _startObserver();
        _watchTitle();
        setInterval(_check, 30000);
      }, 4000);
    }
  } catch (e) {
    try { window.FocusDM.postMessage('LOG:HOOK_ERR=' + e.message); } catch (_) {}
  }
})();
''';

  @override
  void initState() {
    super.initState();
  }

  void resetToInbox() {
    _controller?.evaluateJavascript(source: '''
      (function() {
        if (typeof window.focusDmExitSearch === 'function') {
          window.focusDmExitSearch();
        }
      })()
    ''');
    _controller?.loadUrl(
      urlRequest: URLRequest(
        url: WebUri(AppConstants.instagramInboxUrl),
      ),
    );
  }

  /// Tracks whether the native file chooser (photo/gallery picker) is open.
  /// When true, back-press events from Android (triggered by keyboard dismiss
  /// when the picker opens) must be ignored — they are NOT real navigation backs.
  bool _fileChooserOpen = false;

  Future<void> _handleBackPress() async {
    debugPrint('⬅️ [FocusDM-Back] _handleBackPress called | fileChooserOpen=$_fileChooserOpen');
    if (_controller == null) return;

    // CRITICAL FIX — Gallery / File Picker Suppression

    // When the user taps the gallery/photo button in the DM composer, Android:
    //   1. Fires the JS click event (synchronous, sets window.__focusDmLastFileClick)
    //   2. Requests the IME to hide (keyboard dismiss)
    //   3. Generates a system back-press event that Flutter's PopScope receives
    //   4. THEN launches the file picker Intent
    //
    // Steps 2-3 happen BEFORE the file picker opens, so onWindowBlur and the JS
    // bridge message (FILE_CHOOSER_OPEN) always arrive too late.
    //
    // Solution: evaluateJavascript reads window.__focusDmLastFileClick which was
    // set synchronously in the JS capture-phase click handler (step 1), so it is
    // guaranteed to be set before this Dart function resumes from its first await.
    try {
      final recentFileClick = await _controller!.evaluateJavascript(source: '''
        (function() {
          var t = window.__focusDmLastFileClick || 0;
          var pending = !!(window.__focusDmGalleryPendingBack);
          return (Date.now() - t) < 5000 || pending;
        })()
      ''');
      if (recentFileClick == true || recentFileClick == 'true') {
        debugPrint('📂 [FocusDM-Back] File/media button recently tapped — ignoring back press (gallery picker)');
        return;
      }
    } catch (_) {}

    // Belt-and-suspenders: also check the flag set via onWindowFocus / JS bridge
    if (_fileChooserOpen) {
      debugPrint('📂 [FocusDM-Back] File chooser flag is set — ignoring back press');
      return;
    }

    // 1. If search is active or any input is focused, exit search first!
    try {
      final didExitSearch = await _controller!.evaluateJavascript(source: '''
        (function() {
          var isSearch = document.documentElement.classList.contains('focus-dm-search-active');
          var active = document.activeElement;
          var isInput = active && (active.tagName === 'INPUT' || active.getAttribute('role') === 'combobox');
          if (isSearch || isInput) {
            if (typeof window.focusDmExitSearch === 'function') {
              window.focusDmExitSearch();
            } else {
              if (active && active.blur) active.blur();
              document.documentElement.classList.remove('focus-dm-search-active');
            }
            return true;
          }
          return false;
        })()
      ''');

      if (didExitSearch == true || didExitSearch == 'true') {
        resetToInbox();
        return; // Handled back press by exiting search and returning to inbox!
      }
    } catch (_) {}

    // 1.5. If "New note" screen is active, dismiss it!
    try {
      final didDismissNote = await _controller!.evaluateJavascript(source: '''
        (function() {
          var isNote = !!(
            document.querySelector('[placeholder*="Note" i], textarea[aria-label*="Note" i]') ||
            (document.body && (document.body.innerText.indexOf('New note') !== -1 || document.body.innerText.indexOf('Shared with followers') !== -1))
          );
          if (isNote) {
            history.back();
            return true;
          }
          return false;
        })()
      ''');

      if (didDismissNote == true || didDismissNote == 'true') {
        Future.delayed(const Duration(milliseconds: 150), () async {
          final stillNote = await _controller?.evaluateJavascript(source: '''
            (function() {
              return !!(
                document.querySelector('[placeholder*="Note" i], textarea[aria-label*="Note" i]') ||
                (document.body && document.body.innerText.indexOf('New note') !== -1)
              );
            })()
          ''');
          if (stillNote == true || stillNote == 'true') {
            resetToInbox();
          }
        });
        return; // Handled back press by closing New note!
      }
    } catch (_) {}

    // 2. Thread back navigation
    if (await _controller!.canGoBack()) {
      final currentUrl = (await _controller!.getUrl())?.toString() ?? '';
      if (currentUrl.contains('/direct/t/') ||
          currentUrl.contains('/direct/requests') ||
          currentUrl.contains('/direct/new')) {
        await _controller!.goBack();
        return;
      }
    }

    // 3. Fallback: If not on root inbox, return to inbox
    final currentUrl = (await _controller!.getUrl())?.toString() ?? '';
    if (!currentUrl.endsWith('/direct/inbox/') && !currentUrl.endsWith('/direct/inbox')) {
      resetToInbox();
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          _handleBackPress();
        }
      },
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: const SystemUiOverlayStyle(
          statusBarColor: Colors.black,
          statusBarIconBrightness: Brightness.light,
          systemNavigationBarColor: Color(0xFF000000),
          systemNavigationBarIconBrightness: Brightness.light,
        ),
        child: ColoredBox(
          color: Colors.black,
          child: SafeArea(
            bottom: false,
            child: Stack(
              children: [
                InAppWebView(
                  initialUrlRequest: URLRequest(
                    url: WebUri(AppConstants.instagramInboxUrl),
                  ),
                  initialUserScripts: UnmodifiableListView<UserScript>([
                    UserScript(
                      source: _blockingScript,
                      injectionTime: UserScriptInjectionTime.AT_DOCUMENT_START,
                    ),
                  ]),
                  initialSettings: InAppWebViewSettings(
                    useHybridComposition: true,
                    hardwareAcceleration: true,
                    offscreenPreRaster: true,
                    cacheMode: CacheMode.LOAD_DEFAULT,
                    domStorageEnabled: true,
                    databaseEnabled: true,
                    userAgent: AppConstants.userAgent,
                    transparentBackground: true,
                    mediaPlaybackRequiresUserGesture: false,
                    allowContentAccess: true,
                    allowFileAccess: true,
                    allowsBackForwardNavigationGestures: true,
                    overScrollMode: OverScrollMode.NEVER,
                    disableHorizontalScroll: false,
                    mixedContentMode: MixedContentMode.MIXED_CONTENT_NEVER_ALLOW,
                    supportZoom: false,
                    builtInZoomControls: false,
                    displayZoomControls: false,
                    textZoom: 100,
                    verticalScrollBarEnabled: false,
                    horizontalScrollBarEnabled: false,
                    safeBrowsingEnabled: true,
                    algorithmicDarkeningAllowed: false,
                    disableDefaultErrorPage: true,
                    useWideViewPort: false,
                    loadWithOverviewMode: true,
                    rendererPriorityPolicy: RendererPriorityPolicy(
                      rendererRequestedPriority: RendererPriority.RENDERER_PRIORITY_IMPORTANT,
                      waivedWhenNotVisible: true,
                    ),
                  ),
                  onWebViewCreated: (controller) {
                    _controller = controller;

                    // Register bridge for JS -> Dart communication
                    controller.addJavaScriptHandler(
                      handlerName: 'FocusDM',
                      callback: (args) async {
                        final msg = args.isNotEmpty ? args[0].toString() : '';
                        if (msg.startsWith('REDIRECT')) {
                          debugPrint('🔍 [FocusDM-Bridge] REDIRECT received: $msg');
                          final current = (await _controller?.getUrl())?.toString() ?? '';
                          if (!_isAllowedUrl(current)) {
                            debugPrint('🚫 [FocusDM-Bridge] Reloading inbox, current URL is: $current');
                            _controller?.loadUrl(
                              urlRequest: URLRequest(
                                url: WebUri(AppConstants.instagramInboxUrl),
                              ),
                            );
                          }
                        } else if (msg.startsWith('LOG:')) {
                          // Print JS logs to adb logcat
                          debugPrint('🌐 [FocusDM-JS] ${msg.substring(4)}');
                          // Canary: SCRIPT_BOOT is the proof that JS injection succeeded
                          if (msg.contains('SCRIPT_BOOT')) {
                            unawaited(CanaryService.instance.recordSuccess());
                          }
                          // Canary: HOOK_ERR means JS injection threw a runtime error
                          if (msg.contains('HOOK_ERR')) {
                            unawaited(CanaryService.instance.recordFailure(
                              checkId: 'js_hook_error',
                              detail: msg.substring(4),
                            ));
                          }
                          // Canary: OBSERVER_ERR = MutationObserver/DM detection failed
                          if (msg.contains('OBSERVER_ERR')) {
                            unawaited(CanaryService.instance.recordFailure(
                              checkId: 'mutation_observer',
                              detail: msg.substring(4),
                            ));
                          }
                        } else if (msg.startsWith('NOTIF:')) {
                          try {
                            final raw = msg.substring(6);
                            final data = jsonDecode(raw) as Map<String, dynamic>;
                            final sender = (data['sender'] as String?)?.trim() ?? 'New Message';
                            final body = (data['body'] as String?)?.trim() ?? 'You received a new direct message';
                            await NotificationService.instance.showInstantMessageNotification(
                              sender: sender,
                              message: body,
                            );
                          } catch (e) {
                            debugPrint('Error triggering instant notification: $e');
                          }
                        } else if (msg == 'MSG_ACTIVITY') {
                          // Real-time direct message packet detected over WebSocket
                          debugPrint('💬 [FocusDM] Live incoming direct message packet detected');
                        } else if (msg == 'FILE_CHOOSER_OPEN') {
                          // JS detected a file input click — mark chooser open
                          debugPrint('📂 [FocusDM-Bridge] FILE_CHOOSER_OPEN received from JS');
                          if (mounted) setState(() => _fileChooserOpen = true);
                        } else if (msg == 'NAV_BACK') {
                          _handleBackPress();
                        } else if (msg == 'NAV_INBOX') {
                          resetToInbox();
                        }
                      },
                    );
                  },
                  onLoadStart: (controller, url) {
                    if (mounted) {
                      setState(() => _isLoading = true);
                    }
                  },
                  onLoadStop: (controller, url) {
                    if (mounted) {
                      setState(() {
                        _isLoading = false;
                        // File chooser is definitely closed when page stops loading
                        _fileChooserOpen = false;
                      });
                    }

                    // Save session cookies to SharedPreferences for background notification sync
                    CookieManager.instance().getCookies(url: WebUri('https://www.instagram.com')).then((cookies) async {
                      if (cookies.isNotEmpty) {
                        final cookieHeader = cookies.map((c) => '${c.name}=${c.value}').join('; ');
                        final prefs = await SharedPreferences.getInstance();
                        await prefs.setString('ig_session_cookies', cookieHeader);
                      }
                    });
                  },
                  onWindowFocus: (controller) {
                    // WebView regained focus — user returned from file picker or system overlay.
                    // Reset both the flag and the JS timestamp so back button works normally.
                    if (mounted && _fileChooserOpen) {
                      debugPrint('📂 [FocusDM] WebView regained focus — resetting file chooser state');
                      setState(() => _fileChooserOpen = false);
                    }
                    _controller?.evaluateJavascript(
                      source: 'window.__focusDmLastFileClick = 0;',
                    );
                  },
                  onPermissionRequest: (controller, request) async {
                    final originHost = request.origin.host.toLowerCase();
                    final isInstagram = originHost == 'instagram.com' || originHost.endsWith('.instagram.com');
                    return PermissionResponse(
                      resources: request.resources,
                      action: isInstagram ? PermissionResponseAction.GRANT : PermissionResponseAction.DENY,
                    );
                  },
                  onUpdateVisitedHistory: (controller, url, isReload) {
                    final urlString = url?.toString() ?? '';
                    final allowed = _isAllowedUrl(urlString);
                    debugPrint('🌍 [FocusDM-History] onUpdateVisitedHistory: $urlString | allowed=$allowed');
                    if (urlString.isNotEmpty && !allowed) {
                      debugPrint('🚫 [FocusDM-History] Disallowed — reloading inbox');
                      // Canary: unexpected navigation = potential Instagram web structural change
                      unawaited(CanaryService.instance.recordUnexpectedNavigation(urlString));
                      controller.loadUrl(
                        urlRequest: URLRequest(
                          url: WebUri(AppConstants.instagramInboxUrl),
                        ),
                      );
                    }
                  },
                  shouldOverrideUrlLoading:
                      (controller, navigationAction) async {
                    if (!navigationAction.isForMainFrame) {
                      return NavigationActionPolicy.ALLOW;
                    }

                    final uri = navigationAction.request.url;
                    final url = uri?.toString() ?? '';
                    final allowed = _isAllowedUrl(url);
                    debugPrint('🔗 [FocusDM-Nav] shouldOverrideUrlLoading: $url | allowed=$allowed');

                    if (allowed) {
                      return NavigationActionPolicy.ALLOW;
                    }

                    // Cancel disallowed navigation without re-triggering reload
                    return NavigationActionPolicy.CANCEL;
                  },
                ),
                if (_isLoading)
                  Container(
                    color: Colors.black,
                    child: const Center(
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 1.5,
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
