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

---

<!-- BEGIN operator-conventions: managed block, regenerated from digitronics2025/claude-config -->
## Reply contract — every task-closing reply

Close every task-closing reply with these three, in this order, and nothing after them:

1. A plain recap, **3 sentences max** — no paths, hashes or jargon ("saved" not
   "commit", "sent live" not "deploy"). Shipped work may instead use the five-part
   form (what changed / what was wrong / before → after / what it gets you /
   what's next), ~180 words.
2. A **Grandma summary** — 2-4 plain sentences, no tool, file, product or model
   names, saying what it means for the shop rather than what was done. Unverified
   stays unverified: "it should be sorted, I'm waiting to see it with my own eyes".
3. A **What you need to do** block — numbered steps (1-5), each naming the exact
   button to tap and what they should see, or exactly `Nothing — you're all set.`
   Never empty, never "just" or "simply". Anything the user must do goes ONLY here.

"skip recap" silences 1 and 2; 3 still appears whenever it has content. "details"
drops the cap on 1 and never removes 2 or 3. None of it applies to answers to
technical questions, code, plans, commit messages or PR bodies.

On any open design choice prefer, in order: **maintainable > scalable > secure >
production-ready > sustainable**, and record the trade-off in the commit message,
not a code comment.

Only git-tracked files in THIS repo, plus account-level skills, reach a session
that is not on the operator's own PC. Never write an instruction pointing at a
path outside this repo — `~/.claude/...`, `C:\Users\...` — without marking it
machine-local, or it reads as mandatory and silently cannot be followed.

Canonical source, and the rules that are conditional rather than always-on:
[digitronics2025/claude-config](https://github.com/digitronics2025/claude-config)
<!-- END operator-conventions -->
