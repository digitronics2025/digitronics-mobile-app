# FLEET.md — digitronics-mobile-app

Part of the TenTen fleet (map: claude-config → `skills/tenten-fleet`).
Update this file in the SAME commit as any change to a cross-repo contract.
Last verified: 2026-10-26

## What this app is

Official Android app for digitronics.ma — a Flutter WebView shell ("the
website IS the UI") plus native splash, Firebase push (FCM), offline screen,
deep links, in-app review. Package `com.maroc.digitronics`.

## Tech & deploy

Flutter/Dart, Android only; Firebase project `digitronics-app` (FCM topic
`all`). Ships to Google Play via manual `.aab` upload; GitHub Actions builds
signed artifacts on `v*` tags. Flutter is NOT installed locally — the cloud
builds everything. A plain push to main runs CI checks only (no release).

## Exposes

None — client app.

## Consumes (what this app calls elsewhere)

| Target | Surface | Auth | Notes |
| --- | --- | --- | --- |
| DigiTronics.ma website | WebView opens the locale root `https://digitronics.ma/{fr,ar,en}` directly ([lib/constants/urls.dart](./lib/constants/urls.dart)); App Links and notification URLs open only `https://digitronics.ma` pages ([lib/services/link_router.dart](./lib/services/link_router.dart)) | site session cookies | The WooCommerce-era paths were removed on 24/10/2026. Renaming a locale root on the site breaks the app's first page |
| DigiTronics.ma API | `POST /api/v1/push/register` `{token, platform, appVersion}` ([lib/services/notification_service.dart](./lib/services/notification_service.dart)) | **NONE** — only User-Agent `DigitronicsApp/<version> (Android; FCM-register)`; fire-and-forget, re-sent on token refresh | server side (`app_push_tokens` table + WAF note) lives in the DigiTronics.ma repo |
| DigiTronics.ma API | `POST /api/v1/observability/error` `{scope:'app', message, route, locale, userAgent}` ([lib/services/load_report_service.dart](./lib/services/load_report_service.dart)), since 1.0.13 | **NONE** — public, rate-limited per IP; User-Agent `DigitronicsApp/<version> (Android; load-report)` | Page-load failures and recoveries. The site accepts `scope:'app'` from 24/10/2026 and logs it at `warn` (`src/lib/observability/error-report-level.ts` there). An older site answers 200 with `VALIDATION_001` and drops it — harmless |
| DigiTronics.ma website (in-page) | `window.__digitronicsApp = {platform:'android', version, fcmToken?}` + `digitronics:app-bridge` event, injected after each own-site page load ([lib/services/app_bridge.dart](./lib/services/app_bridge.dart)), since 1.0.14 | none — data for the page only | Read by the website chat (`src/lib/website-chat/continuity-client.ts`) to hide the install card in the app and to bind the token to the customer's own chat session (`POST /api/v1/chat-push {kind:'fcm'}`, cookie-verified server-side). Renaming either side breaks private reply notifications |
| DigiTronics.ma website → app | FCM HTTP v1 message to ONE token: `notification{title,body}` + `data{url:'/{locale}?dt_chat=open', type:'chat_reply'}` (website `src/lib/fcm.ts`) | Firebase service account (website secret `FCM_SERVICE_ACCOUNT_JSON`) | Tap routes through `PendingLink` like any notification URL. Never a topic |
| Firebase FCM | topic `all` subscription | google-services.json | Legacy broadcast list only; never used for private chat replies |

## Planned, not built

- Website → FCM campaign sender: tokens are collected, **no campaign sends yet**
  (the per-token chat-reply sender exists, idle until its secret is set).
- Deep links: need `/.well-known/assetlinks.json` served by the site + a
  Cloudflare WAF skip rule + the Play signing SHA-256 (all pending; the repo
  carries its own assetlinks.json copy).

## Secret names (names only — NEVER values)

CI: `GOOGLE_SERVICES_JSON_BASE64`, `ANDROID_KEYSTORE_BASE64`,
`ANDROID_KEYSTORE_PASSWORD`, `ANDROID_KEY_ALIAS`, `ANDROID_KEY_PASSWORD`,
optional `PLAY_SERVICE_ACCOUNT_JSON`.

## Contract paths (what the fleet audit watches)

`lib/services/notification_service.dart`, `lib/constants/urls.dart`,
`lib/services/load_report_service.dart`, `lib/services/link_router.dart`,
`lib/services/app_bridge.dart`,
`.well-known/assetlinks.json`, `docs/GUIDE.md`.

## Run & debug

Release flow: bump `pubspec.yaml` → tag `vX.Y.Z` → download artifact → upload
in Play Console. See [docs/ci-release.md](./docs/ci-release.md).

## Deep docs

[docs/GUIDE.md](./docs/GUIDE.md) (single source of truth) ·
[docs/deep-links.md](./docs/deep-links.md) · [docs/HANDOFF.md](./docs/HANDOFF.md)
