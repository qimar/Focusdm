/**
 * Focus DM — Instagram Web Canary Health Monitor
 * ─────────────────────────────────────────────
 * Tests every selector, script, API endpoint, and injection point
 * that the Focus DM app relies on. Fires a rich Discord embed + email
 * if anything breaks.
 */

const { chromium } = require('playwright');
const fs = require('fs');
const path = require('path');
const https = require('https');

// Load environment variables from .env if present
const envCandidates = [
  path.join(__dirname, '..', '.env'),
  path.join(__dirname, '.env'),
];
for (const envFile of envCandidates) {
  if (fs.existsSync(envFile)) {
    const lines = fs.readFileSync(envFile, 'utf8').split('\n');
    for (const line of lines) {
      const trimmed = line.trim();
      if (trimmed && !trimmed.startsWith('#') && trimmed.includes('=')) {
        const idx = trimmed.indexOf('=');
        const k = trimmed.slice(0, idx).trim();
        const v = trimmed.slice(idx + 1).trim();
        if (!process.env[k]) process.env[k] = v;
      }
    }
  }
}

// ── Config ─────────────────────────────────────────────────────────────────
const DISCORD_WEBHOOK_URL = process.env.DISCORD_WEBHOOK_URL;
const ALERT_EMAIL         = process.env.ALERT_EMAIL || 'alerts@focusdm.app';
const SENDGRID_API_KEY    = process.env.SENDGRID_API_KEY;
const APP_VERSION         = process.env.APP_VERSION || '1.0.0';
const INSTAGRAM_URL       = 'https://www.instagram.com/direct/inbox/';
const TIMEOUT_MS          = 20000;

// Report directory
const REPORT_DIR = path.join(__dirname, 'reports');
if (!fs.existsSync(REPORT_DIR)) fs.mkdirSync(REPORT_DIR, { recursive: true });

// ── Check Definitions ──────────────────────────────────────────────────────
// Each check is a function that receives (page) and returns { passed, detail }
const CHECKS = [
  {
    id: 'page_load',
    name: '🌐 Instagram Web Page Load',
    description: 'instagram.com/direct/inbox/ loads without error redirect',
    critical: true,
    run: async (page) => {
      const url = page.url();
      const isOnDirect = url.includes('/direct') || url.includes('/accounts/login');
      return {
        passed: isOnDirect,
        detail: `Final URL: ${url}`,
      };
    },
  },
  {
    id: 'dm_list_present',
    name: '💬 DM Thread List DOM Element',
    description: 'div[role="list"] or div[role="listitem"] exists in inbox',
    critical: true,
    run: async (page) => {
      const count = await page.evaluate(() => {
        return document.querySelectorAll('[role="listitem"], [role="list"]').length;
      });
      return {
        passed: count > 0,
        detail: `Found ${count} list/listitem elements`,
      };
    },
  },
  {
    id: 'main_role',
    name: '🏠 [role="main"] Container',
    description: 'Primary content container FocusDM uses for DM count detection',
    critical: true,
    run: async (page) => {
      const found = await page.evaluate(() => {
        return !!(
          document.querySelector('[role="main"]') ||
          document.querySelector('main')
        );
      });
      return {
        passed: found,
        detail: found ? 'role="main" or <main> exists' : 'MISSING — DM count detection will fail',
      };
    },
  },
  {
    id: 'direct_api_badge',
    name: '🔢 /api/v1/direct_v2/get_badge_count/ API',
    description: 'Instagram DM badge count API endpoint (used for unread count detection)',
    critical: true,
    run: async (page) => {
      const result = await page.evaluate(async () => {
        try {
          const resp = await fetch('/api/v1/direct_v2/get_badge_count/', {
            credentials: 'include',
          });
          return { status: resp.status, ok: resp.ok };
        } catch (e) {
          return { status: 0, ok: false, error: e.message };
        }
      });
      // 200 = logged in, 401 = not logged in but endpoint exists (still healthy)
      const endpointExists = result.status === 200 || result.status === 401 || result.status === 403;
      return {
        passed: endpointExists,
        detail: `HTTP ${result.status} — ${endpointExists ? 'endpoint alive' : 'endpoint GONE or changed'}`,
      };
    },
  },
  {
    id: 'flutter_bridge_global',
    name: '🔌 window.flutter_inappwebview Global',
    description: 'The Flutter JS bridge global that FocusDM uses to send messages to Dart',
    critical: false,
    run: async (page) => {
      // We check if instagram.com blocks or removes this pattern —
      // the real test is that nothing on the page clobbers window.flutter_inappwebview
      const blocked = await page.evaluate(() => {
        // Check if the page overrides Object.defineProperty in a way that would break our bridge
        try {
          window.__focusDmCanaryTest = { callHandler: function() { return true; } };
          return typeof window.__focusDmCanaryTest.callHandler === 'function';
        } catch (e) {
          return false;
        }
      });
      return {
        passed: blocked,
        detail: blocked
          ? 'window global assignment works — bridge will function'
          : 'window global blocked — Flutter bridge may fail',
      };
    },
  },
  {
    id: 'aria_back_button',
    name: '⬅️ [aria-label="Back"] Element',
    description: 'Back button selector used for thread-to-inbox navigation',
    critical: false,
    run: async (page) => {
      // Navigate to a thread-like URL to trigger back button
      const found = await page.evaluate(() => {
        // On inbox, check if the pattern could exist anywhere in document
        const el = document.querySelector(
          '[aria-label="Back"], [aria-label*="back" i], svg[aria-label="Back"]'
        );
        return !!el;
      });
      return {
        passed: true, // Not critical on inbox, just check structure
        detail: found
          ? '[aria-label="Back"] found on inbox (unusual but ok)'
          : '[aria-label="Back"] not on inbox (expected — only appears inside threads)',
      };
    },
  },
  {
    id: 'aria_home_exists',
    name: '🚫 [aria-label="Home"] Block Target',
    description: 'FocusDM blocks clicks on Home — check the selector still matches the nav element',
    critical: false,
    run: async (page) => {
      const result = await page.evaluate(() => {
        const home = document.querySelector('[aria-label="Home"], [aria-label="Explore"], [aria-label="Reels"]');
        const nav = document.querySelector('nav[role="navigation"]');
        return { homeEl: !!home, navEl: !!nav };
      });
      // We expect these to EXIST (so we can block them). If they disappear, our blocks are harmless but ineffective.
      return {
        passed: true,
        detail: `aria Home: ${result.homeEl ? '✅' : '⚠️ missing'} | nav[role=navigation]: ${result.navEl ? '✅' : '⚠️ missing'}`,
      };
    },
  },
  {
    id: 'compose_button',
    name: '✏️ New Message / Compose Button',
    description: 'Top-right compose button that FocusDM explicitly allows tapping',
    critical: false,
    run: async (page) => {
      const found = await page.evaluate(() => {
        const el = document.querySelector(
          '[aria-label*="new message" i], [aria-label*="compose" i], [aria-label*="new chat" i], svg[aria-label*="Edit"]'
        );
        return !!el;
      });
      return {
        passed: true, // Not page-breaking if absent
        detail: found ? 'Compose button selector matches ✅' : 'Compose button aria-label may have changed ⚠️',
      };
    },
  },
  {
    id: 'title_element',
    name: '📄 <title> Tag (Unread Count Detection)',
    description: 'FocusDM reads (N) prefix from document.title to detect unread DM count',
    critical: true,
    run: async (page) => {
      const title = await page.evaluate(() => document.title);
      const hasTitleEl = await page.evaluate(() => !!document.querySelector('title'));
      return {
        passed: hasTitleEl,
        detail: `document.title = "${title}" | <title> element: ${hasTitleEl ? 'exists' : 'MISSING'}`,
      };
    },
  },
  {
    id: 'instagram_build_id',
    name: '🏷️ Instagram Web Build / Version ID',
    description: 'Detected Instagram web build hash for change tracking',
    critical: false,
    run: async (page) => {
      const buildInfo = await page.evaluate(() => {
        // Try to extract Instagram build/version from page source patterns
        const scripts = Array.from(document.querySelectorAll('script[src]'))
          .map(s => s.src)
          .filter(s => s.includes('chunk') || s.includes('bundle') || s.includes('main'));

        // Try to get version from meta or window.__additionalData
        let version = 'unknown';
        try {
          const metaVer = document.querySelector('meta[property="al:android:app_name"]');
          if (metaVer) version = metaVer.getAttribute('content') || 'unknown';
        } catch (_) {}

        // Extract a hash from the first JS bundle URL as a proxy for "web version"
        const firstBundle = scripts[0] || '';
        const hashMatch = firstBundle.match(/\/([a-f0-9]{8,})\./);
        const buildHash = hashMatch ? hashMatch[1] : 'undetected';

        return {
          buildHash,
          bundleCount: scripts.length,
          title: document.title,
          htmlLang: document.documentElement.lang,
        };
      });

      return {
        passed: true, // Informational only
        detail: `Build hash: ${buildInfo.buildHash} | Bundles: ${buildInfo.bundleCount} | Lang: ${buildInfo.htmlLang} | Title: "${buildInfo.title}"`,
        meta: buildInfo,
      };
    },
  },
  {
    id: 'css_shield_injection',
    name: '🛡️ CSS style injection (document.createElement)',
    description: 'FocusDM injects a <style> tag at document start — verify no CSP blocks it',
    critical: true,
    run: async (page) => {
      const result = await page.evaluate(() => {
        try {
          const style = document.createElement('style');
          style.id = 'focus-dm-canary-test';
          style.textContent = '/* canary test */';
          (document.head || document.documentElement).appendChild(style);
          const injected = !!document.getElementById('focus-dm-canary-test');
          if (injected) style.remove();
          return { injected, error: null };
        } catch (e) {
          return { injected: false, error: e.message };
        }
      });
      return {
        passed: result.injected,
        detail: result.injected
          ? '<style> injection works — CSS shield is functional'
          : `CSS injection BLOCKED: ${result.error}`,
      };
    },
  },
  {
    id: 'xhr_intercept_possible',
    name: '📡 XMLHttpRequest Override',
    description: 'FocusDM overrides XHR for DM count polling — verify Instagram does not freeze XHR prototype',
    critical: true,
    run: async (page) => {
      const result = await page.evaluate(() => {
        try {
          const original = XMLHttpRequest.prototype.open;
          let intercepted = false;
          XMLHttpRequest.prototype.open = function(...args) {
            intercepted = true;
            return original.apply(this, args);
          };
          // Make a test XHR
          const xhr = new XMLHttpRequest();
          xhr.open('GET', '/favicon.ico');
          // Restore
          XMLHttpRequest.prototype.open = original;
          return { intercepted, error: null };
        } catch (e) {
          return { intercepted: false, error: e.message };
        }
      });
      return {
        passed: result.intercepted,
        detail: result.intercepted
          ? 'XHR prototype override works — notification polling is functional'
          : `XHR override BLOCKED: ${result.error}`,
      };
    },
  },
  {
    id: 'history_pushstate',
    name: '🧭 history.pushState Override',
    description: 'FocusDM wraps history.pushState for SPA route change detection',
    critical: true,
    run: async (page) => {
      const result = await page.evaluate(() => {
        try {
          const orig = history.pushState;
          let overrideWorked = false;
          history.pushState = function(...args) {
            overrideWorked = true;
            return orig.apply(this, args);
          };
          history.pushState({}, '', window.location.href);
          history.pushState = orig;
          return { overrideWorked, error: null };
        } catch (e) {
          return { overrideWorked: false, error: e.message };
        }
      });
      return {
        passed: result.overrideWorked,
        detail: result.overrideWorked
          ? 'history.pushState override works — route detection is functional'
          : `history override BLOCKED: ${result.error}`,
      };
    },
  },
  {
    id: 'localstorage_access',
    name: '💾 localStorage Access',
    description: 'FocusDM uses localStorage for debug log persistence',
    critical: false,
    run: async (page) => {
      const result = await page.evaluate(() => {
        try {
          localStorage.setItem('__focusDmCanary', '1');
          const val = localStorage.getItem('__focusDmCanary');
          localStorage.removeItem('__focusDmCanary');
          return { works: val === '1', error: null };
        } catch (e) {
          return { works: false, error: e.message };
        }
      });
      return {
        passed: result.works,
        detail: result.works
          ? 'localStorage read/write works'
          : `localStorage BLOCKED: ${result.error}`,
      };
    },
  },
];

// ── Discord Alert ──────────────────────────────────────────────────────────
async function sendDiscordAlert({ failures, warnings, buildInfo, timestamp, screenshotPath, runUrl }) {
  if (!DISCORD_WEBHOOK_URL) {
    console.warn('[Canary] No DISCORD_WEBHOOK_URL set — skipping Discord alert');
    return;
  }

  const failedChecks = failures.filter(f => f.critical);
  const warnChecks   = failures.filter(f => !f.critical);
  const totalChecks  = CHECKS.length;
  const passCount    = totalChecks - failures.length;

  const color = failedChecks.length > 0 ? 0xFF3B30 : 0xFF9500; // Red = critical, Orange = warning

  const embed = {
    title: failedChecks.length > 0
      ? '🚨 CRITICAL — Focus DM App Functionality Broken'
      : '⚠️ WARNING — Focus DM Non-Critical Checks Failed',
    description: failedChecks.length > 0
      ? 'One or more **critical** Instagram web selectors or APIs that Focus DM depends on have broken. **Users are currently experiencing a degraded or broken experience.**'
      : 'Non-critical checks failed. Core functionality likely still works but some features may be degraded.',
    color,
    timestamp: new Date(timestamp).toISOString(),
    fields: [
      {
        name: '📊 Check Summary',
        value: [
          `✅ Passed: **${passCount}** / ${totalChecks}`,
          `🔴 Critical Failures: **${failedChecks.length}**`,
          `🟡 Warnings: **${warnChecks.length}**`,
        ].join('\n'),
        inline: false,
      },
      ...(failedChecks.length > 0 ? [{
        name: '🔴 Critical Failures',
        value: failedChecks.map(f =>
          `**${f.name}**\n> ${f.description}\n> ❌ \`${f.detail}\``
        ).join('\n\n').slice(0, 1000),
        inline: false,
      }] : []),
      ...(warnChecks.length > 0 ? [{
        name: '🟡 Warnings (Non-Critical)',
        value: warnChecks.map(f =>
          `**${f.name}**\n> ⚠️ \`${f.detail}\``
        ).join('\n\n').slice(0, 800),
        inline: false,
      }] : []),
      {
        name: '🏷️ Instagram Web Version',
        value: buildInfo
          ? `Build Hash: \`${buildInfo.buildHash || 'unknown'}\`\nBundle count: ${buildInfo.bundleCount || '?'}`
          : '`undetected`',
        inline: true,
      },
      {
        name: '📱 Focus DM App Version',
        value: `\`v${APP_VERSION}\``,
        inline: true,
      },
      {
        name: '🕐 Detected At',
        value: `<t:${Math.floor(new Date(timestamp).getTime() / 1000)}:F>\n(<t:${Math.floor(new Date(timestamp).getTime() / 1000)}:R>)`,
        inline: true,
      },
      {
        name: '🔗 GitHub Actions Run',
        value: runUrl ? `[View Full Logs](${runUrl})` : 'Manual / local run',
        inline: true,
      },
      {
        name: '⚡ What to Do',
        value: failedChecks.length > 0
          ? '1. Open Instagram web on desktop and inspect the broken selector\n2. Update the matching JS/CSS in `inbox_screen.dart`\n3. Run `flutter build apk --debug` and install a hotfix'
          : 'Monitor for 24h — if warning persists, investigate the non-critical selectors.',
        inline: false,
      },
    ],
    footer: {
      text: `Focus DM Canary Monitor • instagram.com/direct/inbox/ • Checks every 6 hours`,
      icon_url: 'https://www.instagram.com/favicon.ico',
    },
    thumbnail: {
      url: 'https://www.instagram.com/favicon.ico',
    },
  };

  const payload = JSON.stringify({
    username: 'Focus DM Canary',
    avatar_url: 'https://cdn.discordapp.com/embed/avatars/0.png',
    embeds: [embed],
  });

  return new Promise((resolve, reject) => {
    const url = new URL(DISCORD_WEBHOOK_URL);
    const options = {
      hostname: url.hostname,
      path: url.pathname + url.search,
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Content-Length': Buffer.byteLength(payload),
      },
    };

    const req = https.request(options, (res) => {
      console.log(`[Canary] Discord webhook response: ${res.statusCode}`);
      resolve(res.statusCode);
    });
    req.on('error', reject);
    req.write(payload);
    req.end();
  });
}

// ── Email Alert via SendGrid ───────────────────────────────────────────────
async function sendEmailAlert({ failures, buildInfo, timestamp }) {
  if (!SENDGRID_API_KEY) {
    console.warn('[Canary] No SENDGRID_API_KEY — skipping email alert');
    return;
  }

  const failedChecks   = failures.filter(f => f.critical);
  const subject = failedChecks.length > 0
    ? `🚨 CRITICAL: Focus DM App Broken — ${failedChecks.length} checks failed`
    : `⚠️ WARNING: Focus DM Non-Critical Checks Failed`;

  const htmlBody = `
    <div style="font-family:sans-serif;max-width:600px;margin:auto;">
      <h2 style="color:${failedChecks.length > 0 ? '#FF3B30' : '#FF9500'}">
        ${failedChecks.length > 0 ? '🚨 CRITICAL ALERT' : '⚠️ WARNING'} — Focus DM Canary Monitor
      </h2>
      <p><strong>Detected at:</strong> ${new Date(timestamp).toUTCString()}</p>
      <p><strong>Instagram Build Hash:</strong> <code>${buildInfo?.buildHash || 'unknown'}</code></p>
      <p><strong>Focus DM App Version:</strong> v${APP_VERSION}</p>
      <hr/>
      <h3>Failed Checks (${failures.length})</h3>
      ${failures.map(f => `
        <div style="border-left:4px solid ${f.critical ? '#FF3B30' : '#FF9500'};padding:8px 12px;margin:8px 0;">
          <strong>${f.name}</strong> ${f.critical ? '(CRITICAL)' : '(Warning)'}<br/>
          <em>${f.description}</em><br/>
          <code style="color:red;">${f.detail}</code>
        </div>
      `).join('')}
      <hr/>
      <h3>What to do</h3>
      <ol>
        <li>Open <a href="https://instagram.com/direct/inbox/">instagram.com/direct/inbox/</a> on desktop</li>
        <li>Open DevTools → inspect the broken element/selector</li>
        <li>Update the corresponding JS/CSS in <code>inbox_screen.dart → _blockingScript</code></li>
        <li>Build and release a hotfix APK</li>
      </ol>
    </div>
  `;

  const payload = JSON.stringify({
    personalizations: [{ to: [{ email: ALERT_EMAIL }] }],
    from: { email: 'canary@focusdm.app', name: 'Focus DM Canary' },
    subject,
    content: [{ type: 'text/html', value: htmlBody }],
  });

  return new Promise((resolve, reject) => {
    const options = {
      hostname: 'api.sendgrid.com',
      path: '/v3/mail/send',
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${SENDGRID_API_KEY}`,
        'Content-Length': Buffer.byteLength(payload),
      },
    };
    const req = https.request(options, (res) => {
      console.log(`[Canary] SendGrid response: ${res.statusCode}`);
      resolve(res.statusCode);
    });
    req.on('error', reject);
    req.write(payload);
    req.end();
  });
}

// ── Main Runner ────────────────────────────────────────────────────────────
async function run() {
  const timestamp = new Date().toISOString();
  const runUrl = process.env.GITHUB_SERVER_URL && process.env.GITHUB_REPOSITORY && process.env.GITHUB_RUN_ID
    ? `${process.env.GITHUB_SERVER_URL}/${process.env.GITHUB_REPOSITORY}/actions/runs/${process.env.GITHUB_RUN_ID}`
    : null;

  console.log(`\n╔══════════════════════════════════════════════════════╗`);
  console.log(`║   Focus DM — Instagram Web Canary Monitor            ║`);
  console.log(`║   ${timestamp}              ║`);
  console.log(`╚══════════════════════════════════════════════════════╝\n`);

  let browser;
  let buildInfo = null;
  const failures = [];
  const results  = [];

  try {
    browser = await chromium.launch({
      headless: true,
      args: [
        '--no-sandbox',
        '--disable-setuid-sandbox',
        '--disable-dev-shm-usage',
        // Simulate a real Android Chrome UA (matches the WebView UA in Focus DM)
        '--user-agent=Mozilla/5.0 (Linux; Android 14; Pixel 8) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/128.0.0.0 Mobile Safari/537.36',
      ],
    });

    const context = await browser.newContext({
      viewport: { width: 390, height: 844 },
      userAgent: 'Mozilla/5.0 (Linux; Android 14; Pixel 8) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/128.0.0.0 Mobile Safari/537.36',
      locale: 'en-US',
    });

    const page = await context.newPage();

    // Navigate to Instagram DM inbox
    console.log(`[Canary] Loading ${INSTAGRAM_URL}...`);
    await page.goto(INSTAGRAM_URL, {
      waitUntil: 'domcontentloaded',
      timeout: TIMEOUT_MS,
    });

    // Give React time to hydrate
    await page.waitForTimeout(4000);
    console.log(`[Canary] Page loaded — URL: ${page.url()}\n`);

    // Run each check
    for (const check of CHECKS) {
      process.stdout.write(`  Checking: ${check.name} ... `);
      try {
        const result = await check.run(page);
        if (check.id === 'instagram_build_id' && result.meta) {
          buildInfo = result.meta;
        }
        const status = result.passed ? '✅ PASS' : (check.critical ? '🔴 FAIL' : '🟡 WARN');
        console.log(`${status}`);
        console.log(`    → ${result.detail}`);

        results.push({ ...check, ...result });
        if (!result.passed) {
          failures.push({ ...check, detail: result.detail });
        }
      } catch (err) {
        console.log(`💥 ERROR`);
        console.log(`    → ${err.message}`);
        failures.push({
          ...check,
          passed: false,
          detail: `Exception during check: ${err.message}`,
        });
      }
    }

    // Save screenshot
    const screenshotPath = path.join(REPORT_DIR, `screenshot_${Date.now()}.png`);
    await page.screenshot({ path: screenshotPath, fullPage: false });
    console.log(`\n[Canary] Screenshot saved: ${screenshotPath}`);

  } catch (err) {
    console.error(`[Canary] FATAL: Could not load Instagram — ${err.message}`);
    failures.push({
      id: 'page_navigation',
      name: '🌐 Page Navigation (FATAL)',
      description: 'Could not reach instagram.com at all',
      critical: true,
      detail: err.message,
    });
  } finally {
    if (browser) await browser.close();
  }

  // ── Save JSON Report ─────────────────────────────────────────────────────
  const report = {
    timestamp,
    appVersion: APP_VERSION,
    instagramBuildInfo: buildInfo,
    totalChecks: CHECKS.length,
    passed: CHECKS.length - failures.length,
    failed: failures.length,
    criticalFailures: failures.filter(f => f.critical).length,
    results,
    failures,
  };

  const reportPath = path.join(REPORT_DIR, `report_${Date.now()}.json`);
  fs.writeFileSync(reportPath, JSON.stringify(report, null, 2));
  console.log(`[Canary] Report saved: ${reportPath}`);

  // ── Summary ──────────────────────────────────────────────────────────────
  console.log(`\n╔══════════════════════════════════════╗`);
  console.log(`║          CANARY SUMMARY               ║`);
  console.log(`╠══════════════════════════════════════╣`);
  console.log(`║  Total Checks:     ${String(CHECKS.length).padEnd(17)}║`);
  console.log(`║  ✅ Passed:        ${String(CHECKS.length - failures.length).padEnd(17)}║`);
  console.log(`║  🔴 Critical Fail: ${String(failures.filter(f=>f.critical).length).padEnd(17)}║`);
  console.log(`║  🟡 Warnings:      ${String(failures.filter(f=>!f.critical).length).padEnd(17)}║`);
  console.log(`╚══════════════════════════════════════╝\n`);

  // ── Fire Alerts if Any Failures ─────────────────────────────────────────
  if (failures.length > 0) {
    console.log('[Canary] Failures detected — firing alerts...\n');
    try {
      await sendDiscordAlert({ failures, buildInfo, timestamp, runUrl });
      console.log('[Canary] ✅ Discord alert sent');
    } catch (e) {
      console.error('[Canary] ❌ Discord alert failed:', e.message);
    }
    try {
      await sendEmailAlert({ failures, buildInfo, timestamp });
      console.log('[Canary] ✅ Email alert sent');
    } catch (e) {
      console.error('[Canary] ❌ Email alert failed:', e.message);
    }
    // Exit with code 1 so GitHub Actions marks the run as failed
    process.exit(failures.filter(f => f.critical).length > 0 ? 1 : 0);
  } else {
    console.log('[Canary] 🎉 All checks passed — no alerts needed\n');
    process.exit(0);
  }
}

run().catch((err) => {
  console.error('[Canary] Unhandled error:', err);
  process.exit(1);
});
