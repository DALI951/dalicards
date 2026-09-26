# DaliCards — PLAN

**One app. Pick a card game. Play it solo, hotseat, or online with a friend via link.**

- Repo: `DALI951/dalicards`
- App name: **DaliCards** · package `ai.dalicards`
- Web (desktop + phone PWA): `https://dali951.github.io/dalicards/`
- API (online play): `https://modali.powerpme.com/dalicards-api/`
- APK: GitHub Releases `DaliCards-vX.Y.Z.apk`

---

## 1. Games in scope

| Game | Status | Notes |
|---|---|---|
| **Chkobba** (شكبة) | v1 — first | 40-card fishing, sweep game, 1v1 or 2v2, bot + online |
| **Rami** | v2 — second | 2 decks + jokers, melds, opening 51 pts, 2–4 players |
| **Belote** | v3 — only if you want | 32-card trick game, 2v2 or 4 |
| _future_ | plug-in slot | each game = one folder + one registry line |

**Game hub** is the landing screen: pick game → pick mode (Solo vs Bot / Hotseat / Online) → pick variant → play.

---

## 2. Tech stack (and why)

| Layer | Choice | Why |
|---|---|---|
| Shared rules engine | **Pure Dart package** (`packages/engine`), zero Flutter imports | Runs headless → testable in seconds, shared by app + server-side sim |
| App UI | **Flutter** (single codebase) | One codebase → Android APK **and** web/desktop PWA. Animations, drag, haptics. Matches your existing DaliDeck/Mini-Games CI pattern. |
| Local play | Engine runs 100% on-device | Works fully offline, no server, no account |
| Online play | **PHP 8 + MySQL API** on your existing `modali.powerpme.com` | You already run PHP + MySQL + SFTP deploy there. Turn-based game → **polling, no websockets needed** (cPanel-safe) |
| Real-time | **Event-log polling** (1.2s) | Reconnect-safe, no state desync, survives phone sleep, ~0 cost |
| Identity | Guest ID + optional account with 6-char **friend code** | No passwords for casual play; code = "add me" |
| Builds | **100% GitHub Actions** | Your N4020 has 4GB RAM — `flutter build` would OOM. CI is the right place anyway. |
| Local dev loop | Dart SDK only (250MB) + headless Chrome screenshots | Fast `dart test` locally; UI verified from CI-built web bundle via screenshots |

---

## 3. Repo layout

```
DALI951/dalicards/
├─ packages/engine/            # pure Dart, no Flutter — THE RULES
│  ├─ lib/src/cards.dart       # Card, Suit, Rank, Deck (40 + 104), values
│  ├─ lib/src/chkobba/         # state machine, captures, chkobba, scoring
│  ├─ lib/src/rami/            # melds, opening drop, jokers, deadwood
│  ├─ lib/src/bots/            # chkobba_bot, rami_bot
│  ├─ lib/src/variants.dart    # tunable rule flags per table
│  └─ test/                    # unit + golden + 10k self-play fuzz
├─ lib/                        # Flutter app
│  ├─ ui/hub/                  # game picker
│  ├─ ui/chkobba/  ui/rami/    # tables
│  ├─ ui/net/                  # lobby, friends, room, invite link
│  ├─ net/api.dart             # REST client
│  ├─ engine_bridge.dart       # dart:ui-free glue
│  └─ l10n/                    # EN / AR / FR (+ Tunisian dialect labels)
├─ web/                        # PWA manifest, service worker, icons
├─ api/                        # PHP: schema.sql, api.php, deploy notes
├─ .github/workflows/ci.yml    # analyze + test + build web
├─ .github/workflows/apk.yml   # signed APK + release on tag
└─ tool/                       # icon gen, screenshot harness, seed data
```

---

## 4. How online play actually works (the important part)

**Server-authoritative + event log.** No shared mutable state guesswork.

```
Client                                   Server (PHP + MySQL)
──────                                   ───────────────────
POST create_room  {game,variant}    →   room_id, invite_code
GET  join?code=ABC123             →   seat assigned, token stored
POST act {room, token, seq, action} →   validate → apply → append event(seq+1)
GET  poll?room&since=<seq>        →   only events after seq  ← every 1.2s
```

- Every move is an **event** with a sequence number: `deal`, `play`, `capture`, `chkobba`, `draw`, `meld`, `discard`, `score`, `chat`, `rematch`.
- Client polls `since=seq` → gets only what's new → applies to its local engine copy.
- **Reconnect = just re-poll.** Close the app, reopen, still in the game, nothing lost.
- **No card leaks:** the API only ever returns *your* hand + opponents' card **counts**. Captured piles are public counts. Verified with a test that greps every response for hidden card IDs.
- **Stall-proof:** 45s turn timer → auto-play. 2min disconnected → a bot takes over the seat and says so. Game never dies because someone's phone died.
- **Invite:** link `…/dicards/#/r/ABC123` + a 6-char code to type. Also "copy invite" button + share sheet on phone.
- **Friends:** code `DALI-7K2M` → add → friends list with online dot → one-tap "invite to Chkobba".

---

## 5. Chkobba rules engine spec

Base: 40-card deck, deal 3 each + 4 on table, play one, capture on single-value **or** sum-of-several, re-deal 3 each, last capturer sweeps.

**Variant flags** (because every table in Tunisia plays slightly differently — this is a real differentiator):

- `deck`: french40 | italian40
- `faceValues`: J=8,Q=9,K=10 (default) **or** J=9,Q=8,K=10 (jack/queen swapped)
- `capturePriority`: single-first (default) | best-sum
- `chkobbaOnLastCard`: forbidden (default) | allowed
- `dealSize`: 3 (default) | 4
- `target`: 11 | 21 | 31 · `winByTwo`: on (default) | off
- `score toggles`: Karta (most cards) · Dīnārī (most ♦) · Barmīla (most 7s, 6s break tie) · Sabaa el-Haya (7♦) · +1 per Chkobba
- edge case: reshuffle & redeal if the opening 4 table cards contain 3–4 of one rank
- 2v2 partner mode

**Test checklist (each = one unit test):** rank capture · sum capture · single-beats-sum priority · no-match leaves card · multi-card sums · Chkobba detection + scoring · dealer-last-card rule · final sweep to last capturer · each of the 5 score categories + ties + Barmīla tiebreak · target + 2-point lead + "continue rounds on tie" · redeal rule · 2v2 partner sum.

## 6. Rami rules engine spec

**Shipped in M2** (`packages/engine/lib/src/rami.dart`, 106 tests green in CI run 36255639301).

2 decks (104) + **4** jokers = **108 cards**, 14 each, draw → meld → discard.
- Meld: set of 3–4 same rank · run of 3+ same suit · **K-A-2 forbidden** (ace is low) · 1 joker per meld · a meld needs at least one natural card
- A meld using a joker is **not franc**
- Opening drop ≥ **51** points (flags ship: 51, 61, and franc-only **71** Tallage, plus a no-threshold simple variant)
- Values: pips at face value, **J/Q/K = 10, A = 11, joker = 20** (note: *not* Chkobba's J=8/Q=9/K=10)
- Can add to your own melds; others' melds too while the table is open (`openMelds`, `progressiveMelds` flags)
- A card taken from the discard cannot be dropped straight back (`mustUsePickedDiscard`)
- Golf scoring: going out is free · losers pay their deadwood · **a player who never melded pays a flat 100** · lowest cumulative total wins, match target 1000

**Open questions** (still house rules, decided at the table, all flag-configurable):
- 51 vs 61 vs 71 opening, and progressive vs locked melds
- whether a run may exceed 7 cards (`maxMeldSize`, default 7)
- match target 1000 (lowest-wins) vs a highest-wins match

**Tests:** every meld shape valid/invalid · joker in each position · duplicate double-deck cards in a set · ace-low and K-A-2 rejection · gap-bridging · opening threshold at 51/61/71 · picked-discard rule · snapshot round trip incl. joker layouts · golf scoring and the 100 penalty · **fuzz: 200 full rounds asserting all 108 cards survive every action**.

## 7. Bots (playable offline, no server)

- **Chkobba bot:** 3 levels. Reads table → enumerates all capture options (singles + subset sums) → scores each by (cards taken + ♦ + 7s + chkobba potential) with 1-ply lookahead of opponent's best reply. *Easy* = 40% random picks, *Normal* = greedy, *Hard* = greedy + card counting.
- **Rami bot:** meld evaluator (value of getting rid of cards) + deadwood-minimising discard + opening-drop planner that respects the 51-pt + clean-meld rule. Hard mode = 2-ply over your own possible melds.
- **Verification:** engine fuzz test = **10,000 bot-vs-bot self-play games**, assert: no crash, no deadlock, all 40/106 cards accounted for, score total always consistent. Seeded → reproducible.

## 8. Design (your taste skill)

Dark cinema: `#0A0A0F` bg, one red accent `#DC2626`, cards `#1A1D26`, hairline borders, rounded-xl, Inter/Amiri. No clutter.
- **Cards drawn in code** (vector `CustomPainter`, no image assets) → crisp at any zoom, tiny APK, zero licensing issues, 40-card + 104-card decks from one painter.
- **The Chkobba moment:** full-screen flash + haptic + "CHKOBBAAA!" in Tunisian Arabic, screen shake, table clears.
- Layouts: phone portrait (stacked) and desktop wide (table in centre, hands at the bottom, captured piles as side columns) — same widgets, responsive.
- i18n EN / AR (RTL) / FR, plus Tunisian dialect strings for the flavour lines.

## 9. CI/CD (GitHub does everything)

**`ci.yml` — every push/PR**
1. `flutter pub get` → `dart analyze` (zero warnings gate) → `flutter test` (engine + widget tests)
2. `flutter build web --release` → deploy to **GitHub Pages** (`dali951.github.io/dalicards`)
3. Headless-Chrome screenshot job → I visually verify the UI without a local build
4. MySQL migration dry-run (PHP lint against the API copy)

**`apk.yml` — on tag `v*`**
1. same gates, then `flutter build apk --release`
2. keystore from repo **secrets** (KEYSTORE_B64 / PASS / ALIAS / KEY_PASS) — never in the repo
3. `zipalign` + `apksigner` → attach `DaliCards-vX.Y.Z.apk` to a GitHub Release
4. Version auto-read from `pubspec.yaml`; release notes auto-generated from the commits

## 10. Server work (modali.powerpme.com)

```
/public_html/dalicards-api/
├─ api.php          # one front controller, op= routing (dalideck pattern)
├─ schema.sql       # players, friends, rooms, events, matches
└─ .htaccess        # deny direct db/ access
```
Tables: `players` (id, code, name, created, last_seen) · `friends` (a,b,status) · `rooms` (id, code, game, variant, state_json, host, created) · `events` (room, seq, type, payload, at) · `matches` (history + ELO).
- MySQL creds reused from your existing setup, stored as **GitHub secrets** + a local gitignored `api.local.php`.
- Deploy via the proven SFTP script pattern (`deploy_dalicards.py` style), then live-verify with a real create→join→play→poll round trip.
- Housekeeping: prune rooms idle > 24h, prune events of finished rooms, cap `state_json` size.

### 10a. Keeping the PHP server honest about the rules (parity)

**The problem:** the rules live in Dart (`packages/engine`). PHP cannot run it, so a
PHP re-implementation would be a second source of truth that silently drifts — the
classic way an online game ends up rejecting moves the offline game allows.

**The rule: the server never re-implements the rules.**

- The Dart engine stays authoritative. Every room stores a **snapshot** (`state_json`)
  plus an ordered **event log**. The server only: authenticates the seat, checks the
  move is *well-formed*, appends the event, bumps `seq`, and returns the new snapshot.
- Legality is **not** re-derived on the server. It is derived when the log is
  *replayed* in Dart (offline audit, anti-cheat sweep, bug reports).
- One canonical JSON shape for a round, owned by Dart: `RamiState.toJson()` /
  `ChkobbaState.toJson()`. PHP treats it as opaque.
- **Shared fixtures are the contract.** A folder of frozen snapshot + expected
  next-state pairs is committed, generated *by Dart*. Both sides must pass:
  - Dart test: replay each fixture, assert it reaches the expected state.
  - PHP test: for each fixture, apply the same event to `state_json` and assert the
    server accepts it and that the snapshot it persists round-trips byte-identical.
  - A fixture that only one side passes is a CI failure, so drift is caught the
    moment either engine changes — not weeks later in an online match.

**Consequence to accept deliberately:** the server cannot reject an illegal move on
its own. Mitigated by the event log being append-only and auditable, and by the
client being the only thing players talk to. Revisit if cheating ever becomes real.

## 11. Build order (each phase ends with something verified)

| # | Phase | Done when |
|---|---|---|
| **M0** | Env setup | ✅ Dart/Flutter is **CI-only** (local box has none), repo created, `.gitignore` + CI skeleton green, MySQL probe returns rows |
| **M1** | Chkobba engine | ✅ 62 tests + 300-game fuzz, CI `36250880360` green, Pages live |
| **M2** | Rami engine | ✅ 106 tests incl. 200-game fuzz, CI `36255639301` green |
| **M3** | Flutter shell + hub | ✅ EN/AR/FR + RTL, real `/game/:id` navigation, 16 widget tests, CI `36257878142` green, 4 screenshots, Pages live |
| **M4** | Chkobba UI + offline | Full game playable vs human (hotseat) and vs 3 bot levels, sound/haptics, Chkobba flash |
| **M5** | Rami UI + offline | Full game playable, meld drag/select, opening-drop validation UX |
| **M6** | API + auth + friends | Guest login, friend codes, add friend, online presence, live round trip verified over real HTTP |
| **M7** | Online Chkobba | Create room → share link → friend joins → play to completion on two devices, reconnect tested |
| **M8** | Online Rami | Same, incl. 4 seats + bot fill |
| **M9** | CI + Pages + APK | Green CI, web live on Pages, signed APK in Releases, installed on your phone |
| **M10** | Polish | ELO + match history, haptics, settings, README, portfolio entry, `UNSURE`s resolved |

## 12. Risks + the fallback I already picked

| Risk | Fallback |
|---|---|
| `flutter build` OOMs on the N4020 | Already assumed — **all builds in CI** |
| Flutter web slow on the old laptop/Celeron | Keep widget tree light; if CanvasKit crawls, the PWA falls back to a plain-HTML build; APK unaffected |
| cPanel blocks long-lived sockets | Design is polling-based from the start — no websockets anywhere |
| MySQL quota / shared hosting slowness | Rooms are tiny; poll returns only new events. Fallback = SQLite file via PDO (same schema file) |
| Chkobba variants differ by region | Already handled by variant flags — a *feature*, not a bug |
| Phone sleeps mid-turn | Turn timer + reconnect + bot takeover |

## 13. What I need from you (3 things, then I start)

1. **Go** on this plan (or tell me what to change).
2. **Chkobba house rules at your table** — J/Q/K values (8/9/10 or 10/9/8), deal 3 or 4, target 11 or 21. I'll ship flag toggles so any answer works.
3. **Keystore** — reuse the dalideck-app one, or a fresh keystore for DaliCards (my default: fresh, so DaliCards signing is independent).

## 14. Definition of done

- Pick a game from the hub → play Chkobba or Rami vs a friend online via a shared link, on phone **and** desktop.
- Every push → CI green → web live automatically. Every tag → signed APK in Releases.
- Works fully offline for solo/hotseat.
- Engine provably correct: full rule tests + 10k self-play games.
- No secrets in the repo, no card leaks from the API.
