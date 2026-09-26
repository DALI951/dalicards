/// Card, Suit, Rank and deck construction for every game in DaliCards.
///
/// Pure Dart: no Flutter, no dart:io, no dart:math Random side effects beyond
/// an injected seed, so the whole engine is unit-testable headlessly and gives
/// bit-identical replays for a given seed (required by the online event log).
library;

import 'dart:math';

/// The four suits. Order matters for stable shuffles and for the online
/// event log, so never reorder - append only.
enum Suit { hearts, diamonds, clubs, spades }

/// Ranks in ascending order. Ace is LOW in Chkobba and in Tunisian Rami
/// (K-A-2 sequences are illegal), so [ace] is index 0 on purpose.
enum Rank {
  ace,
  two,
  three,
  four,
  five,
  six,
  seven,
  eight,
  nine,
  ten,
  jack,
  queen,
  king,
}

/// A single physical card. [id] is unique across the whole game (two decks =>
/// two distinct `7 of hearts`) and is the only thing the online API ever
/// uses to identify a card, so it must never be reused inside one match.
class Card {
  const Card({
    required this.id,
    required this.rank,
    required this.suit,
    this.joker = false,
  });

  final int id;
  final Rank rank;
  final Suit suit;

  /// Jokers (Rami only) have no real rank/suit; [rank]/[suit] are placeholders.
  final bool joker;

  @override
  String toString() => joker ? 'Joker#$id' : '${rank.name} of ${suit.name} #$id';

  @override
  bool operator ==(Object other) => other is Card && other.id == id;

  @override
  int get hashCode => id.hashCode;
}

/// Which cards make up a deck. One spec per game (plus the Rami variants).
class DeckSpec {
  const DeckSpec({
    required this.ranks,
    this.decks = 1,
    this.jokers = 0,
    this.name = 'deck',
  });

  /// 40-card Tunisian pack: A,2..7 + J,Q,K in 4 suits (the 8s, 9s and 10s
  /// are not in the pack at all - it is a 10-rank pack, not a 52-card deck
  /// with three ranks punched out of it).
  static const DeckSpec chkobba = DeckSpec(
    name: 'chkobba',
    ranks: [
      Rank.ace,
      Rank.two,
      Rank.three,
      Rank.four,
      Rank.five,
      Rank.six,
      Rank.seven,
      Rank.jack,
      Rank.queen,
      Rank.king,
    ],
  );

  /// Tunisian Rami: two 52-card packs. Jokers configurable per table.
  static const DeckSpec rami = DeckSpec(
    name: 'rami',
    ranks: Rank.values,
    decks: 2,
    jokers: 4,
  );

  /// Single 52-card pack, used by tests and by the Rami single-deck variant.
  static const DeckSpec singlePack = DeckSpec(
    name: 'single',
    ranks: Rank.values,
  );

  final String name;
  final List<Rank> ranks;
  final int decks;
  final int jokers;

  int get size => ranks.length * decks + jokers;
}

/// How the face cards are valued. Tunisian tables disagree, so this is a
/// setting (Dali's table default: J=8, Q=9, K=10).
class FaceValues {
  const FaceValues({
    this.jack = 8,
    this.queen = 9,
    this.king = 10,
  });

  /// The common Tunisian default chosen by Dali.
  static const FaceValues tunisian = FaceValues(jack: 8, queen: 9, king: 10);

  /// The other widespread variant (J and Q swapped).
  static const FaceValues swapped = FaceValues(jack: 10, queen: 9, king: 8);

  final int jack;
  final int queen;
  final int king;

  /// Capture/sum value of a card in Chkobba. Jokers have no value here.
  int value(Rank rank) {
    switch (rank) {
      case Rank.ace:
        return 1;
      case Rank.two:
        return 2;
      case Rank.three:
        return 3;
      case Rank.four:
        return 4;
      case Rank.five:
        return 5;
      case Rank.six:
        return 6;
      case Rank.seven:
        return 7;
      case Rank.jack:
        return jack;
      case Rank.queen:
        return queen;
      case Rank.king:
        return king;
      case Rank.eight:
        return 8;
      case Rank.nine:
        return 9;
      case Rank.ten:
        return 10;
    }
  }
}

/// An immutable, ordered list of cards with a seeded Fisher-Yates shuffle.
///
/// The seed is stored on the deck so any match can be replayed exactly -
/// that is what makes the online event log auditable.
class Deck {
  Deck(this.cards, this.seed)
      : _rng = Random(seed),
        assert(cards.length >= 0);

  /// Builds and shuffles a deck from [spec]. Same [seed] => same order, always.
  factory Deck.shuffled(DeckSpec spec, int seed) {
    final rng = Random(seed);
    final cards = <Card>[];
    var id = 0;
    for (var d = 0; d < spec.decks; d++) {
      for (final suit in Suit.values) {
        for (final rank in spec.ranks) {
          cards.add(Card(id: id++, rank: rank, suit: suit));
        }
      }
    }
    for (var j = 0; j < spec.jokers; j++) {
      cards.add(Card(id: id++, rank: Rank.ace, suit: Suit.clubs, joker: true));
    }
    // Fisher-Yates, driven by the seeded rng so it is reproducible.
    for (var i = cards.length - 1; i > 0; i--) {
      final j = rng.nextInt(i + 1);
      final tmp = cards[i];
      cards[i] = cards[j];
      cards[j] = tmp;
    }
    return Deck(cards, seed);
  }

  final List<Card> cards;
  final int seed;
  final Random _rng;

  int get remaining => cards.length;

  Card? get top => cards.isEmpty ? null : cards.last;

  /// Draws the top card, or null when the deck is empty.
  Card? draw() => cards.isEmpty ? null : cards.removeLast();

  /// The next seed in a reproducible chain, so each deal/round can be derived
  /// from the match seed alone.
  int nextSeed() => _rng.nextInt(0x7fffffff);
}
