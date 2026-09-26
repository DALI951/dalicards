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

## House rules

Chkobba is not played the same at every table, so the rules are settings:

- deck: French or Italian 40-card pack
- face values: `J=8 Q=9 K=10` (default) or `J=9 Q=8 K=10`
- capture priority: single card beats a sum (default) or best sum wins
- Chkobba on the last card of the round: forbidden (default) or allowed
- deal 3 (default) or 4 · target 11 / 21 / 31 · win by 2 or not
- each scoring category toggleable: Karta, Dīnārī, Barmīla, Sabaa el-Haya, Chkobba
- 2v2 partner mode

Rami: 1 or 2 decks, opening drop 31 / 41 / 51 points, joker rescue, ace-low,
K-A-2 sequences, targets 101 / 201 / 501.

## Build

- every push to `main` → analyze + engine tests + widget tests → web build →
  auto-deploy to GitHub Pages
- every tag `v*` → same gates → signed APK → GitHub Release

Local builds are not supported on purpose: the build machines for this project
are 4 GB Celerons, and `flutter build` needs more RAM than that. CI does it.
