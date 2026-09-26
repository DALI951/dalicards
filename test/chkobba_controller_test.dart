import 'package:dalicards/ui/chkobba/chkobba_controller.dart';
import 'package:engine/engine.dart';
import 'package:flutter_test/flutter_test.dart';

/// Lets the bot's zero-delay timer fire, then the flash timer, without waiting
/// on wall-clock time in a test.
Future<void> settle([int ms = 40]) =>
    Future<void>.delayed(Duration(milliseconds: ms));

void main() {
  group('setup', () {
    test('a shared link carries the whole table and reads it back', () {
      const setup = ChkobbaSetup(
        mode: ChkobbaMode.hotseat,
        level: BotLevel.hard,
        faceValues: FaceValues.swapped,
        targetScore: 31,
        dealSize: 4,
        capturePriority: CapturePriority.bestSum,
      );
      final back = ChkobbaSetup.fromQuery(setup.query);
      expect(back.mode, ChkobbaMode.hotseat);
      expect(back.level, BotLevel.hard);
      expect(back.faceValues.jack, 9);
      expect(back.faceValues.queen, 8);
      expect(back.targetScore, 31);
      expect(back.dealSize, 4);
      expect(back.capturePriority, CapturePriority.bestSum);
    });

    test('a missing or rubbish query falls back to the shipped default', () {
      for (final q in <String?>[
        null,
        '',
        'nonsense',
        'mode=alien&target=abc'
      ]) {
        final setup = ChkobbaSetup.fromQuery(q);
        expect(setup.mode, ChkobbaMode.solo);
        expect(setup.targetScore, 21);
        expect(setup.dealSize, 3);
        expect(setup.faceValues.jack, 8);
        expect(setup.capturePriority, CapturePriority.singleFirst);
      }
    });

    test('the rules the setup builds are the rules the engine reads', () {
      const setup = ChkobbaSetup(targetScore: 31, dealSize: 4);
      final rules = setup.rules;
      expect(rules.targetScore, 31);
      expect(rules.dealSize, 4);
      expect(rules.seats, 2);
      expect(rules.teamCount, 2);
    });
  });

  group('a solo game', () {
    test('the human always plays seat 0 and the bot answers', () async {
      final c = ChkobbaController(
        setup: const ChkobbaSetup(),
        seed: 11,
        botDelay: Duration.zero,
      );
      addTearDown(c.dispose);

      expect(c.viewerSeat, 0);
      expect(c.isMyTurn, isTrue, reason: 'the dealer opens');
      expect(c.botThinking, isFalse);
      expect(c.handOf(0).length, 3);
      expect(c.tableCards().length, 4);

      c.playCard(c.handOf(0).first.id);
      expect(c.handOf(0).length, 2);
      expect(c.isMyTurn, isFalse);
      expect(c.botThinking, isTrue);

      await settle();
      expect(c.isMyTurn, isTrue, reason: 'the bot must have moved');
    });

    test('the bot never sees its own cards and always moves legally', () async {
      for (var seed = 0; seed < 25; seed++) {
        final c = ChkobbaController(
          setup: const ChkobbaSetup(level: BotLevel.easy),
          seed: seed,
          botDelay: Duration.zero,
        );
        var guard = 0;
        while (!c.roundFinished && guard++ < 60) {
          if (c.isMyTurn) {
            expect(c.viewerSeat, 0);
            c.playCard(c.handOf(0).first.id);
          }
          await settle(2);
        }
        expect(c.roundFinished, isTrue, reason: 'seed $seed never finished');
        c.dispose();
      }
    });

    test(
        'a whole match runs to a winner without a human tap after each bot turn',
        () async {
      final c = ChkobbaController(
        setup: const ChkobbaSetup(),
        seed: 5,
        botDelay: Duration.zero,
      );
      addTearDown(c.dispose);

      var rounds = 0;
      while (c.matchWinner == -1 && rounds++ < 40) {
        var guard = 0;
        while (!c.roundFinished && guard++ < 60) {
          if (c.isMyTurn) c.playCard(c.handOf(0).first.id);
          await settle(2);
        }
        expect(c.roundFinished, isTrue, reason: 'round $rounds never finished');
        expect(c.roundScores, isNotEmpty,
            reason: 'a round must award something');
        if (c.matchWinner != -1) break;
        c.nextRound();
        await settle(2);
      }
      expect(c.matchWinner, isNot(-1),
          reason: 'no winner after $rounds rounds');
      expect(c.teamPoints[c.matchWinner],
          greaterThanOrEqualTo(c.setup.targetScore));
    });
  });

  group('hotseat', () {
    test('the hand on screen follows the turn, and never both hands', () async {
      final c = ChkobbaController(
        setup: const ChkobbaSetup(mode: ChkobbaMode.hotseat),
        seed: 3,
      );
      addTearDown(c.dispose);

      expect(c.viewerSeat, 0);
      expect(c.botThinking, isFalse, reason: 'no bot in hotseat');
      final firstHand = c.handOf(0).map((card) => card.id).toSet();

      c.playCard(c.handOf(0).first.id);
      // Turn passed to seat 1, so the screen now shows seat 1's hand.
      expect(c.viewerSeat, 1);
      expect(c.botThinking, isFalse);

      c.playCard(c.handOf(1).first.id);
      expect(c.viewerSeat, 0);
      // Whatever seat 1 played, seat 0's hand is the original one minus one card.
      expect(c.handOf(0).length, firstHand.length - 1);
    });

    test('the bot timer never runs in hotseat', () async {
      final c = ChkobbaController(
        setup: const ChkobbaSetup(mode: ChkobbaMode.hotseat),
        seed: 9,
        botDelay: Duration.zero,
      );
      addTearDown(c.dispose);
      c.playCard(c.handOf(0).first.id);
      await settle(30);
      // Still seat 1 to move: nobody played for them.
      expect(c.viewerSeat, 1);
      expect(c.isMyTurn, isTrue);
    });
  });

  group('playing', () {
    test('a card with no capture joins the table', () {
      // 9 in hand, nothing on the table sums to 9.
      final c = ChkobbaController(
        setup: const ChkobbaSetup(),
        seed: 1234,
      );
      addTearDown(c.dispose);
      final card = c.handOf(0).first;
      final options = c.state.capturesFor(card);
      if (options.isEmpty) {
        final before = c.tableCards().length;
        c.playCard(card.id);
        expect(c.tableCards().length, before + 1);
        expect(c.tableCards().contains(card), isTrue);
      }
      // Whatever the seed dealt, the engine must never throw.
      expect(c.state.cardsInPlay + c.stockCount, 40);
    });

    test('lifting a card asks for a capture only when there is a real choice',
        () {
      final c = ChkobbaController(
        setup: const ChkobbaSetup(),
        seed: 77,
      );
      addTearDown(c.dispose);
      for (final card in c.handOf(0)) {
        c.toggleCard(card.id);
        expect(c.selectedCardId, card.id);
        expect(c.needsCaptureChoice, c.selectedOptions.length > 1);
        c.clearSelection();
        expect(c.selectedCardId, isNull);
      }
    });

    test('lifting the same card twice puts it back down', () {
      final c = ChkobbaController(setup: const ChkobbaSetup(), seed: 2);
      addTearDown(c.dispose);
      final id = c.handOf(0).first.id;
      c.toggleCard(id);
      expect(c.selectedCard, isNotNull);
      c.toggleCard(id);
      expect(c.selectedCard, isNull);
    });

    test('nothing is played out of turn', () async {
      final c = ChkobbaController(
        setup: const ChkobbaSetup(),
        seed: 8,
        botDelay: const Duration(milliseconds: 400),
      );
      // The bot's turn now: our taps must be ignored rather than throwing.
      final seat1Hand = c.handOf(1).length;
      c.playCard(c.handOf(0).first.id);
      c.playCard(99999);
      expect(c.handOf(1).length, seat1Hand);
      expect(c.isMyTurn, isFalse);
      c.dispose();
    });
  });

  group('the round and the match', () {
    test('an illegal opening deal is re-dealt, not handed to the player', () {
      // Exhaustively: no seed may ever start a match with three or four of one
      // rank on the table, because the controller redeals those.
      for (var seed = 0; seed < 300; seed++) {
        final c = ChkobbaController(setup: const ChkobbaSetup(), seed: seed);
        final counts = <int, int>{};
        for (final card in c.tableCards()) {
          final v = c.state.rules.valueOf(card);
          counts[v] = (counts[v] ?? 0) + 1;
        }
        expect(counts.values.every((n) => n < 3), isTrue,
            reason: 'seed $seed was dealt an illegal table');
        c.dispose();
      }
    });

    test('the round panel names every scoring reason from the engine',
        () async {
      final c = ChkobbaController(
        setup: const ChkobbaSetup(),
        seed: 21,
        botDelay: Duration.zero,
      );
      addTearDown(c.dispose);
      var guard = 0;
      while (!c.roundFinished && guard++ < 60) {
        if (c.isMyTurn) c.playCard(c.handOf(0).first.id);
        await settle(2);
      }
      expect(c.roundFinished, isTrue);
      expect(c.roundScores, isNotEmpty);
      for (final score in c.roundScores) {
        expect(score.reasons, isNotEmpty);
        expect(score.points, greaterThanOrEqualTo(score.reasons.length));
      }
      // Points and reasons were committed together, exactly once.
      final sum = c.teamPoints.fold<int>(0, (a, b) => a + b);
      expect(sum, greaterThan(0));
    });

    test('next round keeps the totals, restart throws them away', () async {
      final c = ChkobbaController(
        setup: const ChkobbaSetup(targetScore: 11),
        seed: 31,
        botDelay: Duration.zero,
      );
      addTearDown(c.dispose);
      var guard = 0;
      while (!c.roundFinished && guard++ < 60) {
        if (c.isMyTurn) c.playCard(c.handOf(0).first.id);
        await settle(2);
      }
      final afterRound = List<int>.from(c.teamPoints);
      expect(afterRound.fold<int>(0, (a, b) => a + b), greaterThan(0));

      c.nextRound();
      expect(c.roundScores, isEmpty);
      expect(c.teamPoints, afterRound,
          reason: 'a new round is not a new match');
      expect(c.roundFinished, isFalse);

      c.restart();
      expect(c.teamPoints, everyElement(0));
      expect(c.roundScores, isEmpty);
      expect(c.handOf(0).length, 3);
    });

    test('the Chkobba flash raises on a sweep and always clears itself',
        () async {
      var sawFlash = false;
      var stuck = 0;
      var sweeps = 0;

      // Driven by the hard bot on BOTH seats. A "play the first card in hand"
      // policy almost never sweeps - a sweep needs a card that actually beats
      // the table sum - so it would prove nothing about the flash. This is the
      // same driver the engine fuzz uses, and it does produce chkobbas.
      for (var seed = 0; seed < 12; seed++) {
        final driver = ChkobbaBot(level: BotLevel.hard, seed: seed);
        final c = ChkobbaController(
          setup: const ChkobbaSetup(),
          seed: seed,
          botDelay: Duration.zero,
          flashDuration: const Duration(milliseconds: 10),
        );
        expect(c.chkobbaFlashing, isFalse, reason: 'a new match never flashes');
        var guard = 0;
        while (!c.roundFinished && guard++ < 80) {
          if (c.isMyTurn) {
            final before = c.state.chkobbasOf(c.viewerSeat);
            final move = driver.chooseMove(c.state);
            c.playCard(move.cardId, optionIndex: move.optionIndex);
            sweeps += c.state.chkobbasOf(c.viewerSeat) - before;
          }
          if (c.chkobbaFlashing) sawFlash = true;
          await settle(15);
          if (c.chkobbaFlashing) stuck++;
        }
        c.dispose();
      }

      expect(stuck, 0, reason: 'the flash got stuck on $stuck times');
      expect(sweeps, greaterThan(0),
          reason: 'no sweep in 12 games, so the flash path was never proven');
      expect(sawFlash, isTrue,
          reason: '$sweeps sweeps but the flash never rose');
    });
  });
}
