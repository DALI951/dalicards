# DaliCards — Milestones

Running log of what actually shipped, how it was verified, and what is still open.
`PLAN.md` is the plan of record; this file is the truth of what is **done**.

**Verification rule for this repo:** there is no Dart/Flutter SDK on Dali's PC
(i7-4790K / GTX 1650, and the secondary Celeron N4020 is far worse). Everything
is built and tested by GitHub Actions. **A milestone is not done until CI is
green** — `flutter analyze` treats info-level lints as failures, so the target
is zero findings, not zero errors.

Live app: <https://dali951.github.io/dalicards>

---

## Status

| # | Phase | State | Proof |
|---|---|---|---|
| M0 | Env setup | ✅ done | CI green, MySQL probe returns rows |
| M1 | Chkobba engine | ✅ done | 62 tests + 300-game fuzz, CI `36250880360` |
| M2 | Rami engine | ✅ done | 106 tests incl. 200-game fuzz, CI `36255639301` |
| M3 | Flutter shell + hub | ✅ done | 16 widget tests, CI `36257878142` |
| M4 | Chkobba UI + offline | ✅ done | 117 engine tests incl. 10k-match bot fuzz, 44 widget tests |
| M5 | Rami UI + offline | ⬜ | engine is ready; needs meld UX |
| M6 | API + auth + friends | ⬜ | design settled in PLAN.md §10a |
| M7 | Online Chkobba | ⬜ | |
| M8 | Online Rami | ⬜ | |
| M9 | CI + Pages + signed APK | ⬜ | keystore already provisioned |
| M10 | Polish | ⬜ | |

---

## M3 — Flutter shell + hub ✅

**CI run `36257878142`, head `bb0ed52`, fully green:** 106 engine tests + 16
widget tests + `flutter analyze` + web build + 4 screenshots + Pages deploy.

### What shipped

| File | Role |
|---|---|
| `lib/l10n/app_strings.dart` | EN/AR/FR strings, `?lang=` query override, `AppState` + `AppScope` |
| `lib/games/registry.dart` | `GameStatus` (`playable` / `tableInProgress` / `planned`), `GameEntry`, named `/game/:id` routes |
| `lib/ui/game/table_screen.dart` | Landing screen a table route opens; says honestly what is not built yet |
| `lib/ui/hub/hub_screen.dart` | Rewritten hub: hero, game tiles, language picker, online card |
| `test/hub_test.dart` | 16 tests: navigation, i18n, RTL, responsive, locale switching |

Honest status is deliberate: Chkobba and Rami engines are **done**, but their
tables land in M4/M5, so the registry reported `tableInProgress` back then, and
Belote is `planned`. Nothing on screen claims to be playable before it is. **M4
has since landed the Chkobba table, so Chkobba now reports `playable`.**

## M4 — Chkobba table, playable offline ✅

Chkobba is a real game in the app now, not a placeholder. Deal it, play it,
lose to the bot, and watch the table.

### What shipped

| File | Role |
|---|---|
| `packages/engine/lib/src/bots/chkobba_bot.dart` | Three levels (`easy` / `normal` / `hard`), seeded, reads only its own hand |
| `packages/engine/test/chkobba_bot_test.dart` | 11 tests: legality on every level, self-play fuzz over **10,000 full matches** |
| `lib/ui/cards/playing_card.dart` | Cards and suits drawn as vectors — no image assets, any DPI, one accent red |
| `lib/ui/chkobba/chkobba_controller.dart` | Owns the engine state, drives the bot on a timer, raises the Chkobba flash, one single `_commit` path for both players |
| `lib/ui/chkobba/chkobba_setup.dart` | Opponent, bot level, and four house-rule flags before the deal |
| `lib/ui/chkobba/chkobba_table.dart` | The table: opponent, table pile, your hand, capture chooser, round panel, the shout |
| `test/chkobba_controller_test.dart` | 16 tests: hotseat privacy, full match to a winner, redeal, shareable setup links |
| `test/chkobba_table_test.dart` | 12 tests: dealing, tapping, a whole round, EN/AR/FR, RTL, 320px phone, desktop |

### Rules it plays

Dali's table defaults, all of them flags in the setup screen: **J=8, Q=9, K=10,
deal 3, target 21, win by 2, a single capture beats a sum, no Chkobba on the
final card.** Swapped faces, target 31 or 11, deal 4, and "you pick the best
capture" are one tap away, because every one of them is a `ChkobbaRules` field
the engine already had.

### Two bugs the tests caught, worth remembering

1. **The whole screen was 0px wide.** `Scaffold.body` hands out *loose*
   constraints, and a `Stack` whose children are all `Positioned` sizes itself
   to `constraints.smallest`. The table needed `fit: StackFit.expand`. Nothing
   looked wrong in the widget tree; it only showed up as a `Row` overflow.
2. **The player's own Chkobba was silent.** The shout was raised in the human's
   `playCard` and in the bot's path separately, and one of them dropped the
   `ChkobbaMove` on the floor — so a sweep the player earned played no sound
   and no flash. Both paths now go through one `_commit`, because a rule
   implemented in two places is a rule implemented in one place minus the tests.

### Deliberately not in M4

- **2v2 partner play.** The engine supports seats and teams, but only the 1v1
  paths are tested, so only 1v1 ships. The variants are ready for M7 online.
- **Audio.** There are no sound assets in the repo and none were invented, so
  the Chkobba moment is haptic plus the red flash plus the shout. Sound is a
  M10 question, not an M4 gap.

### How to check it yourself

1. Open <https://dali951.github.io/dalicards> and tap **Chkobba** — it is the
   only tile marked PLAYABLE.
2. Pick **Solo vs bot** and a level, then **Deal the cards**.
3. Tap a card in your hand. A card with two legal captures asks which one.
4. `?lang=ar` mirrors the whole table, and the shout is written in Arabic.

### How to check it yourself

1. Open <https://dali951.github.io/dalicards> — English hub.
2. Append `?lang=ar` — full RTL: content starts from the right edge, chevrons
   point left.
3. Append `?lang=fr` — French.
4. Use the 🌐 button in the app bar to switch language live.
5. Tap **Chkobba** or **Rami** — routes to `/game/chkobba`, `/game/rami`.
   **Belote** is locked and says so.
6. Screenshot evidence is attached to every CI run as the `web-shots` artifact:
   `desktop`, `phone`, `phone-ar`, `desktop-fr`.

```powershell
gh run view 36257878142 --repo DALI951/dalicards
gh run download 36257878142 --repo DALI951/dalicards --name web-shots --dir shots
```

### Three bugs worth remembering

M3 took five CI rounds, and every failure was a mistake of mine that the log
did **not** point at. The transferable lesson: *on a no-SDK machine a vague
error costs a full CI round, so widen the net before pushing — fix the whole
class of error, and make the test name the culprit instead of guessing twice.*

1. **Real app bug — a rebuilt root ignored a new locale.** `AppState` was only
   initialised in `initState`, so pumping the root with a different
   `initialLocale` reused the existing `State` and the app **silently stayed in
   the old language**. Caught by the RTL chevron test. Fixed in `didUpdateWidget`
   with a post-frame callback, because notifying the `ListenableBuilder` during
   the build phase marks a descendant dirty and trips a Flutter assert.
2. **Real layout bug — 20 px overflow at 320 pt.** The two online buttons were a
   fixed `Row`; with the longer Arabic labels they did not fit. They are now a
   `Wrap`, and the game name, status chip and online-card title are all
   `Flexible`/`Expanded` with `TextOverflow.ellipsis`, so no rigid `Text` in a
   `Row` can push it over.
3. **Import resolution.** Relative `lib/` imports failed with `Target of URI
   doesn't exist` for files that were demonstrably committed *and* being
   analyzed. Everything inside `lib/` now uses `package:dalicards/...`, which
   removes the entire class.

### Conventions this repo now follows

- **`package:dalicards/...` imports only** for anything inside `lib/`.
- **CI is the only compiler.** `flutter create` runs in CI, never locally, and a
  guard step checks all six `lib/` files by name and prints `git ls-files lib`,
  so a clobbered or missing file fails with the real reason.
- **Layout tests use a tall viewport** (`tallPhone = Size(412, 1800)`).
  `ListView` never builds off-screen children and the EN/AR/FR heroes wrap to
  different heights, so a phone-height box makes finders depend on which
  language is under test.
- **`expectNoRowOverflow(tester)`** is the overflow guard. `tester.takeException()`
  only reports "a RenderFlex overflowed by N pixels" and never names the widget;
  this helper walks each horizontal `Row`'s children via
  `firstChild`/`childAfter` (`RenderFlex` has no public `children` list) and fails
  with the widget and the exact pixel overage.

---

## Open items

- **[needs one human glance]** Pixel analysis of the M3 screenshots shows one
  element drawing full-bleed with a 17 pt inset (ink spans x=34..2846 of 2880 on
  desktop, with zero ink within 3 px of any edge). The 720 pt content cap itself
  is correct — the online-card band measures a centred 1360 px = 680 pt — so this
  is most likely an intentionally wide `BoxShadow` or gradient. Confirm it is
  deliberate and not a stray glow.
- **[UNSURE]** Rami opening threshold: ship **51** as the default, or **61**?
  Both are implemented as flags in `RamiRules`, so nothing is blocked — only the
  default needs confirming.
- **[UNSURE]** Rami house rules still open and all flag-driven: 51 vs 61 vs 71
  ("Tallage"), progressive vs locked melds, and whether a run may exceed 7 cards.
- **Rotate the shared-host credential.** It is stored in plaintext in this
  agent's private memory from an earlier session. Rotate it on the host and scrub
  the stored copy. No credential has ever been committed to this repo.

---

## M2 — Rami engine ✅

**CI run `36255639301`:** 106 tests, including a 200-round fuzz asserting all 108
cards survive every action.

Shipped rules: **108 cards** (2×52 + **4 jokers**), 14 each, 2 players. Values
J/Q/K = 10, A = 11, joker = 20 — deliberately different from Chkobba's face
values. Meld is *tirsi* (3–4 same rank; the two copies of a card may both be
used) or *suivi* (3+ consecutive, one suit). **Ace is low, so K-A-2 is illegal.**
Max one joker per meld, and a meld containing a joker is not franc. Opening
threshold is a flag: 51 / 61 / franc-only 71 / none. A card picked from the
discard cannot be discarded straight back. Going out is free; losers pay their
deadwood; **a player who never melded pays a flat 100**; lowest cumulative total
wins, match target 1000.

## M1 — Chkobba engine ✅

**CI run `36250880360`:** 62 tests + a 300-game fuzz.

Dali's ruling: J=8 Q=9 K=10, deal 3, target 21, win by 2, single capture beats
sum, no Chkobba on the final card. The alternative face values **J=9 Q=8 K=10**
also ship (K stays 10 in both). Every table-to-table difference is a flag in
`ChkobbaRules`, so house variants need no code change.

The fuzz found three invariant violations a human would have shipped: the round
ended as soon as hands emptied while 30 cards were still undealt; the Chkobba
marker card was counted twice (captured *and* on the table); and `Chkobba x3`
scored 1 point because points were derived from the number of reason strings.

## M0 — Environment ✅

Flutter/Dart is CI-only. Repo, `.gitignore`, CI skeleton, and the MySQL probe
against the live host (`php 8.5.6`, `mysql 8.0.46`, PDO MySQL on) are all in
place. The API host is **SFTP-only on port 22** — FTP ports 21/990/992 are closed
— so deployment is Paramiko `open_sftp()`, not FTP.
