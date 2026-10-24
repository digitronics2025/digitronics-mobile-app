# Digitronics App — Complete Guide

> Single source of truth for the Digitronics Android app. Start here for any change.
> Last updated: 2026-10-24 (1.0.13: no more white screen — §11)

---

## 1. What this app is

A **Flutter WebView app** that wraps the **digitronics.ma** website full-screen and
adds native powers a browser can't. It is **not** a separate storefront — the
website *is* the UI. So most "app" changes are really website changes; this repo
only owns the native shell.

- **Package:** `com.maroc.digitronics`
- **Base URL:** `https://digitronics.ma`
- **Stack:** Flutter (Dart SDK ^3.8.1), Android only (iOS not built)
- **Native features:** animated splash, Firebase push (FCM), offline and
  "page did not load" retry screens, external-link routing, deep links (App
  Links, opened at the tapped page since 1.0.13), page-load error reporting,
  in-app review prompt.

---

## 2. Golden path — how to change something and ship it

1. **Edit** the Dart/config in this repo (see the cookbook in §3).
2. **Commit & push to `main`** → the **CI** workflow runs `flutter analyze` +
   tests automatically (validates your change compiles).
3. **Bump the version** in [`pubspec.yaml`](../pubspec.yaml) — e.g. `1.0.13+13`
   (the `+N` build number must always go up for Play).
4. **Tag & push the tag** → the **Release** workflow builds a *signed* app in the
   cloud (no local Flutter needed):
   ```bash
   git tag v1.0.13 && git push origin v1.0.13
   ```
5. **Download** the build from the GitHub Actions run → *Artifacts*:
   - `app-release-aab` → upload to Play Console (ships to users)
   - `app-release-apk` → sideload onto a phone to preview first
6. **Upload the `.aab`** in Play Console → *Test and release → Production →
   Create new release* → add release notes → *Start rollout*.

Full release detail: [`ci-release.md`](ci-release.md).
There is **no local build** — Flutter isn't installed on this PC; the cloud does it.

---

## 3. Cookbook — "I want to change…"

| I want to change… | Edit this |
| --- | --- |
| **Splash animation / text / colors** | [`lib/screens/splash_screen.dart`](../lib/screens/splash_screen.dart) |
| **System (OS) launch splash color/logo** | `flutter_native_splash:` block in [`pubspec.yaml`](../pubspec.yaml) (regenerated in CI) |
| **App icon** | `flutter_launcher_icons:` block in [`pubspec.yaml`](../pubspec.yaml) + images in [`assets/icon/`](../assets/icon) |
| **App theme / brand color** | `kBrandRed` in [`lib/app.dart`](../lib/app.dart) |
| **Offline / "page did not load" / loading screens** | [`lib/screens/retry_screen.dart`](../lib/screens/retry_screen.dart); their words (fr/ar/en) in [`lib/l10n/app_strings.dart`](../lib/l10n/app_strings.dart) |
| **What counts as a failed page load, the 20 s timeout** | [`lib/services/page_load_policy.dart`](../lib/services/page_load_policy.dart) (§11) |
| **Clear every phone's WebView cache once after an update** | bump `kWebViewCacheEpoch` in [`lib/constants/app_info.dart`](../lib/constants/app_info.dart) |
| **Which links open in-app vs. a native app** | `_externalHosts` in [`lib/services/external_link_service.dart`](../lib/services/external_link_service.dart) |
| **The website the app loads** | `AppUrls` in [`lib/constants/urls.dart`](../lib/constants/urls.dart) — it opens `/fr`, `/ar` or `/en` directly (the last language used on the site, else the phone's). Cross-repo contract: update FLEET.md in the same commit |
| **App version** | `version:` in [`pubspec.yaml`](../pubspec.yaml) **and** `kAppVersion` in [`lib/constants/app_info.dart`](../lib/constants/app_info.dart) (a test fails if they differ) |
| **Push-notification behaviour** | [`lib/services/notification_service.dart`](../lib/services/notification_service.dart) |
| **Deep-link routing (App Links + notification URLs)** | [`lib/services/link_router.dart`](../lib/services/link_router.dart) — only `https://digitronics.ma` pages are ever opened in-app |
| **When the review prompt appears** | `_openThreshold` in [`lib/services/review_service.dart`](../lib/services/review_service.dart) |
| **Android permissions / manifest** | [`android/app/src/main/AndroidManifest.xml`](../android/app/src/main/AndroidManifest.xml) |
| **Store listing (name, description, screenshots)** | Play Console → *Grow users → Store presence* (see §7) |

After any Dart/config edit: commit, push, then §2 steps 3–6 to ship.

---

## 4. Brand & design assets

- **Brand red:** `#E4232B` (splash + native splash). App theme seed: `#DD3333`
  (`kBrandRed`). Splash gradient: `#E4232B → #B01A20`.
- **Logo (transparent sphere):** [`assets/icon/app_icon_foreground.png`](../assets/icon/app_icon_foreground.png)
  — used for the icon, splash logo, and the store screenshots.
- **App icon background:** clean **white** (`#FFFFFF`) — set in `pubspec.yaml`.
- **Arabic tagline:** `ديجيترونيك بعروضها ترضيك`
- **Splash subtitle:** "Best Electronics Store in Morocco"

---

## 5. Credentials & secrets — where everything lives

**Nothing secret is committed.** Locations:

- **`.env`** (this repo root, **gitignored**) — keystore passwords, key alias,
  paths, Firebase project, upload-key SHA-256. This is your local reference file.
- **GitHub Actions secrets** (encrypted, used by the cloud build):
  `GOOGLE_SERVICES_JSON_BASE64`, `ANDROID_KEYSTORE_BASE64`,
  `ANDROID_KEYSTORE_PASSWORD`, `ANDROID_KEY_ALIAS`, `ANDROID_KEY_PASSWORD`,
  and optionally `PLAY_SERVICE_ACCOUNT_JSON`.
- **Signing keystore file:** `D:/digitronics/digitronics.jks`
  (alias `digitronics`). ⚠️ Irreplaceable — back it up in a password manager.
- **Firebase:** project `digitronics-app` (`804597428661`); config file
  `google-services.json` (gitignored, on `D:` and in a GitHub secret).
- **Upload-key SHA-256:** `3C:06:E4:3D:77:5A:1E:57:1D:6C:7D:0C:84:87:9E:2D:0D:9E:09:F2:DA:01:7C:51:E8:74:DE:99:CD:A2:DA:65`

Key facts and how to regenerate the base64 secrets: [`ci-release.md`](ci-release.md)
and [`HANDOFF.md`](HANDOFF.md).

---

## 6. CI/CD (GitHub Actions)

- [`.github/workflows/ci.yml`](../.github/workflows/ci.yml) — on every push/PR to
  `main`: `flutter analyze` + `flutter test`. No secrets.
- [`.github/workflows/release.yml`](../.github/workflows/release.yml) — on a `v*`
  tag or manual run: restores the keystore + Firebase file from secrets,
  regenerates icons + native splash, builds a **signed** `.aab` **and** `.apk`,
  uploads both as artifacts, and can optionally draft-publish to the Play
  internal track.

Check runs: repo → **Actions** tab, or `gh run list`.

**Toolchain floor (24/10/2026).** Both workflows build with the *latest stable*
Flutter, which on 3.47 requires Gradle ≥ 8.14, Android Gradle Plugin ≥ 8.11.1
and Kotlin ≥ 2.2.20 — the app was on 8.12 / 8.9.3 / 2.1.0 and no longer built.
Now: Gradle 8.14.3, AGP 8.11.1, Kotlin 2.2.20, proven by a local
`flutter build apk --release`. Flutter 3.47 also rewrites any `minSdk` ≤ 23 to
its own default on every build, so the app now needs **Android 7.0 (API 24)**;
phones on Android 6 keep the version they have but get no updates.

**Actions billing (24/10/2026):** jobs are not starting — GitHub reports
"recent account payments have failed or your spending limit needs to be
increased". Until that is fixed in GitHub → Settings → Billing, neither CI nor
the release build runs.

---

## 7. Play Store listing

- **Screenshots:** a ready-made branded set (French captions, real logo) was
  designed as an artifact — regenerate/upload via Play Console → *Store presence
  → Main store listing → Phone screenshots*. Must be 9:16, **each side ≥ 720px**.
- **Listing copy (FR):** app name `Digitronics – Électroménager`; keyword-rich
  short + full descriptions were written for ASO (TV, frigo, lave-linge,
  climatiseur, livraison, paiement à la livraison, Maroc).
- **Advertising ID:** declared **not used** (the app removes the `AD_ID`
  permission on purpose).

---

## 8. Deep links (Android App Links) — still to finish

Tapping a `digitronics.ma` link should open the app. Two things are needed:

1. **Play App Signing SHA-256** → add it to the website's
   `public/.well-known/assetlinks.json`. Get it from Play Console → *App
   integrity → App signing*.
2. **Cloudflare WAF** must stop 403-ing `/.well-known/` for bots (Google's
   verifier is a bot). Add a WAF skip rule for that path.

Detail: [`deep-links.md`](deep-links.md) and [`HANDOFF.md`](HANDOFF.md).

---

## 9. Push notifications — backend note

The app registers its FCM token to `POST /api/v1/push/register` and subscribes to
the `all` topic. **That endpoint + the `app_push_tokens` table live in the
website repo** (`DigiTronics.ma`), because they run on the server — they can't
live here. **The FCM *sender* is not built yet**: tokens are collected, but
nothing sends to them. To send campaigns you need a Firebase service-account key
and a sender (see the website repo's `docs/systems/web-push-notifications.md`).

---

## 10. What lives elsewhere (can't be in this repo)

These are server-side and stay in the **DigiTronics.ma** website repo, but are
listed here so this guide stays complete:

- `assetlinks.json` served at `digitronics.ma/.well-known/` (deep-link proof)
- `POST /api/v1/push/register` + `app_push_tokens` (push token storage)
- the Cloudflare WAF rule for `/.well-known/`

Everything about the **app itself** is in this repo.

---

## 11. Page-load safety net (1.0.13, 24/10/2026)

**Why:** a phone opened the app and stayed on a white screen with the progress
bar frozen at 10 %. The app had no plan for a page that fails: no error
handling, no time limit, no retry, so any failure looked like that.

**What happens now** ([`webview_screen.dart`](../lib/screens/webview_screen.dart)):

1. On the first launch after updating to 1.0.13 the WebView HTTP cache is
   cleared once (`kWebViewCacheEpoch`). Only the cache: the login (cookies) and
   the cart (localStorage) stay. This drops the one-year redirects the website
   could leave on phones between 21/10 and the fix that removed them.
2. The app opens `/fr`, `/ar` or `/en` directly (no redirect hop).
3. A failure is: a network error on the page itself, an HTTP 403/429/5xx on
   the page itself, or 20 s with nothing visible. A slow page that already
   shows something is never replaced, and the site's own 404 page stays.
4. The first failure per launch clears the cache and reloads silently. The
   next one shows "La page ne s'est pas chargée" with **Réessayer** (which
   clears the cache and reloads again). Offline shows the offline screen and
   reloads by itself when the network returns.
5. Every failure, and every recovery, is reported to the website:
   `POST /api/v1/observability/error` with `scope: 'app'`
   ([`load_report_service.dart`](../lib/services/load_report_service.dart)).
   Reports land in the site's system logs as warnings (code
   `error-boundary:app`). A report that cannot be sent (no network) is kept
   and sent after the next page that loads.

**Startup:** the shop starts loading before notifications are set up (they
used to come first and could hold the launch screen on a slow network).

## 12. Testing without a phone

`flutter test` runs [`test/webview_screen_test.dart`](../test/webview_screen_test.dart):
the real screen against a scripted fake WebView (failed page, blank 403, a page
that never arrives, offline launch, links). CI runs it on every push.

## 13. Pending / TODO

- [ ] Deep links: add Play signing SHA-256 to website assetlinks + WAF skip rule.
- [ ] Build the FCM sender (website) to actually send push campaigns.
- [ ] iOS build (not started).
- [ ] Back up the signing keystore + password to a password manager.
