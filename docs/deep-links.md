# Android App Links Setup

The Android app already claims these verified hosts in [`android/app/src/main/AndroidManifest.xml`](../android/app/src/main/AndroidManifest.xml):

- `https://digitronics.ma`
- `https://www.digitronics.ma`

The Play Console warning is caused by the website not serving a valid Digital Asset Links file yet.

Since app 1.0.13 the app opens the tapped page itself (not the home page): Flutter hands the link to [`lib/services/link_router.dart`](../lib/services/link_router.dart), which accepts only `https://digitronics.ma` / `www` pages.

## File To Deploy

Deploy [`/.well-known/assetlinks.json`](../.well-known/assetlinks.json) to:

- `https://digitronics.ma/.well-known/assetlinks.json`

`https://www.digitronics.ma/.well-known/assetlinks.json` may keep redirecting to the apex domain as long as the final destination returns `200 OK` with the JSON file above.

## Required Edit Before Deploy

Replace `PLAY_SIGNING_SHA256` in [`/.well-known/assetlinks.json`](../.well-known/assetlinks.json) with the Play App Signing certificate fingerprint from Google Play Console.

The local upload key already present in this repo is:

`3C:06:E4:3D:77:5A:1E:57:1D:6C:7D:0C:84:87:9E:2D:0D:9E:09:F2:DA:01:7C:51:E8:74:DE:99:CD:A2:DA:65`

## Verification

After the file is live:

1. Open `https://digitronics.ma/.well-known/assetlinks.json` and confirm the response is raw JSON, not a WordPress 404 page.
2. Check the Deep Links page in Play Console and wait for host re-verification.
3. Optionally run:

```powershell
adb shell pm verify-app-links --re-verify com.maroc.digitronics
adb shell pm get-app-links com.maroc.digitronics
```
