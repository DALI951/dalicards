/// Rule tests for Tunisian Rami.
///
/// These are written as rules, not as implementation trivia: every assertion
/// below is a statement a Tunisian player would recognise, and each one is
/// cross-checkable against the published rule pages.
library;

import 'dart:math';

import 'package:engine/engine.dart';
import 'package:test/test.dart';

/// A hand big enough to always have something legal available.
const stock = [
  '2c', '3c', '4c', '5c', '6c', '7c', '8c', '9c', 'Tc', 'Jc', 'Qc', 'Kc',
  'Ac', '2d', '3d', '4d', '5d', '6d', '7d', '8d', '9d', 'Td', 'Jd', 'Qd',
  'Kd', 'Ad', '2h', '3h', '4h', '5h', '6h', '7h', '8h', '9h', 'Th', 'Jh',
  'Qh', 'Kh', 'Ah', '2s', '3s', '4s', '5s', '6s', '7s', '8s', '9s', 'Ts',
  'Js', 'Qs', 'Ks', 'As', '2c', '3c', '4c', '5c', '6c', '7c', '8c', '9c',
  'Tc', 'Jc', 'Qc', 'Kc', 'Ac', '2d', '3d', '4d', '5d', '6d', '7d', '8d',
];

/// Ids of the cards named by [notes] in [seat]'s hand.
///
/// The hand is searched first on purpose: a double deck means the same
/// notation can sit in the stock and in a hand at the same time, and they are
/// different physical cards.
List<int> idsIn(RamiState s, int seat, List<String> notes) => [
      for (final n in notes)
        s.handOf(seat).firstWhere((c) => c.notation == n,
            orElse: () => throw StateError('seat$seat holds no $n')).id,
    ];

Card one(String n) => Card.parse(n);

void main() {
  group('the Tunisian deck', () {
    test('is 108 cards: two packs plus four jokers', () {
      expect(DeckSpec.rami.size, 108);
      expect(RamiRules.tunisian.totalCards, 108);
      expect(RamiRules.tunisian.decks, 2);
      expect(RamiRules.tunisian.jokers, 4);
    });

    test('builds exactly as many cards as it claims', () {
      final deck = Deck.shuffled(DeckSpec.rami, 1);
      expect(deck.cards.length, 108);
      expect(deck.cards.where((c) => c.joker).length, 4);
      expect(deck.cards.map((c) => c.id).toSet().length, 108,
          reason: 'every card id is unique');
    });

    test('deals 14 cards to each of 2 players', () {
      final s = RamiState.newRound(seed: 7);
      expect(s.handCount(0), 14);
      expect(s.handCount(1), 14);
      // 108 - 28 - 1 face-up discard
      expect(s.stock.length, 79);
      expect(s.cardsInPlay, 108);
    });
  });

  group('card values', () {
    test('ace 11, every face 10, jokers 20, pips at face value', () {
      const r = RamiRules.tunisian;
      expect(ramiValue(one('Ad'), r), 11);
      expect(ramiValue(one('Jd'), r), 10);
      expect(ramiValue(one('Qd'), r), 10);
      expect(ramiValue(one('Kd'), r), 10);
      expect(ramiValue(one('7d'), r), 7);
      expect(ramiValue(one('Td'), r), 10);
      expect(ramiValue(Card.parse('Jk'), r), 20);
    });
  });

  group('tirsi (sets)', () {
    test('three of a kind in three suits is a tirsi', () {
      final m = solveMeld([one('Kd'), one('Kh'), one('Ks')], RamiRules.tunisian);
      expect(m, isNotNull);
      expect(m!.kind, MeldKind.tirsi);
      expect(m.franc, isTrue);
      expect(m.length, 3);
    });

    test('a quartet of the same rank is a tirsi', () {
      final m = solveMeld(
          [one('7d'), one('7h'), one('7s'), one('7c')], RamiRules.tunisian);
      expect(m!.kind, MeldKind.tirsi);
      expect(m.length, 4);
    });

    test('the two copies of one card may fill a double-deck set', () {
      // Both queens of diamonds plus the other two queens.
      final set = [one('Qd'), one('Qd'), one('Qh'), one('Qs')];
      expect(solveMeld(set, RamiRules.tunisian), isNotNull);
      // The same shape is illegal where duplicates are not allowed.
      expect(
        solveMeld(set, const RamiRules(duplicateCardInSetAllowed: false)),
        isNull,
      );
    });

    test('a pair alone is not a meld', () {
      expect(solveMeld([one('Ad'), one('Kd')], RamiRules.tunisian), isNull);
    });

    test('two red queens of the same rank and suit make a pair, not a tirsi', () {
      // Two identical cards plus a king is not a set, and it is not a run.
      expect(solveMeld([one('Qd'), one('Qd'), one('Kd')], RamiRules.tunisian),
          isNull);
    });

    test('two kings and a joker make a tirsi, and it is not franc', () {
      final m = solveMeld(
          [one('Kd'), one('Kh'), Card.parse('Jk')], RamiRules.tunisian);
      expect(m, isNotNull);
      expect(m!.kind, MeldKind.tirsi);
      expect(m.franc, isFalse, reason: 'a meld using a joker is not franc');
    });

    test('one joker per meld', () {
      expect(
        solveMeld([one('Kd'), Card.parse('Jk'), Card.parse('Jk')],
            RamiRules.tunisian),
        isNull,
      );
    });
  });

  group('suivi (runs)', () {
    test('three consecutive of one suit is a suivi', () {
      final m =
          solveMeld([one('5h'), one('6h'), one('7h')], RamiRules.tunisian);
      expect(m!.kind, MeldKind.suivi);
      expect(m.franc, isTrue);
    });

    test('a run of 5+ is still a run', () {
      final m = solveMeld(
          [one('5h'), one('6h'), one('7h'), one('8h'), one('9h')],
          RamiRules.tunisian);
      expect(m!.kind, MeldKind.suivi);
      expect(m.length, 5);
    });

    test('a gap needs a joker to bridge it', () {
      expect(solveMeld([one('5h'), one('6h'), one('8h')], RamiRules.tunisian),
          isNull);
      final m = solveMeld(
          [one('5h'), one('6h'), one('8h'), Card.parse('Jk')],
          RamiRules.tunisian);
      expect(m, isNotNull);
      expect(m!.length, 4);
    });

    test('two cards plus a joker make a run of three', () {
      final m = solveMeld(
          [one('5h'), one('6h'), Card.parse('Jk')], RamiRules.tunisian);
      expect(m, isNotNull);
      expect(m!.kind, MeldKind.suivi);
      expect(m.length, 3);
    });

    test('K-A-2 is NOT a run, because the ace is low in Tunisia', () {
      expect(
        solveMeld([one('Kh'), one('Ah'), one('2h'), Card.parse('Jk')],
            RamiRules.tunisian),
        isNull,
      );
    });

    test('mixed suits are not a run', () {
      expect(
        solveMeld([one('5h'), one('6s'), one('7c')], RamiRules.tunisian),
        isNull,
      );
    });

    test('a run can be 3+8 long but not longer than maxMeldSize', () {
      final eight = [
        one('5h'),
        one('6h'),
        one('7h'),
        one('8h'),
        one('9h'),
        one('Th'),
        one('Jh'),
        one('Qh'),
      ];
      expect(solveMeld(eight, const RamiRules(maxMeldSize: 8))!.length, 8);
      // The default cap is 7, so the same eight cards are refused.
      expect(solveMeld(eight, RamiRules.tunisian), isNull);
    });
  });

  group('the 51-point opening', () {
    test('a small meld is refused until the threshold is broken', () {
      final s = RamiState.fromCards(
        stock: stock,
        hands: [
          ['5c', '6c', '7c'], // suivi worth 18 - too small
          ['Kd', '9d', '8d'],
        ],
        current: 0,
      );
      expect(s.canMeld(0, idsIn(s, 0, ['5c', '6c', '7c'])), isNull,
          reason: '18 < 51');
    });

    test('a meld reaching 51 is allowed', () {
      // 7+8+9+10+J+Q+K = 54 in one suit.
      final s = RamiState.fromCards(
        stock: stock,
        hands: [
          ['7c', '8c', '9c', 'Tc', 'Jc', 'Qc', 'Kc'],
          ['Kd', '9d', '8d'],
        ],
        current: 0,
      );
      final shape = s.canMeld(0, idsIn(s, 0, ['7c', '8c', '9c', 'Tc', 'Jc', 'Qc', 'Kc']));
      expect(shape, isNotNull);
      expect(s.meldValue(shape!), greaterThanOrEqualTo(51));
    });

    test('once opened, small melds are free', () {
      final s = RamiState.fromCards(
        stock: stock,
        hands: [
          ['5c', '6c', '7c'],
          ['Kd', '9d', '8d'],
        ],
        current: 0,
      );
      s.opened[0] = true;
      expect(s.canMeld(0, idsIn(s, 0, ['5c', '6c', '7c'])), isNotNull);
    });

    test('the threshold is configurable: 61 refuses what 51 allowed', () {
      final notes = ['7c', '8c', '9c', 'Tc', 'Jc', 'Qc', 'Kc']; // 54
      final easy = RamiState.fromCards(
          stock: stock, hands: [notes, ['Kd', '9d', '8d']], current: 0);
      final hard = RamiState.fromCards(
        stock: stock,
        hands: [notes, ['Kd', '9d', '8d']],
        current: 0,
        rules: RamiRules.tunisian61,
      );
      expect(easy.canMeld(0, idsIn(easy, 0, notes)), isNotNull);
      expect(hard.canMeld(0, idsIn(hard, 0, notes)), isNull, reason: '54 < 61');
    });

    test('Tallage 71 counts only franc melds', () {
      // Six naturals + 1 joker: 74 raw points, but not franc, so 0 toward 71.
      final wild = ['7c', '8c', '9c', 'Tc', 'Jc', 'Qc', 'Jk'];
      final s = RamiState.fromCards(
        stock: stock,
        hands: [wild, ['Kd', '9d', '8d']],
        current: 0,
        rules: RamiRules.tallage71,
      );
      expect(s.canMeld(0, idsIn(s, 0, wild)), isNull,
          reason: 'the joker makes it non-franc, so it scores 0 toward 71');

      // The same seven cards without the joker are franc, but only worth 54.
      final franc = ['7c', '8c', '9c', 'Tc', 'Jc', 'Qc', 'Kc'];
      final s2 = RamiState.fromCards(
        stock: stock,
        hands: [franc, ['Kd', '9d', '8d']],
        current: 0,
        rules: RamiRules.tallage71,
      );
      expect(s2.canMeld(0, idsIn(s2, 0, franc)), isNull, reason: '54 < 71');
    });

    test('the simple variant has no opening requirement at all', () {
      final s = RamiState.fromCards(
        stock: stock,
        hands: [
          ['5c', '6c', '7c'],
          ['Kd', '9d', '8d'],
        ],
        current: 0,
        rules: RamiRules.simple,
      );
      expect(s.canMeld(0, idsIn(s, 0, ['5c', '6c', '7c'])), isNotNull);
    });
  });

  group('turn flow', () {
    test('you must be the player on turn', () {
      final s = RamiState.newRound(seed: 3);
      expect(() => s.meld(0, [s.handOf(0).first.id]),
          throwsA(isA<StateError>()));
    });

    test('draw, meld, discard: play moves to the other seat', () {
      final s = RamiState.fromCards(
        stock: stock,
        hands: [
          ['7c', '8c', '9c', 'Tc', 'Jc', 'Qc', 'Kc', '2s'],
          ['Ad'],
        ],
        current: 0,
      );
      final drawn = s.draw(0)!;
      expect(drawn.id, isNot(-1));
      s.meld(0, idsIn(s, 0, ['7c', '8c', '9c', 'Tc', 'Jc', 'Qc', 'Kc']));
      s.discard(0, s.handOf(0).first.id);
      expect(s.current, 1);
      expect(s.discardPile.length, 1);
    });

    test('a card taken from the discard cannot be dropped straight back', () {
      final s = RamiState.fromCards(
        stock: stock,
        hands: [
          ['5c'],
          ['Ad'],
        ],
        discarded: ['9h'],
        current: 0,
      );
      final picked = s.draw(0, fromDiscard: true)!;
      expect(picked.notation, '9h');
      expect(s.canDiscard(0, picked.id), isFalse);
      expect(s.canDiscard(0, s.handOf(0).first.id), isTrue);
      s.discard(0, s.handOf(0).firstWhere((c) => c.id != picked.id).id);
      expect(s.current, 1);
    });

    test('you cannot draw twice in one turn', () {
      final s = RamiState.newRound(seed: 5);
      s.draw(s.current);
      expect(() => s.draw(s.current), throwsA(isA<StateError>()));
    });

    test('you cannot discard before drawing', () {
      final s = RamiState.fromCards(
        stock: stock,
        hands: [
          ['5c', '6c'],
          ['Ad'],
        ],
        current: 0,
      );
      expect(s.canDiscard(0, s.handOf(0).first.id), isFalse);
    });

    test('you cannot meld a card that is not in your hand', () {
      final s = RamiState.fromCards(
        stock: stock,
        hands: [
          ['5c', '6c', '7c'],
          ['Ad'],
        ],
        current: 0,
      );
      expect(s.canMeld(0, idsIn(s, 0, ['5c', '6c', '7c', '9d'])), isNull);
    });
  });

  group('progressive melds', () {
    test('a suivi on the table can be extended', () {
      final s = RamiState.fromCards(
        stock: stock,
        hands: [
          ['7c', '8c', '9c', 'Tc', 'Jc', 'Qc', 'Kc'],
          ['Ad'],
        ],
        current: 0,
      );
      s.meld(0, idsIn(s, 0, ['7c', '8c', '9c', 'Tc', 'Jc', 'Qc']));
      expect(s.melds.single.length, 6);
      s.draw(0);
      s.addToMeld(0, s.melds.single.id, idsIn(s, 0, ['Kc']));
      expect(s.melds.single.length, 7);
      expect(s.melds.single.shape.franc, isTrue);
    });

    test('you may add to another player meld on an open table', () {
      final s = RamiState.fromCards(
        stock: stock,
        hands: [
          ['8c', '9c', 'Tc', 'Jc', 'Qc', 'Kc', '2s'],
          ['7c', '3h'],
        ],
        current: 0,
      );
      s.meld(0, idsIn(s, 0, ['8c', '9c', 'Tc', 'Jc', 'Qc', 'Kc']));
      final meldId = s.melds.single.id;
      s.draw(0);
      s.discard(0, s.handOf(0).first.id);
      expect(s.current, 1);
      s.addToMeld(1, meldId, idsIn(s, 1, ['7c']));
      expect(s.melds.single.length, 7);
      expect(s.melds.single.owner, 0, reason: 'ownership never changes');
    });

    test('a closed table refuses to let others touch the meld', () {
      final s = RamiState.fromCards(
        stock: stock,
        hands: [
          ['8c', '9c', 'Tc', 'Jc', 'Qc', 'Kc', '2s'],
          ['7c', '3h'],
        ],
        current: 0,
        rules: const RamiRules(openMelds: false),
      );
      s.meld(0, idsIn(s, 0, ['8c', '9c', 'Tc', 'Jc', 'Qc', 'Kc']));
      final meldId = s.melds.single.id;
      s.draw(0);
      s.discard(0, s.handOf(0).first.id);
      expect(() => s.addToMeld(1, meldId, idsIn(s, 1, ['7c'])),
          throwsA(isA<StateError>()));
    });

    test('the locked variant refuses any extension', () {
      final s = RamiState.fromCards(
        stock: stock,
        hands: [
          ['7c', '8c', '9c', 'Tc', 'Jc', 'Qc', 'Kc'],
          ['Ad'],
        ],
        current: 0,
        rules: RamiRules.simple,
      );
      s.meld(0, idsIn(s, 0, ['7c', '8c', '9c', 'Tc', 'Jc', 'Qc']));
      expect(() => s.addToMeld(0, s.melds.single.id, idsIn(s, 0, ['Kc'])),
          throwsA(isA<StateError>()));
    });
  });

  group('going out and golf scoring', () {
    // Seat 0 is one card from out: it draws, then has to play that card.
    RamiState nearTheExit({List<int> totals = const [], bool seat1EverMelded = false}) {
      final s = RamiState.fromCards(
        stock: stock,
        hands: [
          <String>[],
          ['Ad', 'Kd'],
        ],
        totals: totals,
        current: 0,
        rules: RamiRules.simple,
      );
      if (seat1EverMelded) s.everMeld[1] = true;
      return s;
    }

    test('emptying your hand ends the round at zero cost', () {
      final s = nearTheExit();
      s.draw(0);
      final move = s.discard(0, s.handOf(0).first.id);
      expect(move.wentOut, isTrue);
      final r = s.result!;
      expect(r.winner, 0);
      expect(r.bills[0].charge, 0, reason: 'going out is free');
      expect(r.bills[0].looseValue, 0);
    });

    test('losers pay the value of the loose cards in their hand', () {
      // 11 + 10 = 21. Seat 1 melded earlier, so it pays cards and not the
      // flat never-melded penalty.
      final s = nearTheExit(seat1EverMelded: true);
      s.draw(0);
      s.discard(0, s.handOf(0).first.id);
      final r = s.result!;
      expect(r.bills[1].looseValue, 21);
      expect(r.bills[1].charge, 21);
      expect(r.totals[1], 21);
      expect(r.totals[0], 0);
    });

    test('a player who never melded pays the flat penalty instead', () {
      final s = nearTheExit();
      s.draw(0);
      s.discard(0, s.handOf(0).first.id);
      final bill = s.result!.bills[1];
      expect(bill.everMeld, isFalse);
      expect(bill.charge, RamiRules.tunisian.neverMeldedPenalty,
          reason: '100 flat, not 21');
    });

    test('melded cards are not charged - only the loose ones are', () {
      // Seat 0 lays its whole hand as one seven-card run and is immediately
      // out, so it pays nothing at all.
      final s = RamiState.fromCards(
        stock: stock,
        hands: [
          ['7c', '8c', '9c', 'Tc', 'Jc', 'Qc', 'Kc'],
          ['Ad', 'Kd'],
        ],
        current: 0,
      );
      final move = s.meld(0, idsIn(s, 0, ['7c', '8c', '9c', 'Tc', 'Jc', 'Qc', 'Kc']));
      expect(move.wentOut, isTrue, reason: 'laying your last cards ends it');
      expect(s.result!.bills[0].charge, 0);
      expect(s.result!.bills[1].looseValue, 21);
      expect(s.result!.bills[1].everMeld, isFalse);
    });

    test('the match ends once somebody crosses the target, lowest wins', () {
      final s = nearTheExit(totals: [0, 999], seat1EverMelded: true);
      s.draw(0);
      s.discard(0, s.handOf(0).first.id);
      final r = s.result!;
      expect(r.totals[1], 1020);
      expect(r.matchOver, isTrue);
    });

    test('no moves are possible after the round is over', () {
      final s = nearTheExit();
      s.draw(0);
      s.discard(0, s.handOf(0).first.id);
      expect(s.roundOver, isTrue);
      expect(() => s.discard(1, s.handOf(1).first.id),
          throwsA(isA<StateError>()));
    });
  });

  group('snapshot round trip', () {
    test('a mid-round match restores exactly, joker layouts included', () {
      final s = RamiState.fromCards(
        stock: stock,
        hands: [
          ['7c', '8c', '9c', 'Tc', 'Jc', 'Qc', 'Kc', '2s', 'Ad'],
          ['5h', '6h', '7h', '3d', '4d'],
        ],
        discarded: ['2h'],
        current: 0,
      );
      s.meld(0, idsIn(s, 0, ['7c', '8c', '9c', 'Tc', 'Jc', 'Qc', 'Kc']));
      s.draw(0);
      s.discard(0, s.handOf(0).first.id);

      final back = RamiState.fromJson(s.toJson());
      expect(back.seed, s.seed);
      expect(back.current, s.current);
      expect(back.stock.map((c) => c.id).toList(),
          s.stock.map((c) => c.id).toList());
      expect(back.discardPile.map((c) => c.id).toList(),
          s.discardPile.map((c) => c.id).toList());
      for (var seat = 0; seat < 2; seat++) {
        expect(back.handOf(seat).map((c) => c.id).toList(),
            s.handOf(seat).map((c) => c.id).toList());
      }
      expect(back.melds.length, 1);
      expect(back.melds.single.length, s.melds.single.length);
      expect(back.melds.single.shape.kind, s.melds.single.shape.kind);
      expect(back.melds.single.shape.layout.map((c) => c.notation).toList(),
          s.melds.single.shape.layout.map((c) => c.notation).toList());
      expect(back.cardsInPlay, s.cardsInPlay);
    });

    test('a joker meld survives the round trip as non-franc', () {
      final s = RamiState.fromCards(
        stock: stock,
        hands: [
          ['Kd', 'Kh', 'Jk', '2s'],
          ['5h', '6h', '7h', '3d'],
        ],
        current: 0,
      );
      s.opened[0] = true;
      s.meld(0, idsIn(s, 0, ['Kd', 'Kh', 'Jk']));
      expect(s.melds.single.shape.franc, isFalse);
      final back = RamiState.fromJson(s.toJson());
      expect(back.melds.single.shape.franc, isFalse);
      expect(back.melds.single.shape.kind, MeldKind.tirsi);
    });
  });

  group('fuzz: 200 full rounds are legal and lossless', () {
    test('no crash, no deadlock, no card created or destroyed', () {
      final rng = Random(20260926);
      for (var seed = 0; seed < 200; seed++) {
        final s = RamiState.newRound(seed: seed * 7 + 1);
        var guard = 0;
        while (!s.roundOver && guard < 5000) {
          guard++;
          final seat = s.current;
          if (!s.drewThisTurn) {
            // Take from the stock most of the time, sometimes the discard.
            final takeDiscard = s.discardPile.isNotEmpty && rng.nextInt(4) == 0;
            if (s.stock.isEmpty && s.discardPile.isEmpty) break;
            s.draw(seat, fromDiscard: takeDiscard && s.stock.isEmpty);
          }
          // Try to open, then to meld: biggest combination first.
          final hand = s.handOf(seat).map((c) => c.id).toList();
          var didMeld = false;
          for (final n in [5, 4, 3]) {
            if (didMeld || hand.length < n) continue;
            for (final combo in _combos(hand, n)) {
              if (s.canMeld(seat, combo) != null) {
                s.meld(seat, combo);
                didMeld = true;
                break;
              }
            }
          }
          final legal =
              s.handOf(seat).where((c) => s.canDiscard(seat, c.id)).toList();
          if (legal.isEmpty) {
            if (s.handOf(seat).isEmpty) break;
            fail('seed $seed: no legal discard for seat $seat');
          }
          s.discard(seat, legal[rng.nextInt(legal.length)].id);
          expect(s.cardsInPlay, 108,
              reason: 'seed $seed lost or gained a card');
        }
        expect(s.roundOver || s.stock.isEmpty, isTrue,
            reason: 'seed $seed deadlocked after $guard turns');
      }
    });
  });
}

/// Every [n]-sized combination of [ids], capped so the fuzz stays quick.
List<List<int>> _combos(List<int> ids, int n) {
  final out = <List<int>>[];
  final pool = ids.take(8).toList();
  void walk(List<int> acc, int start) {
    if (acc.length == n) {
      out.add(List<int>.from(acc));
      return;
    }
    for (var i = start; i < pool.length; i++) {
      acc.add(pool[i]);
      walk(acc, i + 1);
      acc.removeLast();
    }
  }

  walk([], 0);
  return out;
}