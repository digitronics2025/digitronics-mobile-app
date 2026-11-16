# Previous project instructions

Historical architecture and operating evidence, preserved at 9bc58f6c600f2e3d18a89b14944e38573226514b.
Current process and authorization are exclusively in [the authored contract](../agent-contract.md).
Past approvals are not permission. Verify dated facts against current code.
Read relevant sections only; paths below have been rebased for this reference.

## Previous AGENTS.md project material

# digitronics-mobile-app — agent contract

Rules specific to this repo go above the managed block below.

## Previous CLAUDE.md project material

# CLAUDE.md — digitronics-mobile-app

The single source of truth for this repo is [docs/GUIDE.md](../GUIDE.md) —
read it before changing anything. Release flow and CI are in
[docs/ci-release.md](../ci-release.md). Flutter is NOT installed locally;
the cloud builds everything (push runs checks; a `v*` tag builds the release).

## Fleet manifest — FLEET.md

[FLEET.md](../../FLEET.md) at the repo root describes what this app consumes from
the other TenTen apps (fleet map: claude-config → `skills/tenten-fleet`).
**Any commit that changes a cross-repo contract — the push-register call in
`lib/services/notification_service.dart`, the URL map in
`lib/constants/urls.dart`, or the deep-link assets — must update FLEET.md in
the same commit.** Before changing any such surface, check the fleet index for
the other side of the contract (the server half lives in the DigiTronics.ma
repo).

---

