import 'package:engine/engine.dart';
import 'package:test/test.dart';

/// Builds a card list from compact notation: `cards(['5h', '2c', '3d'])`.
List<Card> cards(List<String> notes) {
  final out = <Card>[];
  for (var i = 0; i < notes.length; i++) {
    out.add(Card.parse(notes[i], id: i + 1));
  }
  return out;
}

Card one(String note) => cards([note]).first;

ChkobbaState pos({
  List<String> table = const [],
  List<String> hand0 = const [],
  List<String> hand1 = const [],
  List<String> hand2 = const [],
  List<String> hand3 = const [],
  List<String> captured0 = const [],
  List<String> captured1 = const [],
  List<String> captured2 = const [],
  List<String> captured3 = const [],
  List<int> chkobbas = const [],
  List<int> teamPoints = const [],
  int current = 0,
  int dealer = 0,
  int lastCapturer = -1,
  int playedThisDeal = 0,
  int seed = 0,
  ChkobbaRules rules = ChkobbaRules.tunisianDefault,
}) {
  return ChkobbaState.fromCards(
    rules: rules,
    table: cards(table),
    hands: {
      0: cards(hand0),
      1: cards(hand1),
      2: cards(hand2),
      3: cards(hand3),
    },
    captured: {
      0: cards(captured0),
      1: cards(captured1),
      2: cards(captured2),
      3: cards(captured3),
    },
    chkobbas: chkobbas,
    teamPoints: teamPoints,
    current: current,
    dealer: dealer,
    lastCapturer: lastCapturer,
    playedThisDeal: playedThisDeal,
    seed: seed,
  );
}

void main() {
  // -------------------------------------------------------------------------
  group('capture resolution', () {
    test('a single equal-value table card is captured', () {
      final s = pos(table: ['5h', '2c'], hand0: ['5d']);
      final opts = s.capturesFor(one('5d'));
      expect(opts.length, 1);
      expect(opts.first.size, 2); // played card + the 5
      expect(opts.first.isSingle, isTrue);
      expect(opts.first.cards.map((c) => c.notation).toSet(), {'5d', '5h'});
    });

    test('a sum of table cards is captured', () {
      final s = pos(table: ['2c', '3d'], hand0: ['5h']);
      final opts = s.capturesFor(one('5h'));
      expect(opts.length, 1);
      expect(opts.first.size, 3);
      expect(opts.first.cards.length, 3);
    });

    test('a single beats an equal sum (the rule everybody forgets)', () {
      final s = pos(table: ['5h', '2c', '3d'], hand0: ['5s']);
      final opts = s.capturesFor(one('5s'));
      expect(opts.length, 1, reason: 'single-first must hide the 2+3 option');
      expect(opts.first.size, 2);
      expect(opts.first.cards.map((c) => c.notation), containsAll(['5s', '5h']));
      expect(s.forcedCapture(one('5s'))!.size, 2);
    });

    test('bestSum mode offers the player both options', () {
      final s = pos(
        table: ['5h', '2c', '3d'],
        hand0: ['5s'],
        rules: const ChkobbaRules(
            capturePriority: CapturePriority.bestSum),
      );
      final opts = s.capturesFor(one('5s'));
      expect(opts.length, 2);
      expect(opts.first.size, 3, reason: 'biggest capture first');
      expect(opts.first.isSingle, isFalse);
      expect(opts.last.isSingle, isTrue);
    });

    test('no match means no capture, the card joins the table', () {
      final s = pos(table: ['2c', '3d'], hand0: ['9h']);
      expect(s.capturesFor(one('9h')), isEmpty);
      expect(s.forcedCapture(one('9h')), isNull);
    });

    test('three-card sums work', () {
      final s = pos(table: ['2c', '3d', '4h'], hand0: ['9s']);
      final opts = s.capturesFor(one('9s'));
      expect(opts.length, 1);
      expect(opts.first.size, 4);
    });

    test('face cards use the variant values (J=8 Q=9 K=10 by default)', () {
      final s = pos(table: ['2c', '6d'], hand0: ['Jh']);
      expect(s.capturesFor(one('Jh')).first.size, 3, reason: 'J is worth 8');

      final s2 = pos(
        table: ['2c', '6d'],
        hand0: ['Jh'],
        rules: const ChkobbaRules(faceValues: FaceValues.swapped),
      );
      expect(s2.capturesFor(one('Jh')), isEmpty, reason: 'J is worth 9 now');
    });

    test('a value already on the table cannot be used twice in one sum', () {
      // Table has two 5s; a K (10) may take 5+5 but not 5+5+5.
      final s = pos(table: ['5h', '5c', '2d'], hand0: ['Ks']);
      final opts = s.capturesFor(one('Ks'));
      expect(opts.length, 1);
      expect(opts.first.size, 3);
    });

    test('ambiguous sums force the player to choose', () {
      // 6 can be 6, 1+5, 2+4, 1+2+3 -> several valid sums.
      final s = pos(table: ['Ad', '2c', '3h', '4s', '5c'], hand0: ['6h']);
      expect(s.capturesFor(one('6h')).length, greaterThan(1));
      expect(s.forcedCapture(one('6h')), isNull);
    });

    test('an Ace is always worth 1, never 11', () {
      // The ace must not be able to reach a king (10) or a queen (9).
      final s = pos(table: ['Kh'], hand0: ['Ad']);
      expect(s.capturesFor(one('Ad')), isEmpty);

      final s2 = pos(table: ['Ah'], hand0: ['Ad']);
      expect(s2.capturesFor(one('Ad')).first.size, 2,
          reason: 'ace matches ace');
    });
  });

  // -------------------------------------------------------------------------
  group('playing a card', () {
    test('capturing removes the cards from the table and records the move', () {
      final s = pos(table: ['2c', '3d'], hand0: ['5h']);
      final move = s.play(0, one('5h').id);
      expect(move.captured.length, 3);
      expect(move.chkobba, isFalse);
      expect(s.table, isEmpty);
      expect(s.capturedOf(0).length, 3);
      expect(s.handOf(0), isEmpty);
      expect(s.current, 1);
    });

    test('a non-capturing card stays on the table', () {
      final s = pos(table: ['2c'], hand0: ['9h']);
      final move = s.play(0, one('9h').id);
      expect(move.cardLeftOnTable, isTrue);
      expect(move.captured, isEmpty);
      expect(s.table.length, 2);
      expect(s.capturedOf(0), isEmpty);
      expect(s.lastCapturer, -1);
    });

    test('turns alternate', () {
      final s = pos(table: ['2c'], hand0: ['9h'], hand1: ['9d']);
      expect(s.current, 0);
      s.play(0, one('9h').id);
      expect(s.current, 1);
      s.play(1, one('9d').id);
      expect(s.current, 0);
    });

    test('playing out of turn is rejected', () {
      final s = pos(table: ['2c'], hand0: ['9h'], hand1: ['9d'], current: 0);
      expect(() => s.play(1, one('9d').id), throwsStateError);
    });

    test('playing a card you do not hold is rejected', () {
      final s = pos(table: ['2c'], hand0: ['9h']);
      expect(() => s.play(0, 999), throwsStateError);
    });

    test('the option index picks between equal sums', () {
      final s = pos(table: ['Ad', '2c', '3h', '4s', '5c'], hand0: ['6h']);
      final options = s.capturesFor(one('6h'));
      expect(options.length, greaterThan(1));
      final move = s.play(0, one('6h').id, optionIndex: 0);
      // CaptureOption.cards already contains the played card.
      expect(move.captured.length, options.first.size);
    });
  });

  // -------------------------------------------------------------------------
  group('Chkobba (the sweep)', () {
    test('emptying the table scores a Chkobba and keeps the marker card', () {
      final s = pos(table: ['5h'], hand0: ['5d'], hand1: ['2c']);
      final move = s.play(0, one('5d').id);
      expect(move.chkobba, isTrue);
      expect(s.chkobbasOf(0), 1);
      expect(s.table, isEmpty, reason: 'the table really is swept');
      expect(s.chkobbaMarker?.notation, '5d');
      // The marker must not be counted twice: 2 captured + 1 still in hand.
      expect(s.cardsInPlay, 3);
    });

    test('the dealer cannot Chkobba with the final card of the round', () {
      final s = pos(
        table: ['5h'],
        hand0: ['5d'],
        hand1: <String>[],
        dealer: 0,
        // stock empty + both hands empty after this play => final card
        playedThisDeal: 0,
      );
      s.hands[1] = <Card>[];
      final move = s.play(0, one('5d').id);
      expect(move.chkobba, isFalse);
      expect(s.chkobbasOf(0), 0);
    });

    test('a non-dealer still Chkobbas on the final card', () {
      final s = pos(
        table: ['5h'],
        hand0: [],
        hand1: ['5d'],
        current: 1,
        dealer: 0,
      );
      final move = s.play(1, one('5d').id);
      expect(move.chkobba, isTrue);
    });

    test('the chkobbaOnFinalCard variant allows it for the dealer', () {
      final s = pos(
        table: ['5h'],
        hand0: ['5d'],
        hand1: <String>[],
        dealer: 0,
        rules: const ChkobbaRules(chkobbaOnFinalCard: true),
      );
      expect(s.play(0, one('5d').id).chkobba, isTrue);
    });
  });

  // -------------------------------------------------------------------------
  group('dealing and round end', () {
    test('opening deal is 3 each plus 4 on the table', () {
      final s = ChkobbaState.newMatch(seed: 42);
      expect(s.handOf(0).length, 3);
      expect(s.handOf(1).length, 3);
      expect(s.table.length, 4);
      expect(s.stockCount, 30);
    });

    test('all 40 cards are always accounted for', () {
      final s = ChkobbaState.newMatch(seed: 7);
      expect(s.cardsInPlay + s.stockCount, 40);
    });

    test('a fresh deal of 3 goes to each seat after a full deal is played', () {
      final s = ChkobbaState.newMatch(seed: 11);
      // 3 cards x 2 seats = 6 plays before the next deal.
      for (var i = 0; i < 6; i++) {
        s.play(s.current, s.handOf(s.current).first.id);
      }
      expect(s.stockCount, 24);
      expect(s.handOf(0).length, 3);
      expect(s.handOf(1).length, 3);
    });

    test('the round ends when every card is played', () {
      final s = ChkobbaState.newMatch(seed: 3);
      var guard = 0;
      while (!s.roundFinished && guard++ < 200) {
        final seat = s.current;
        final card = s.handOf(seat).first;
        final options = s.capturesFor(card);
        s.play(seat, card.id,
            optionIndex: options.isEmpty ? null : 0);
      }
      expect(s.roundFinished, isTrue, reason: s.debug());
      expect(guard, lessThan(200));
      expect(s.cardsInPlay, 40, reason: 'nothing may be lost or duplicated');
    });

    test('the last capturer sweeps the table at the end of the round', () {
      final s = ChkobbaState.newMatch(seed: 5);
      var guard = 0;
      while (!s.roundFinished && guard++ < 200) {
        final seat = s.current;
        final card = s.handOf(seat).first;
        s.play(seat, card.id);
      }
      expect(s.table, isEmpty);
      final total =
          s.captured.fold<int>(0, (a, c) => a + c.length) + s.table.length;
      expect(total, 40);
    });

    test('an opening table with three of a rank asks for a redeal', () {
      // Force it: build a state whose 4 table cards are 5h 5c 5d 7s by dealing
      // until one appears, using the flag explicitly.
      final s = pos(table: ['5h', '5c', '5d', '7s'], hand0: ['Ah']);
      expect(s.redealNeeded, isFalse, reason: 'fromCards skips the deal check');

      final found = _findTripleOpening(2000);
      expect(found, isTrue, reason: 'the redeal rule must actually trigger');
    });
  });

  // -------------------------------------------------------------------------
  group('scoring', () {
    test('Karta goes to the side with strictly more cards', () {
      final s = pos(
        captured0: ['Ah', '2c'],
        captured1: ['3d'],
      );
      final scores = s.scoreRound();
      final karta = scores.firstWhere((x) => x.reasons.contains('Karta'));
      expect(karta.team, 0);
      expect(karta.points, 1);
    });

    test('a Karta tie scores nothing', () {
      final s = pos(captured0: ['Ah'], captured1: ['3d']);
      expect(s.scoreRound().where((x) => x.reasons.contains('Karta')), isEmpty);
    });

    test('Dinari goes to the most diamonds and needs at least one', () {
      final s = pos(captured0: ['Ad', '2d'], captured1: ['3c', '4c']);
      final scores = s.scoreRound();
      expect(scores.firstWhere((x) => x.reasons.contains('Dinari')).team, 0);
      expect(scores.firstWhere((x) => x.reasons.contains('Dinari')).points, 1);

      final none = pos(captured0: ['Ah', '2c'], captured1: ['3h', '4c']);
      expect(none.scoreRound().where((x) => x.reasons.contains('Dinari')),
          isEmpty);
    });

    test('a Dinari tie scores nothing', () {
      final s = pos(captured0: ['Ad'], captured1: ['3d']);
      expect(s.scoreRound().where((x) => x.reasons.contains('Dinari')),
          isEmpty);
    });

    test('Barmila goes to the most sevens', () {
      final s = pos(captured0: ['7h'], captured1: ['3d', '4c']);
      expect(
          s.scoreRound().firstWhere((x) => x.reasons.contains('Barmila')).team,
          0);
    });

    test('Barmila ties are broken by sixes', () {
      final s = pos(captured0: ['7h'], captured1: ['7d']);
      expect(s.scoreRound().where((x) => x.reasons.contains('Barmila')),
          isEmpty);

      final s2 = pos(captured0: ['7h'], captured1: ['7d', '6c']);
      expect(
          s2.scoreRound().firstWhere((x) => x.reasons.contains('Barmila')).team,
          1);
    });

    test('Sabaa el-Haya goes to whoever holds the 7 of diamonds', () {
      final s = pos(captured0: ['Ah'], captured1: ['7d']);
      expect(
          s.scoreRound().firstWhere((x) => x.reasons.contains('Sabaa el-Haya')).team,
          1);
    });

    test('each Chkobba is worth one point', () {
      final s = pos(captured0: ['Ah'], chkobbas: [2, 0]);
      final x = s.scoreRound().firstWhere((e) => e.reasons.contains('Chkobba x2'));
      expect(x.team, 0);
      expect(x.points, greaterThanOrEqualTo(1));
    });

    test('in 2v2 both partners score for the same team', () {
      final s = pos(
        rules: ChkobbaRules.twoVTwo,
        captured0: ['Ah'],
        captured1: ['3h'],
        captured2: ['4h'],
        captured3: ['5c'],
        chkobbas: [0, 0, 1, 0],
      );
      final scores = s.scoreRound();
      // seat0 and seat2 are partners (team 0): Karta 2 cards vs 2 -> tie, and
      // nobody holds a diamond, so the only point is seat2's Chkobba.
      final t0 =
          scores.where((x) => x.team == 0).fold<int>(0, (a, b) => a + b.points);
      final t1 =
          scores.where((x) => x.team == 1).fold<int>(0, (a, b) => a + b.points);
      expect(t0, 1);
      expect(t1, 0);
    });

    test('every scoring category can be switched off individually', () {
      final s = pos(
        captured0: ['7d', 'Ah'],
        chkobbas: [1, 0],
        rules: const ChkobbaRules(
          scoreKarta: false,
          scoreDinari: false,
          scoreBarmila: false,
          scoreSabaa: false,
          scoreChkobba: false,
        ),
      );
      expect(s.scoreRound(), isEmpty);
    });
  });

  // -------------------------------------------------------------------------
  group('match end', () {
    test('reaching the target with a 2-point lead wins', () {
      final s = pos(teamPoints: [21, 19]);
      expect(s.matchWinner(), 0);
    });

    test('target reached without the lead does not win', () {
      final s = pos(teamPoints: [21, 20]);
      expect(s.matchWinner(), -1);
    });

    test('winByTwo off only needs the target', () {
      final s = pos(teamPoints: [21, 21], rules: const ChkobbaRules(winByTwo: false));
      expect(s.matchWinner(), greaterThanOrEqualTo(0));
    });

    test('below the target never wins', () {
      final s = pos(teamPoints: [20, 3]);
      expect(s.matchWinner(), -1);
    });

    test('commitRound folds the round into the match totals', () {
      final s = pos(captured0: ['Ah', '2c', '3d'], chkobbas: [1, 0]);
      s.scoreRound();
      s.commitRound();
      expect(s.teamPoints[0], greaterThan(0));
    });

    test('the next round keeps the match totals and passes the dealer', () {
      final s = pos(teamPoints: [7, 3], dealer: 1, seed: 99);
      final n = s.nextRound();
      expect(n.teamPoints, [7, 3]);
      expect(n.dealer, 0);
      expect(n.handOf(0).length, 3);
      expect(n.seed, isNot(99));
    });
  });

  // -------------------------------------------------------------------------
  group('snapshot round trip', () {
    test('a serialised match restores exactly, mid-round', () {
      final s = ChkobbaState.newMatch(seed: 1234);
      for (var i = 0; i < 7; i++) {
        final seat = s.current;
        final card = s.handOf(seat).first;
        final opts = s.capturesFor(card);
        s.play(seat, card.id, optionIndex: opts.isEmpty ? null : 0);
      }
      final back = ChkobbaState.fromJson(s.toJson());
      expect(back.seed, s.seed);
      expect(back.current, s.current);
      expect(back.turnIndex, s.turnIndex);
      expect(back.table.map((c) => c.notation).toList(),
          s.table.map((c) => c.notation).toList());
      expect(back.handOf(0).map((c) => c.notation).toList(),
          s.handOf(0).map((c) => c.notation).toList());
      expect(back.capturedOf(0).map((c) => c.notation).toList(),
          s.capturedOf(0).map((c) => c.notation).toList());
      expect(back.toJson().toString(), s.toJson().toString());
    });

    test('rules survive the round trip', () {
      const r = ChkobbaRules(
        seats: 4,
        partners: true,
        targetScore: 11,
        faceValues: FaceValues.swapped,
        capturePriority: CapturePriority.bestSum,
      );
      final back = ChkobbaRules.fromJson(r.toJson());
      expect(back.seats, 4);
      expect(back.partners, isTrue);
      expect(back.targetScore, 11);
      expect(back.faceValues.jack, 9);
      expect(back.capturePriority, CapturePriority.bestSum);
    });
  });

  // -------------------------------------------------------------------------
  group('fuzz: 300 full bot-less games are legal and lossless', () {
    test('no crash, no deadlock, no card created or destroyed', () {
      for (var seed = 0; seed < 300; seed++) {
        final s = ChkobbaState.newMatch(seed: seed);
        var guard = 0;
        while (!s.roundFinished) {
          guard++;
          expect(guard, lessThan(500), reason: 'deadlock at seed $seed');
          final seat = s.current;
          expect(seat, inInclusiveRange(0, s.seats - 1));
          final hand = s.handOf(seat);
          expect(hand, isNotEmpty);
          // Deterministic pseudo-random but legal choice: always prefer a
          // forced capture, else the first card.
          final card = hand.first;
          final forced = s.forcedCapture(card);
          s.play(seat, card.id, optionIndex: forced == null ? null : 0);
          expect(s.cardsInPlay + s.stockCount, 40,
              reason: 'card count drifted at seed $seed');
        }
        expect(s.cardsInPlay, 40, reason: 'seed $seed ended at ${s.debug()}');
        expect(s.table, isEmpty);
        // Scoring must never throw: 4 single-point categories at most, plus one
        // point per Chkobba.
        final scored = s.scoreRound();
        final chkobbas = s.chkobbas.fold<int>(0, (a, b) => a + b);
        final total = scored.fold<int>(0, (a, b) => a + b.points);
        expect(total, lessThanOrEqualTo(4 + chkobbas));
      }
    });

    test('a whole match reaches a winner with 4 seats and partners', () {
      var matches = 0;
      for (var seed = 0; seed < 40; seed++) {
        var s = ChkobbaState.newMatch(
            rules: ChkobbaRules.twoVTwo, seed: seed);
        var rounds = 0;
        while (s.matchWinner() < 0 && rounds < 60) {
          var guard = 0;
          while (!s.roundFinished && guard++ < 500) {
            final seat = s.current;
            final card = s.handOf(seat).first;
            s.play(seat, card.id);
          }
          s.scoreRound();
          s.commitRound();
          s = s.nextRound();
          rounds++;
        }
        expect(rounds, lessThan(60), reason: 'match $seed never ended');
        expect(s.matchWinner(), inInclusiveRange(0, 1));
        matches++;
      }
      expect(matches, 40);
    });
  });
}

/// Searches for a seed whose opening 4 table cards contain three of a rank.
bool _findTripleOpening(int maxSeeds) {
  for (var seed = 0; seed < maxSeeds; seed++) {
    final s = ChkobbaState.newMatch(seed: seed);
    if (s.redealNeeded) return true;
  }
  return false;
}
