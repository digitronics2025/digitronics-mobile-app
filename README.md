# digitronics-mobile-app

Official Android app for **digitronics.ma** — a Flutter WebView shell of the
website plus native features (splash, push notifications, offline screen,
deep links, in-app review).

## 📖 Start here

**[docs/GUIDE.md](docs/GUIDE.md) — the complete guide.** Everything about this
app in one place: how to change anything, how to release, where the credentials
live, CI/CD, design, the Play listing, and what lives in the website repo.

## Quick reference

- **Change something & ship it:** edit code → push to `main` → bump version in
  [`pubspec.yaml`](pubspec.yaml) → `git tag vX.Y.Z && git push origin vX.Y.Z` →
  the cloud builds a signed app → download from **Actions → Artifacts** → upload
  the `.aab` in Play Console. Full flow: [docs/GUIDE.md §2](docs/GUIDE.md).
- **Release detail & required secrets:** [docs/ci-release.md](docs/ci-release.md)
- **Credentials & handoff items:** [docs/HANDOFF.md](docs/HANDOFF.md)
- **Deep links (App Links) setup:** [docs/deep-links.md](docs/deep-links.md)

## Layout

```
lib/            Dart source (screens/, services/, constants/)
android/        Android project (signing reads android/key.properties)
assets/         icon/, splash/, logo
.github/workflows/  ci.yml (analyze+test), release.yml (signed build)
docs/           GUIDE.md + ci-release, deep-links, HANDOFF
```

> No local builds — Flutter isn't installed here; GitHub Actions builds and signs
> every release. Secrets live in GitHub Actions + a gitignored `.env` (never
> committed).
