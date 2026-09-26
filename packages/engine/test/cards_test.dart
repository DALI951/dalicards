import 'package:engine/engine.dart';
import 'package:test/test.dart';

Card c(int id, Rank rank, Suit suit) => Card(id: id, rank: rank, suit: suit);

void main() {
  group('DeckSpec', () {
    test('chkobba is a 40-card 10-rank pack', () {
      expect(DeckSpec.chkobba.size, 40);
      expect(DeckSpec.chkobba.ranks.length, 10);
      expect(DeckSpec.chkobba.ranks, isNot(contains(Rank.eight)));
      expect(DeckSpec.chkobba.ranks, isNot(contains(Rank.nine)));
      expect(DeckSpec.chkobba.ranks, isNot(contains(Rank.ten)));
    });

    test('rami is two 52-card packs plus jokers', () {
      expect(DeckSpec.rami.size, 108);
      expect(DeckSpec.rami.decks, 2);
      expect(DeckSpec.rami.jokers, 4);
    });

    test('single pack is 52', () {
      expect(DeckSpec.singlePack.size, 52);
    });

    test('size always matches what Deck.shuffled actually builds', () {
      for (final spec in [
        DeckSpec.chkobba,
        DeckSpec.rami,
        DeckSpec.singlePack,
      ]) {
        expect(Deck.shuffled(spec, 4).cards.length, spec.size,
            reason: '${spec.name}: size getter must count 4 suits x decks');
      }
    });
  });

  group('Deck.shuffled', () {
    test('has the exact expected number of cards', () {
      final d = Deck.shuffled(DeckSpec.chkobba, 1);
      expect(d.cards.length, 40);
    });

    test('every id is unique (two identical cards are still distinct)', () {
      final d = Deck.shuffled(DeckSpec.rami, 7);
      final ids = d.cards.map((x) => x.id).toSet();
      expect(ids.length, d.cards.length);
    });

    test('contains no duplicates of rank+suit beyond the deck count', () {
      final d = Deck.shuffled(DeckSpec.rami, 7);
      final natural = d.cards.where((x) => !x.joker);
      final pairs = <String, int>{};
      for (final card in natural) {
        final k = '${card.rank.name}-${card.suit.name}';
        pairs[k] = (pairs[k] ?? 0) + 1;
      }
      expect(pairs.values.every((n) => n == 2), isTrue);
      expect(pairs.length, 52);
    });

    test('jokers are marked and have no rank meaning', () {
      final d = Deck.shuffled(DeckSpec.rami, 3);
      final jokers = d.cards.where((x) => x.joker).toList();
      expect(jokers.length, 4);
      expect(jokers.every((j) => j.id >= 104), isTrue);
    });

    test('same seed gives an identical order (replayable)', () {
      final a = Deck.shuffled(DeckSpec.chkobba, 12345);
      final b = Deck.shuffled(DeckSpec.chkobba, 12345);
      expect(a.cards.map((x) => x.id).toList(),
          b.cards.map((x) => x.id).toList());
    });

    test('different seeds give a different order', () {
      final a = Deck.shuffled(DeckSpec.chkobba, 1).cards.map((x) => x.id).toList();
      final b = Deck.shuffled(DeckSpec.chkobba, 2).cards.map((x) => x.id).toList();
      expect(a, isNot(equals(b)));
    });
  });

  group('FaceValues', () {
    test('tunisian default: J=8 Q=9 K=10, A=1..7 face value', () {
      const v = FaceValues.tunisian;
      expect(v.value(Rank.ace), 1);
      expect(v.value(Rank.seven), 7);
      expect(v.value(Rank.jack), 8);
      expect(v.value(Rank.queen), 9);
      expect(v.value(Rank.king), 10);
    });

    test('swapped variant: J=9 Q=8 K=10', () {
      const v = FaceValues.swapped;
      expect(v.value(Rank.jack), 9);
      expect(v.value(Rank.queen), 8);
      expect(v.value(Rank.king), 10);
    });

    test('the two variants never agree on a rank', () {
      for (final r in [Rank.jack, Rank.queen, Rank.king]) {
        expect(FaceValues.tunisian.value(r),
            isNot(FaceValues.swapped.value(r)));
      }
    });
  });

  group('Deck draw', () {
    test('draw removes from the top and empties cleanly', () {
      final d = Deck.shuffled(DeckSpec.chkobba, 99);
      var n = 0;
      while (d.draw() != null) {
        n++;
      }
      expect(n, 40);
      expect(d.remaining, 0);
      expect(d.draw(), isNull);
      expect(d.top, isNull);
    });

    test('nextSeed is deterministic per deck seed', () {
      final a = Deck.shuffled(DeckSpec.chkobba, 5).nextSeed();
      final b = Deck.shuffled(DeckSpec.chkobba, 5).nextSeed();
      expect(a, b);
    });
  });

  group('Card identity', () {
    test('equality is by id, so a hand can be compared by set', () {
      final hand = [c(1, Rank.ace, Suit.hearts), c(2, Rank.king, Suit.spades)];
      expect(hand.toSet().length, 2);
      expect(hand.first, c(1, Rank.ace, Suit.hearts));
      expect(hand.first, isNot(c(9, Rank.ace, Suit.hearts)));
    });
  });
}
