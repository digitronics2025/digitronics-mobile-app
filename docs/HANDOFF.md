# Handoff — what's done & what you need to provide

Everything that can be done in code is done and shipped to the repos. Three
things need values only you can get. **Nothing secret goes in chat** — see the
last section.

## Already done (in the repos)
- App: HTTPS-only, brand-red theme, French offline screen, splash preloads the
  site, notifications deep-link into the right page, FCM token registered to the
  backend, smarter link routing. Validated by CI (`flutter analyze` + tests).
- Website: `POST /api/v1/push/register` + `app_push_tokens` table (deployed);
  `assetlinks.json` now carries the real upload-key fingerprint.
- CI/CD: `ci.yml` (analyze+test every push) and `release.yml` (cloud build of a
  signed `.aab`, optional draft upload to Play).

---

## 1. Ship the improved app — GitHub secrets for the cloud build
Repo → **Settings → Secrets and variables → Actions → New repository secret**:

| Secret | Where to get it |
| --- | --- |
| `GOOGLE_SERVICES_JSON_BASE64` | Firebase Console → Project settings → your Android app (`com.maroc.digitronics`) → download `google-services.json`, then base64 it |
| `ANDROID_KEYSTORE_BASE64` | the `.jks` used to sign v1.0.8 (whoever built it has it), base64'd |
| `ANDROID_KEYSTORE_PASSWORD` | keystore store password |
| `ANDROID_KEY_ALIAS` | key alias |
| `ANDROID_KEY_PASSWORD` | key password |
| `PLAY_SERVICE_ACCOUNT_JSON` | *(optional)* Play Console → Users & permissions → invite a service account with release rights; download its JSON. Only needed to auto-upload. |

Base64 on PowerShell:
```powershell
[Convert]::ToBase64String([IO.File]::ReadAllBytes("google-services.json")) | Set-Clipboard
[Convert]::ToBase64String([IO.File]::ReadAllBytes("upload-keystore.jks"))  | Set-Clipboard
```

Then cut a release (see [ci-release.md](ci-release.md)): bump `pubspec.yaml`
version → `git tag v1.0.9 && git push origin v1.0.9` → download the AAB from the
run's Artifacts (or re-run with **publish** ticked) → promote in Play Console.

## 2. Fix deep links for real users — Play App Signing SHA-256
Play Console → **digitronics → Test and release → App integrity → App signing**
→ under **App signing key certificate**, copy the **SHA-256 certificate
fingerprint**. This value is **public — safe to paste in chat.** I add it as a
second entry in the website `assetlinks.json`.

## 3. Fix deep links at the edge — Cloudflare WAF skip for `/.well-known/`
Google's App Links verifier is a bot; the WAF currently 403s it on that path.
Pick one:
- **Dashboard:** Cloudflare → `digitronics.ma` → Security → WAF → Custom rules →
  add/extend a **Skip** rule (Super Bot Fight Mode) matching
  `http.request.uri.path contains "/.well-known/"`.
- **Or** hand me a short-lived API token scoped **Zone · WAF · Edit** on
  `digitronics.ma`; I'll add the rule and you revoke the token.

## Later (optional) — actually send push campaigns
Token capture is live, but nothing sends yet. To send, I need a **Firebase
service-account key** (Firebase Console → Project settings → Service accounts →
Generate new private key) stored as a Cloudflare secret; then I build the sender.

---

## Do NOT paste in chat
Keystore, `google-services.json`, service-account JSON, API tokens = **secrets**.
Put them in **GitHub secrets** / a **gitignored file** (tell me the path) / or a
**revocable WAF token**. The **Play signing SHA-256 is the only value safe to
paste** — it's public by design.
