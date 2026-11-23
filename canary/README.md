# Focus DM — Instagram Web Canary Monitor

## What This Does

Runs automated checks every **6 hours** against `instagram.com/direct/inbox/` using a headless Chromium browser (Playwright). Tests every JavaScript selector, DOM element, API endpoint, and browser API override that the Focus DM app relies on.

If anything breaks → **instant Discord embed + email alert**.

---

## Required GitHub Secrets

Go to your repo → **Settings → Secrets and Variables → Actions → New repository secret** and add:

| Secret Name | Value |
|---|---|
| `DISCORD_WEBHOOK_URL` | Your Discord webhook URL |
| `ALERT_EMAIL` | `your-alert-email@example.com` |
| `SENDGRID_API_KEY` | Your [SendGrid](https://sendgrid.com) free API key (for email alerts) |

> **Note on SendGrid:** Sign up free at sendgrid.com (3,000 emails/month free). Create an API key with "Mail Send" permission. Verify a sender email (or domain) in SendGrid before alerts will send.

---

## Checks Performed

| # | Check | Critical? | What it tests |
|---|---|---|---|
| 1 | Page Load | ✅ | `instagram.com/direct/inbox/` loads without unexpected redirect |
| 2 | DM Thread List | ✅ | `[role="listitem"]` / `[role="list"]` DOM elements present |
| 3 | `[role="main"]` Container | ✅ | Primary container used for DM count detection |
| 4 | Badge Count API | ✅ | `/api/v1/direct_v2/get_badge_count/` endpoint alive |
| 5 | Flutter Bridge Global | ⚠️ | `window` global assignment not blocked by Instagram |
| 6 | `[aria-label="Back"]` | ⚠️ | Back button selector validity |
| 7 | `[aria-label="Home"]` Block Target | ⚠️ | Nav blocking selectors still match |
| 8 | Compose Button | ⚠️ | New message button selector |
| 9 | `<title>` Tag | ✅ | Document title used for unread count (`(N) Instagram`) |
| 10 | Build ID Extraction | ℹ️ | Detects Instagram web build hash for version tracking |
| 11 | CSS Style Injection | ✅ | `document.createElement('style')` not blocked by CSP |
| 12 | XHR Override | ✅ | `XMLHttpRequest.prototype.open` overrideable (notification polling) |
| 13 | `history.pushState` Override | ✅ | Route change detection still works |
| 14 | `localStorage` Access | ⚠️ | Debug log persistence |

---

## Manual Trigger

Go to **GitHub Actions → Focus DM Instagram Web Canary Monitor → Run workflow** to trigger an immediate check at any time.

---

## Local Testing

```bash
cd canary
npm install
npx playwright install chromium
DISCORD_WEBHOOK_URL="your-webhook" node check.js
```
