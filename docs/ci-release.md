# CI & Release

Two GitHub Actions workflows keep this app building without a local Flutter setup.

## `ci.yml` — on every push / PR to `main`
Runs `flutter analyze` + `flutter test`. No secrets. This is the safety net that
catches broken Dart before it ever reaches a release build.

## `release.yml` — on a `v*` tag or manual run
Builds a **signed** `.aab` in the cloud and uploads it as a downloadable
artifact. Optionally publishes it to the Google Play **internal** track as a
**draft** (opt-in only — it never auto-rolls-out to production).

### One-time setup — repository secrets
Settings → Secrets and variables → Actions → *New repository secret*:

| Secret | What it is |
| --- | --- |
| `GOOGLE_SERVICES_JSON_BASE64` | base64 of `android/app/google-services.json` (Firebase) |
| `ANDROID_KEYSTORE_BASE64` | base64 of the release keystore `.jks` |
| `ANDROID_KEYSTORE_PASSWORD` | keystore (store) password |
| `ANDROID_KEY_ALIAS` | key alias |
| `ANDROID_KEY_PASSWORD` | key password |
| `PLAY_SERVICE_ACCOUNT_JSON` | *(optional)* Play Developer API service-account JSON — only to auto-upload |

Create a base64 secret on Windows PowerShell:

```powershell
[Convert]::ToBase64String([IO.File]::ReadAllBytes("upload-keystore.jks")) | Set-Clipboard
[Convert]::ToBase64String([IO.File]::ReadAllBytes("google-services.json")) | Set-Clipboard
```

### Cut a release
1. Bump `version:` in `pubspec.yaml` (e.g. `1.0.9+9`).
2. Tag it: `git tag v1.0.9 && git push origin v1.0.9`.
3. The workflow builds the AAB → download it from the run's *Artifacts*, or
   re-run via *Actions → Release Android → Run workflow* with **publish** ticked
   to push a draft to the Play internal track.
4. In the Play Console, review the draft and promote to production.

> The AAB is signed with the **upload key**. Google Play App Signing re-signs it
> with the app signing key before distributing to users — that app signing
> certificate's SHA-256 is what must go in the website's `assetlinks.json` for
> deep links to verify.
