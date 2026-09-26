# DaliCards

Tunisian card games in one app. **Chkobba** and **Rami** — solo against a bot,
hotseat on one phone, or online with a friend through a shared link.

Desktop, phone (PWA) and Android APK all come out of **one** Flutter codebase,
built automatically by GitHub Actions.

| | |
|---|---|
| Web (desktop + phone) | `https://dali951.github.io/dalicards/` |
| API (online play) | `https://modali.powerpme.com/dalicards-api/` |
| Android APK | GitHub Releases, `DaliCards-vX.Y.Z.apk` |
| Plan | [PLAN.md](PLAN.md) |
| Progress | [MILESTONES.md](MILESTONES.md) — what is done, how it was verified, what is still open |

## Architecture

```
packages/engine/   pure Dart rules engine - zero Flutter imports, unit tested,
                  seeded so any match replays exactly (the online event log
                  depends on that)
lib/              Flutter app: game hub, tables, lobby, friends
api/              PHP + MySQL online play: rooms, event log, friend codes
```

**Online play is polling, not websockets.** Every move is an event with a
sequence number; the client asks for `events since <seq>` every 1.2s. That
means reconnecting is free, nothing desyncs, and it works on ordinary shared
hosting. The server is authoritative and never sends another player's hand.

## What works today

- **Chkobba is playable**, offline: solo against a bot on three levels, or
  hotseat on one phone with the hand kept hidden between turns. Deal, capture,
  Chkobba, score, race to the target.
- **Rami's engine is done and tested**; its table is the next milestone (M5).
- **Online play** is not up yet. The API design is settled in
  [PLAN.md](PLAN.md) §10a and the engine already speaks the seeded, replayable
  event log it will need.

Everything below describes what the *engine* supports, which is deliberately
wider than what is on screen today — the rules were built variant-first so the
UI could be a set of flags instead of a rewrite.

## House rules

Chkobba is not played the same at every table, so the rules are settings:

- deck: French or Italian 40-card pack
- face values: `J=8 Q=9 K=10` (default) or `J=9 Q=8 K=10`
- capture priority: single card beats a sum (default) or best sum wins
- Chkobba on the last card of the round: forbidden (default) or allowed
- deal 3 (default) or 4 · target 11 / 21 / 31 · win by 2 or not
- each scoring category toggleable: Karta, Dīnārī, Barmīla, Sabaa el-Haya, Chkobba
- 2v2 partner mode

Rami is one 108-card double deck (2×52 + **4 jokers**), 14 cards each, two
players. Values J/Q/K = 10, A = 11, joker = 20 — deliberately different from
Chkobba's face values. Melds are *tirsi* (3–4 of a rank) or *suivi* (3+
consecutive of one suit), with **at most one joker per meld**, and a meld
containing a joker does not count as franc. **Ace is low, so K-A-2 is not a run.**
The opening drop is a setting — 51 / 61 / franc-only 71 ("Tallage") / none — and
a card taken from the discard cannot be dropped straight back. Scoring: going out
is free, losers pay their deadwood, and **a player who never melded pays a flat
100**; lowest cumulative total wins, match target 1000.

## Build

- every push to `main` → analyze + engine tests + widget tests → web build →
  auto-deploy to GitHub Pages
- every tag `v*` → same gates → signed APK → GitHub Release

Local builds are not supported on purpose: the build machines for this project
are 4 GB Celerons, and `flutter build` needs more RAM than that. CI does it.
