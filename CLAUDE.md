# CLAUDE.md — digitronics-mobile-app

The single source of truth for this repo is [docs/GUIDE.md](./docs/GUIDE.md) —
read it before changing anything. Release flow and CI are in
[docs/ci-release.md](./docs/ci-release.md). Flutter is NOT installed locally;
the cloud builds everything (push runs checks; a `v*` tag builds the release).

## Fleet manifest — FLEET.md

[FLEET.md](./FLEET.md) at the repo root describes what this app consumes from
the other TenTen apps (fleet map: claude-config → `skills/tenten-fleet`).
**Any commit that changes a cross-repo contract — the push-register call in
`lib/services/notification_service.dart`, the URL map in
`lib/constants/urls.dart`, or the deep-link assets — must update FLEET.md in
the same commit.** Before changing any such surface, check the fleet index for
the other side of the contract (the server half lives in the DigiTronics.ma
repo).
