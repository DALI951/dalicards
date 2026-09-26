import 'package:engine/engine.dart';
import 'package:test/test.dart';

/// Same helper shape as the rule tests, so positions read the same everywhere.
List<Card> cards(List<String> notes) {
  final out = <Card>[];
  for (var i = 0; i < notes.length; i++) {
    out.add(Card.parse(notes[i], id: i + 1));
  }
  return out;
}

ChkobbaState pos({
  List<String> table = const [],
  List<String> hand0 = const [],
  List<String> hand1 = const [],
  int current = 0,
  int dealer = 0,
  ChkobbaRules rules = ChkobbaRules.tunisianDefault,
}) {
  return ChkobbaState.fromCards(
    rules: rules,
    table: cards(table),
    hands: {0: cards(hand0), 1: cards(hand1)},
    current: current,
    dealer: dealer,
  );
}

/// Asserts the invariant a human would never check by eye: every one of the 40
/// physical cards is in exactly one place. This is the fuzz that caught the
/// "Chkobba marker counted twice" bug in M1.
void expectCardsAccountedFor(ChkobbaState state) {
  final seen = <int, String>{};
  void take(List<Card> pile, String where) {
    for (final c in pile) {
      seen[c.id] =
          seen.containsKey(c.id) ? 'DUPLICATE of ${seen[c.id]}' : where;
    }
  }

  for (var s = 0; s < state.seats; s++) {
    take(state.handOf(s), 'hand$s');
    take(state.capturedOf(s), 'captured$s');
  }
  take(state.table, 'table');
  take(state.stock, 'stock');

  final dupes = seen.values.where((v) => v.startsWith('DUPLICATE')).length;
  expect(dupes, 0,
      reason: 'a card is in two places at once:\n${state.debug()}');
  expect(seen.length, 40,
      reason: 'expected all 40 cards to be somewhere:\n${state.debug()}');
  expect(state.cardsInPlay + state.stockCount, 40, reason: state.debug());
}

void main() {
  group('legality', () {
    test('every level only ever returns a card that is in the hand', () {
      for (final level in BotLevel.values) {
        for (var seed = 0; seed < 200; seed++) {
          final state = ChkobbaState.newMatch(seed: seed);
          final bot = ChkobbaBot(level: level, seed: seed);
          for (var turn = 0; turn < 40; turn++) {
            if (state.roundFinished) break;
            final move = bot.chooseMove(state);
            // Re-read the hand every turn: a spent deal hands out three fresh
            // cards, so a hand captured before the loop goes stale immediately.
            final handIds =
                state.handOf(state.current).map((c) => c.id).toSet();
            expect(handIds, contains(move.cardId),
                reason:
                    '$level seed $seed turn $turn picked a card not in hand');
            state.play(state.current, move.cardId,
                optionIndex: move.optionIndex);
            expectCardsAccountedFor(state);
          }
        }
      }
    });

    test('the option index is always inside the engine\'s option list', () {
      for (final level in BotLevel.values) {
        for (var seed = 0; seed < 200; seed++) {
          final state = ChkobbaState.newMatch(seed: seed);
          final bot = ChkobbaBot(level: level, seed: seed);
          for (var turn = 0; turn < 40; turn++) {
            if (state.roundFinished) break;
            final move = bot.chooseMove(state);
            final card = state
                .handOf(state.current)
                .firstWhere((c) => c.id == move.cardId);
            final options = state.capturesFor(card);
            if (move.optionIndex != null) {
              expect(move.optionIndex!, lessThan(options.length),
                  reason: '$level seed $seed: option out of range');
            }
            state.play(state.current, move.cardId,
                optionIndex: move.optionIndex);
          }
        }
      }
    });

    test('a finished round is refused instead of played', () {
      final state = ChkobbaState.newMatch(seed: 7);
      final bot = ChkobbaBot(level: BotLevel.hard, seed: 7);
      while (!state.roundFinished) {
        final move = bot.chooseMove(state);
        state.play(state.current, move.cardId, optionIndex: move.optionIndex);
      }
      expect(() => bot.chooseMove(state), throwsStateError);
    });
  });

  group('behaviour', () {
    test('normal takes the capture instead of dumping the card', () {
      // A 5 on the table, a 5 in hand: taking two cards is worth far more than
      // leaving a 5 lying there.
      final state = pos(table: ['5h'], hand0: ['5d', 'Ah'], hand1: ['2c']);
      final bot = ChkobbaBot(level: BotLevel.normal, seed: 1);
      final move = bot.chooseMove(state);
      expect(move.cardId, cards(['5d']).first.id);
    });

    test('normal prefers the capture that takes the most cards', () {
      // 2 + 3 on the table, a 5 in hand: the sum beats a lone card.
      final state =
          pos(table: ['2h', '3c'], hand0: ['5d', 'Ah'], hand1: ['Kc']);
      final ranked =
          ChkobbaBot(level: BotLevel.normal, seed: 1).rankMoves(state, 0);
      expect(ranked.first.card.notation, '5d');
      expect(ranked.first.optionIndex, isNotNull,
          reason: 'taking 2+3 must be a chosen capture, not a silent one');
    });

    test('a lone 7 of diamonds is worth chasing', () {
      final state = pos(table: ['7d'], hand0: ['7d'], hand1: ['9c']);
      expect(
          ChkobbaBot(level: BotLevel.normal, seed: 1).chooseMove(state).cardId,
          cards(['7d']).first.id);
    });

    test('easy is random but never illegal', () {
      // 400 games of easy: whatever it does, the game must stay consistent.
      for (var seed = 0; seed < 400; seed++) {
        var state = ChkobbaState.newMatch(seed: seed);
        final bot = ChkobbaBot(level: BotLevel.easy, seed: seed);
        var guard = 0;
        while (!state.roundFinished && guard++ < 60) {
          final move = bot.chooseMove(state);
          state.play(state.current, move.cardId, optionIndex: move.optionIndex);
          expectCardsAccountedFor(state);
        }
        expect(state.roundFinished, isTrue, reason: 'easy deadlocked on $seed');
      }
    });

    test('hard looks one move further than normal', () {
      // Seat 0 can take one card; leaving a table the opponent can sweep is
      // exactly what hard is supposed to avoid.
      final state = pos(
        table: ['4h', '6c', '8d'],
        hand0: ['7s', '9c', 'Ts'],
        hand1: ['6h', '6d', 'Ah'],
        current: 0,
      );
      final normal =
          ChkobbaBot(level: BotLevel.normal, seed: 3).rankMoves(state, 0).first;
      final hard =
          ChkobbaBot(level: BotLevel.hard, seed: 3).rankMoves(state, 0).first;
      // Same shape of answer, but hard's score must be the penalised one.
      expect(hard.score, lessThanOrEqualTo(normal.score));
      expect(hard.card.id, normal.card.id);
    });

    test('levels are all reachable by name for the online bot takeover', () {
      expect(BotLevel.byName('easy'), BotLevel.easy);
      expect(BotLevel.byName('hard'), BotLevel.hard);
      expect(BotLevel.byName('nonsense'), BotLevel.normal);
    });

    test('the same seed plays the same match twice', () {
      List<int> run() {
        var state = ChkobbaState.newMatch(seed: 4242);
        final bots = [
          ChkobbaBot(level: BotLevel.hard, seed: 1),
          ChkobbaBot(level: BotLevel.normal, seed: 2),
        ];
        final log = <int>[];
        var guard = 0;
        while (!state.roundFinished && guard++ < 60) {
          final move = bots[state.current].chooseMove(state);
          log.add(move.cardId);
          state.play(state.current, move.cardId, optionIndex: move.optionIndex);
        }
        return log;
      }

      expect(run(), run());
    });
  });

  group('self-play fuzz', () {
    /// Plays one round to the end, asserting the invariants after every move.
    void playRound(ChkobbaState state, ChkobbaBot a, ChkobbaBot b) {
      var guard = 0;
      while (!state.roundFinished) {
        expect(guard++, lessThan(60),
            reason: 'round never ended:\n${state.debug()}');
        final bot = state.current == 0 ? a : b;
        final move = bot.chooseMove(state);
        state.play(state.current, move.cardId, optionIndex: move.optionIndex);
        expectCardsAccountedFor(state);
        expect(state.table.length, lessThanOrEqualTo(20));
      }
    }

    test('10,000 bot-vs-bot matches never crash, deadlock or lose a card', () {
      // Levels rotate so easy, normal and hard all get a workout. Two decks of
      // experience is the point: the invariants are what matter, not who wins.
      final levels = BotLevel.values;
      var matches = 0;
      var rounds = 0;
      var chkobbas = 0;
      var splitRounds = 0;
      for (var seed = 0; seed < 10000; seed++) {
        var state = ChkobbaState.newMatch(seed: seed);
        final bots = [
          ChkobbaBot(level: levels[seed % 3], seed: seed * 31 + 1),
          ChkobbaBot(level: levels[(seed + 1) % 3], seed: seed * 31 + 2),
        ];
        var roundGuard = 0;
        while (state.matchWinner() == -1 && roundGuard++ < 40) {
          playRound(state, bots[0], bots[1]);
          expectCardsAccountedFor(state);
          final scored = state.scoreRound();

          // Two teams scoring in one round is LEGAL and common: one side can
          // take Karta (most cards) while the other takes Sabaa el-Haya, which
          // is a single physical 7 of diamonds. Each *category* is exclusive,
          // so the invariant is per category, not per round. An earlier version
          // of this test asserted the round-exclusive version and the fuzz
          // caught the assumption, not the engine.
          for (final s in scored) {
            expect(s.points, greaterThanOrEqualTo(s.reasons.length),
                reason: 'a reason must be worth at least a point: $s');
            expect(s.reasons.toSet().length, s.reasons.length,
                reason: 'a reason was counted twice: $s');
            expect(s.team, inInclusiveRange(0, state.teamCount - 1));
          }
          // Points and reasons are two views of the same thing: a team with no
          // reason gets nothing, and a team with a reason gets something. This
          // is the exact pair of directions that M1 got wrong once.
          for (var t = 0; t < state.teamCount; t++) {
            final reasons = scored
                .where((s) => s.team == t)
                .fold<int>(0, (a, s) => a + s.reasons.length);
            expect(reasons == 0, state.roundPoints[t] == 0,
                reason: 'team $t: $reasons reasons but ${state.roundPoints[t]} '
                    'points');
          }
          state.commitRound();
          if (scored.where((s) => s.team == 0).isNotEmpty &&
              scored.where((s) => s.team == 1).isNotEmpty) {
            splitRounds++;
          }
          for (var t = 0; t < state.teamCount; t++) {
            expect(state.teamPoints[t], greaterThanOrEqualTo(0));
          }
          rounds++;
          chkobbas += state.chkobbas.fold<int>(0, (a, b) => a + b);
          if (state.matchWinner() != -1) break;
          state = state.nextRound(nextSeed: seed * 977 + rounds);
          expectCardsAccountedFor(state);
        }
        expect(state.matchWinner(), isNot(-1),
            reason: 'match $seed never reached a winner in $roundGuard rounds');
        // Win by two means the winner really is clear of the field.
        final winner = state.matchWinner();
        final otherSeats = List<int>.generate(state.teamCount, (t) => t)
          ..remove(winner);
        final others = otherSeats.map((t) => state.teamPoints[t]).toList();
        expect(
            state.teamPoints[winner] - others.reduce((a, b) => a > b ? a : b),
            greaterThanOrEqualTo(2));
        expectCardsAccountedFor(state);
        matches++;
      }

      // Sanity: the run has to have actually exercised the game, not 10,000
      // rounds of nothing happening.
      expect(matches, 10000);
      expect(rounds, greaterThan(10000));
      expect(chkobbas, greaterThan(0));
      // And the split-round case above has to be a real branch, not a theory.
      expect(splitRounds, greaterThan(0),
          reason: 'no round ever scored for both sides, so nothing proved it');
    });
  });
}
