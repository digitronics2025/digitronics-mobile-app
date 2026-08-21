# FLEET.md — digitronics-mobile-app

Part of the TenTen fleet (map: claude-config → `skills/tenten-fleet`).
Update this file in the SAME commit as any change to a cross-repo contract.
Last verified: 2026-08-21

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
| DigiTronics.ma website | WebView loads `https://digitronics.ma` ([lib/constants/urls.dart](./lib/constants/urls.dart)) | site session cookies | ⚠️ urls.dart still lists WooCommerce-era paths (`/shop/`, `/vous-panier/`…) predating the Next.js rebuild — verify before relying on them |
| DigiTronics.ma API | `POST /api/v1/push/register` `{token, platform}` ([lib/services/notification_service.dart](./lib/services/notification_service.dart)) | **NONE** — only User-Agent `DigitronicsApp/1.0 (Android; FCM-register)`; fire-and-forget, re-sent on token refresh | server side (`app_push_tokens` table + WAF note) lives in the DigiTronics.ma repo |
| Firebase FCM | topic `all` subscription | google-services.json | |

## Planned, not built

- Website → FCM campaign sender: tokens are collected, **nothing sends yet**.
- Deep links: need `/.well-known/assetlinks.json` served by the site + a
  Cloudflare WAF skip rule + the Play signing SHA-256 (all pending; the repo
  carries its own assetlinks.json copy).

## Secret names (names only — NEVER values)

CI: `GOOGLE_SERVICES_JSON_BASE64`, `ANDROID_KEYSTORE_BASE64`,
`ANDROID_KEYSTORE_PASSWORD`, `ANDROID_KEY_ALIAS`, `ANDROID_KEY_PASSWORD`,
optional `PLAY_SERVICE_ACCOUNT_JSON`.

## Contract paths (what the fleet audit watches)

`lib/services/notification_service.dart`, `lib/constants/urls.dart`,
`.well-known/assetlinks.json`, `docs/GUIDE.md`.

## Run & debug

Release flow: bump `pubspec.yaml` → tag `vX.Y.Z` → download artifact → upload
in Play Console. See [docs/ci-release.md](./docs/ci-release.md).

## Deep docs

[docs/GUIDE.md](./docs/GUIDE.md) (single source of truth) ·
[docs/deep-links.md](./docs/deep-links.md) · [docs/HANDOFF.md](./docs/HANDOFF.md)
