# Build a Flutter WebView App for Digitronics.ma

## Overview

Build a Flutter mobile app (Android + iOS) that wraps the **digitronics.ma** e-commerce website in a full-screen WebView. The app should NOT add any custom UI, menus, or navigation — the website itself IS the interface. The app only adds native mobile capabilities that a browser cannot provide.

---

## App Identity

- **App Name:** Digitronics.ma
- **Package Name:** com.maroc.digitronics
- **Base URL:** `https://digitronics.ma`
- **Company:** DigiTronics SARL
- **Language:** French (primary), Arabic (tagline only)
- **Currency:** MAD (د.م.)

---

## Project Structure

```
lib/
├── main.dart                    # Entry point, Firebase init
├── app.dart                     # MaterialApp config
├── firebase_options.dart        # Firebase config (keep existing)
├── constants/
│   └── app_constants.dart       # Base URL, colors, strings
├── screens/
│   ├── splash_screen.dart       # Animated splash intro
│   ├── webview_screen.dart      # Full-screen WebView (main screen)
│   └── offline_screen.dart      # No-internet fallback
├── services/
│   ├── notification_service.dart    # Firebase Cloud Messaging
│   ├── external_link_service.dart   # Route external URLs to native apps
│   └── review_service.dart          # In-app review after N opens
```

---

## Screen 1: Splash Screen

An animated intro that plays once on app launch, then navigates to the WebView screen.

### Design

- **Background:** White or use `assets/Back.jpg` if available
- **Logo:** `assets/logo.png` — slides in from top with fade
- **Brand Name:** "Digitronics.ma" — Poppins font, 30px, bold, fades in with scale
- **Subtitle:** "Best Electronics Store in Morocco" — Poppins, 16px, slides up
- **Arabic Tagline:** "ديجيترونيك بعروضها ترضيك" — Amiri font, 24px, fades in
- **Accent Color:** `#DD3333` (red)
- **Duration:** ~4-5 seconds total, staggered animations
- **Transition:** Fade to WebView screen after animations complete

---

## Screen 2: WebView Screen (Main App)

A **single full-screen WebView** that loads `https://digitronics.ma`. This is the entire app UI — no custom headers, no bottom navigation bars, no floating buttons, no overlays.

### Behavior

- Load `https://digitronics.ma` on launch
- Show a thin **linear progress indicator** at the top while pages load (disappears when done)
- **Back button:** Navigate back in WebView history. If no history, show exit confirmation or double-tap to exit
- Allow the website's own navigation (hamburger menu, links, buttons) to handle all user navigation
- **JavaScript injection:** Optionally inject CSS/JS to hide the website's "download our app" banner if one exists, since the user is already in the app
- Support pinch-to-zoom if the website allows it
- Handle **pull-to-refresh** to reload the current page
- Enable JavaScript, DOM storage, and cookies for full WooCommerce functionality
- Maintain user sessions (login state, cart contents) across pages

### External Link Handling

When the WebView encounters URLs that should open outside the app, intercept and route them:

| URL Pattern | Action |
|---|---|
| `tel:*` | Open phone dialer |
| `mailto:*` | Open email app |
| `sms:*` | Open SMS app |
| `whatsapp://`, `api.whatsapp.com/*`, `wa.me/*` | Open WhatsApp |
| `maps.google.com/*`, `maps.app.goo.gl/*` | Open Google Maps |
| `facebook.com/*`, `fb.com/*` | Open Facebook app or browser |
| `instagram.com/*` | Open Instagram app or browser |
| `twitter.com/*`, `x.com/*` | Open Twitter/X app or browser |
| `youtube.com/*`, `youtu.be/*` | Open YouTube app or browser |
| `tiktok.com/*` | Open TikTok app or browser |
| `play.google.com/*` | Open Play Store |
| Any non-digitronics.ma URL | Open in system browser |

All `digitronics.ma` and `www.digitronics.ma` URLs stay inside the WebView.

---

## Screen 3: Offline Screen

Shown when there is no internet connection. Replaces the WebView screen entirely.

### Design

- **Icon:** WiFi-off icon, large, centered, grey
- **Title:** "Pas de connexion Internet" (No Internet Connection)
- **Subtitle:** "Vérifiez votre connexion et réessayez" (Check your connection and try again)
- **Button:** "Réessayer" (Retry) — red (#DD3333), rounded, taps to check connectivity and reload
- **Auto-reconnect:** Listen for connectivity changes, automatically reload WebView when connection returns

---

## Native Features

### 1. Firebase Push Notifications

- Initialize Firebase on app start using existing `firebase_options.dart` config
- Request notification permissions on first launch
- Register for FCM (Firebase Cloud Messaging) and retrieve token
- Handle foreground notifications: display as local notification using `flutter_local_notifications`
- Handle background notifications: standard FCM background handler
- Handle notification taps: if the notification payload contains a URL, load it in the WebView

### 2. Connectivity Detection

- Monitor network state using `connectivity_plus`
- When offline: show the Offline Screen
- When back online: automatically return to WebView and reload the last URL
- Check connectivity on app resume (coming back from background)

### 3. Deep Linking

- Configure Android intent filters for `https://digitronics.ma` and `https://www.digitronics.ma`
- When the app is opened via a digitronics.ma link, load that specific URL in the WebView
- Enable auto-verification for Android App Links

### 4. In-App Review

- Track app open count using `shared_preferences`
- After 5 app opens, trigger `in_app_review` to prompt for a Play Store / App Store rating
- Only prompt once — store a flag so it doesn't repeat

### 5. Share Support

- If the website triggers a share action, handle it via `share_plus`

---

## Dependencies (pubspec.yaml)

```yaml
dependencies:
  flutter:
    sdk: flutter
  webview_flutter: ^4.10.0
  connectivity_plus: ^6.1.1
  firebase_core: ^3.9.0
  firebase_messaging: ^15.2.0
  flutter_local_notifications: ^18.0.1
  url_launcher: ^6.3.1
  share_plus: ^10.1.4
  in_app_review: ^2.0.10
  shared_preferences: ^2.3.4
  google_fonts: ^6.2.1

dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^5.0.0
  flutter_launcher_icons: ^0.14.2
  flutter_native_splash: ^2.4.3
```

---

## Theme & Styling

```dart
MaterialApp(
  title: 'Digitronics.ma',
  theme: ThemeData(
    colorSchemeSeed: Colors.blue,
    useMaterial3: true,
    brightness: Brightness.light,
  ),
)
```

- **Primary accent:** Blue (Material3 seed)
- **Brand red:** `#DD3333` (splash screen, offline retry button)
- **Fonts:** Poppins (English text), Amiri (Arabic text) via `google_fonts`

---

## Android Configuration

### AndroidManifest.xml Permissions

```xml
<uses-permission android:name="android.permission.INTERNET"/>
<uses-permission android:name="android.permission.ACCESS_NETWORK_STATE"/>
<uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>
```

### Deep Link Intent Filters

```xml
<intent-filter android:autoVerify="true">
    <action android:name="android.intent.action.VIEW"/>
    <category android:name="android.intent.category.DEFAULT"/>
    <category android:name="android.intent.category.BROWSABLE"/>
    <data android:scheme="https" android:host="digitronics.ma"/>
    <data android:scheme="https" android:host="www.digitronics.ma"/>
</intent-filter>
```

---

## Assets

Keep existing assets in the `assets/` folder:

- `assets/logo.png` — App logo for splash screen
- `assets/Back.jpg` — Splash background (optional)
- `assets/icon/app_icon.png` — Launcher icon

---

## Important Constraints

1. **NO custom navigation** — no bottom nav bar, no drawer, no tab bar, no floating action buttons
2. **NO custom UI overlays** on top of the WebView — the website is the entire UI
3. **NO feature additions** beyond what the website already provides
4. **NO product listings, categories, or search UI** built in Flutter — all of that comes from the website
5. The app is simply a native shell that provides: splash screen, push notifications, offline handling, external link routing, deep linking, and in-app review
6. Keep the code clean, well-organized, and maintainable
7. Support both Android and iOS

---

## Key Website URLs (for reference only — NOT for building custom navigation)

These are the URLs the website uses. The WebView will naturally navigate to them through the website's own UI:

- Home: `https://digitronics.ma/`
- Shop: `https://digitronics.ma/shop/`
- Wishlist: `https://digitronics.ma/wishlist/`
- Cart: `https://digitronics.ma/vous-panier/`
- Account: `https://digitronics.ma/mon-compte/`
- Contact: `https://digitronics.ma/contact/`
- Search: `https://digitronics.ma/?s=&post_type=product`

---

## Contact Information (for reference)

- **Phone:** +212 6 60 11 14 38
- **Email:** Contact@digitronics.ma
- **Address:** 30 RUE 9 ETG RC LTS SMARA, Haj Fateh, Oulfa. Casablanca 20230
- **Facebook:** https://www.facebook.com/p/Digitronicsma-100048682913043/
- **Instagram:** https://www.instagram.com/digitronics.ma.official/
- **YouTube:** https://www.youtube.com/@DigiTronics_HajFateh
- **TikTok:** https://www.tiktok.com/@digitronics.ma
