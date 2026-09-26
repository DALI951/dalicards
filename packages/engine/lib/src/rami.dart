/// Tunisian Rami (Ã˜Â§Ã™â€žÃ˜Â±Ã˜Â§Ã™â€¦Ã™Å ) rules engine.
///
/// Pure Dart, no Flutter, deterministic for a given seed so the online event
/// log can replay a match card for card.
///
/// ## Where the numbers come from
///
/// Cross-checked against the Tunisian-facing rule pages (chkobba.gg "Tunisian
/// Rami", nasro.uk North-Africa Rami) and the Maghreb "Tallage" variant
/// (rasderb.com):
///
/// * 108 cards: two 52-card packs + **four** jokers.
/// * 14 cards per player in the 2-player Tunisian default.
/// * The **first** meld of a round must reach **51 points** (some tables play
///   61; the Moroccan Tallage variant plays 71 and counts only jokerless
///   melds).
/// * Card values: 2-10 at face value, J/Q/K = 10, ace = 11, joker = 20.
/// * A meld is a *tirsi* (3-4 of a kind, suits distinct) or a *suivis* (3+
///   consecutive of one suit). Ace is LOW, so K-A-2 is never a run.
/// * One joker per meld; a meld containing a joker is not *franc*.
/// * You draw from the stock or the top of the discard, may meld, and must
///   discard to end the turn. A card taken from the discard cannot be
///   discarded straight back.
/// * Go out by emptying your hand. It is a **golf** game: every loser pays the
///   value of the loose cards still in hand, a player who never melded pays a
///   flat penalty instead, and the LOWEST cumulative total wins the match.
///
/// Every one of those is a flag on [RamiRules] rather than a hardcoded
/// assumption, because tables genuinely disagree and a house variant must
/// never need a code change.
library;

import 'cards.dart';

/// The two meld shapes, in the Tunisian names players actually use.
enum MeldKind {
  /// Ã˜ÂªÃ™Å Ã˜Â±Ã˜Â³Ã™Å  - 3 or 4 cards of the same rank, suits distinct.
  tirsi,

  /// Ã˜Â³Ã™Ë†Ã™Å Ã™ÂÃ™Å  - 3 or more consecutive cards of one suit.
  suivi,
}

/// A validated meld: the shape, whether it is jokerless (*franc*), and the
/// concrete card layout the jokers stand in for (so the UI can draw it and the
/// engine can value it without re-solving).
class MeldShape {
  const MeldShape({
    required this.kind,
    required this.franc,
    required this.layout,
  });

  final MeldKind kind;

  /// True when no joker was used. Only franc melds count toward the Tallage 71
  /// opening requirement.
  final bool franc;

  /// The real cards this meld represents, with each joker assigned to the
  /// rank/suit it is standing in for.
  final List<Card> layout;

  int get length => layout.length;
  @override
  String toString() =>
      '${kind.name}${franc ? '' : '+joker'} ${layout.map((c) => c.notation).join(' ')}';
}

/// A meld that is on the table, owned by the player who laid it.
///
/// [sourceIds] are the *physical* cards that were laid, jokers included, and
/// are what a snapshot stores. [shape] is the solved layout, recomputed on
/// load, so a restored match is byte-identical to the original.
class RamiMeld {
  RamiMeld({
    required this.id,
    required this.owner,
    required this.shape,
    required this.sourceIds,
  });

  final int id;
  final int owner;
  final List<int> sourceIds;
  MeldShape shape;

  List<Card> get cards => shape.layout;
  bool get isFranc => shape.franc;

  @override
  String toString() => 'meld#$id by seat$owner ${shape}';
}

/// What one action did. Returned so the online event log, the bot and the UI
/// can all react from a single value.
class RamiMove {
  const RamiMove({
    required this.seat,
    required this.drewFromStock,
    this.drewFromDiscard,
    this.melded = const [],
    this.extended = const {},
    this.discarded,
    this.wentOut = false,
    this.notes = const [],
  });

  final int seat;
  final bool drewFromStock;
  final Card? drewFromDiscard;
  final List<RamiMeld> melded;

  /// meldId -> the shape it became after being extended.
  final Map<int, MeldShape> extended;
  final Card? discarded;
  final bool wentOut;
  final List<String> notes;
  @override
  String toString() => 'seat$seat drewFromStock=$drewFromStock '
      'melded=${melded.length} extended=${extended.length} '
      'discarded=${discarded?.notation} wentOut=$wentOut';
}

/// One player's bill at the end of a round.
class RamiBill {
  const RamiBill({
    required this.seat,
    required this.wentOut,
    required this.everMeld,
    required this.looseValue,
    required this.meldedValue,
    required this.charge,
  });

  final int seat;
  final bool wentOut;
  final bool everMeld;
  final int looseValue;
  final int meldedValue;

  /// What this player actually pays: 0 if they went out, the loose-card value
  /// otherwise, or the flat penalty if they never melded.
  final int charge;

  @override
  String toString() => 'seat$seat wentOut=$wentOut everMeld=$everMeld '
      'loose=$looseValue melded=$meldedValue charge=$charge';
}

/// How a round finished.
class RamiRoundResult {
  const RamiRoundResult({
    required this.bills,
    required this.totals,
    required this.winner,
    required this.matchOver,
  });

  final List<RamiBill> bills;

  /// Cumulative match totals after this round, per seat.
  final List<int> totals;

  /// The seat that emptied their hand, if anybody did.
  final int? winner;

  /// Golf: the match ends when somebody reaches the target, and the *lowest*
  /// total wins, so crossing the target is bad.
  final bool matchOver;

  @override
  String toString() => 'winner=$winner totals=$totals matchOver=$matchOver';
}

/// Everything that changes between Rami tables. Defaults are the Tunisian
/// 2-player standard verified above.
class RamiRules {
  const RamiRules({
    this.name = 'tunisian',
    this.seats = 2,
    this.handSize = 14,
    this.decks = 2,
    this.jokers = 4,
    this.openingThreshold = 51,
    this.openingFrancOnly = false,
    this.aceValue = 11,
    this.faceValue = 10,
    this.jokerValue = 20,
    this.maxMeldSize = 7,
    this.oneJokerPerMeld = true,
    this.requireNaturalInMeld = true,
    this.progressiveMelds = true,
    this.openMelds = true,
    this.mustUsePickedDiscard = true,
    this.neverMeldedPenalty = 100,
    this.duplicateCardInSetAllowed = true,
    this.matchTarget = 1000,
  });

  /// The Tunisian default: 51-point opening, four jokers, 14 cards.
  static const RamiRules tunisian = RamiRules();

  /// Stricter opening threshold played in some Tunisian homes.
  static const RamiRules tunisian61 =
      RamiRules(name: 'tunisian-61', openingThreshold: 61);

  /// The Maghreb "Tallage" variant: 71 points and only jokerless melds count.
  static const RamiRules tallage71 = RamiRules(
    name: 'tallage-71',
    openingThreshold: 71,
    openingFrancOnly: true,
  );

  /// No opening requirement, and melds are locked once laid.
  static const RamiRules simple =
      RamiRules(name: 'simple', openingThreshold: 0, progressiveMelds: false);

  final String name;
  final int seats;
  final int handSize;
  final int decks;
  final int jokers;

  /// Minimum value of the first meld of a round. 0 disables the requirement.
  final int openingThreshold;

  /// When true only jokerless (franc) melds count toward [openingThreshold].
  final bool openingFrancOnly;

  final int aceValue;
  final int faceValue;
  final int jokerValue;
  final int maxMeldSize;
  final bool oneJokerPerMeld;
  final bool requireNaturalInMeld;
  final bool progressiveMelds;
  final bool openMelds;
  final bool mustUsePickedDiscard;
  final int neverMeldedPenalty;

  /// In double-deck play a tirsi may use both copies of one card (two red
  /// queens). Off means suits must always be distinct.
  final bool duplicateCardInSetAllowed;
  final int matchTarget;

  int get teams => 1;
  int teamOf(int seat) => 0;

  DeckSpec get deckSpec => DeckSpec(
        name: 'rami',
        ranks: Rank.values,
        decks: decks,
        jokers: jokers,
      );

  int get totalCards => deckSpec.size;

  @override
  String toString() => 'RamiRules($name)';
}

/// Hands out unique ids to fixture cards. The same notation can appear twice
/// (the two copies of a card in a double deck) and must still be distinct.
/// Ids start high so a fixture card never collides with a real deck id.
class _IdGen {
  int _next = 1000;
  Card card(Card c) => Card(
        id: _next++,
        rank: c.rank,
        suit: c.suit,
        joker: c.joker,
      );
}

/// Card values for Rami. Distinct from Chkobba's [FaceValues]: in Rami the
/// ace is 11 and every face card is a flat 10, and the joker is 20.
int ramiValue(Card c, RamiRules r) {
  if (c.joker) return r.jokerValue;
  return switch (c.rank) {
    Rank.ace => r.aceValue,
    Rank.jack || Rank.queen || Rank.king => r.faceValue,
    // Rami always uses the full 13-rank pack, so index+2 is the pip value.
    _ => c.rank.index + 2,
  };
}

/// Solves whether [cards] form one valid meld, and if so what it actually is.
///
/// Jokers are wild: the solver assigns each one to the rank/suit it is standing
/// in for and returns the concrete layout. Runs never wrap, so K-A-2 is
/// rejected because [Rank.ace] is index 0.
MeldShape? solveMeld(List<Card> cards, RamiRules rules) {
  if (cards.length < 3 || cards.length > rules.maxMeldSize) return null;

  final naturals = cards.where((c) => !c.joker).toList();
  final wilds = cards.where((c) => c.joker).length;

  if (rules.requireNaturalInMeld && naturals.isEmpty) return null;
  if (rules.oneJokerPerMeld && wilds > 1) return null;

  // A tirsi is cheaper to satisfy, so try it first; a card set of 3-4 that is
  // also a run is not a realistic ambiguity.
  final tirsi = _solveTirsi(cards, naturals, wilds, rules);
  if (tirsi != null) return tirsi;
  return _solveSuivi(cards, naturals, wilds, rules);
}

MeldShape? _solveTirsi(
    List<Card> cards, List<Card> naturals, int wilds, RamiRules rules) {
  if (cards.length > 4) return null;
  // A tirsi is 3 or 4 cards, every natural the same rank.
  if (naturals.isNotEmpty) {
    final rank = naturals.first.rank;
    if (naturals.any((c) => c.rank != rank)) return null;
  }
  // Suits must be distinct, except that double-deck play allows the two exact
  // copies of one card inside a quartet.
  final seen = <int, int>{};
  for (final c in naturals) {
    final key = c.suit.index;
    seen[key] = (seen[key] ?? 0) + 1;
    if (seen[key]! > 1 && !rules.duplicateCardInSetAllowed) return null;
    if (seen[key]! > 2) return null;
  }

  final target = naturals.isEmpty ? Rank.ace : naturals.first.rank;
  // Fill the missing suits with the wilds.
  final layout = <Card>[...naturals];
  final used = seen.keys.toSet();
  for (var i = 0; i < wilds && used.length < 4; i++) {
    final free = Suit.values.firstWhere((s) => !used.contains(s.index));
    used.add(free.index);
    layout.add(Card(id: -1 - i, rank: target, suit: free, joker: true));
  }
  return MeldShape(
    kind: MeldKind.tirsi,
    franc: wilds == 0,
    layout: layout,
  );
}

MeldShape? _solveSuivi(
    List<Card> cards, List<Card> naturals, int wilds, RamiRules rules) {
  if (naturals.isEmpty) return null;
  final suit = naturals.first.suit;
  if (naturals.any((c) => c.suit != suit)) return null;

  final ranks = naturals.map((c) => c.rank.index).toList()..sort();
  final lo = ranks.first;
  final hi = ranks.last;
  final span = hi - lo + 1;

  // Every gap inside the natural range must be paid for by a wild.
  if (span - naturals.length > wilds) return null;
  // A run of only two naturals still needs a third card to be a run at all.
  if (span < 3 && wilds < 3 - span) return null;

  var start = lo;
  var end = hi;
  // Wilds that are not needed to bridge a gap must still be used, otherwise
  // they would silently vanish from the meld. They extend the run instead.
  final gaps = span - naturals.length;
  var need = wilds - gaps;
  if (need < 0) return null;
  // A run also has to be at least three cards long.
  final minNeed = 3 - span;
  if (minNeed > 0) need = minNeed > need ? minNeed : need;

  final right = need < Rank.values.length - 1 - end
      ? need
      : Rank.values.length - 1 - end;
  final left = need - right;
  if (left > start) return null;
  end += right;
  start -= left;
  if (end - start + 1 < 3) return null;
  if (end - start + 1 > rules.maxMeldSize) return null;

  final layout = <Card>[];
  final naturalByRank = <int, Card>{};
  for (final c in naturals) {
    naturalByRank[c.rank.index] = c;
  }
  var wildId = -1;
  for (var r = start; r <= end; r++) {
    final nat = naturalByRank[r];
    if (nat != null) {
      layout.add(nat);
    } else {
      wildId--;
      layout.add(Card(id: wildId, rank: Rank.values[r], suit: suit, joker: true));
    }
  }
  return MeldShape(
    kind: MeldKind.suivi,
    franc: wilds == 0,
    layout: layout,
  );
}

/// The face value of the cards a meld locks up. A joker inside a meld is worth
/// the card it stands in for, not the joker penalty value.
int ramiMeldValue(RamiMeld m, RamiRules r) =>
    m.shape.layout.fold<int>(0, (a, c) => a + ramiValue(c, r));

/// A full Rami round: dealing, drawing, melding, discarding, going out, and
/// the golf scoring at the end.
class RamiState {
  RamiState._({
    required this.rules,
    required this.seed,
    required this.stock,
    required this.hands,
    required this.discardPile,
    required this.totals,
    this.dealer = 0,
  });

  final RamiRules rules;
  int seed;

  List<Card> stock;
  List<List<Card>> hands;
  List<Card> discardPile;
  List<RamiMeld> melds = [];
  List<int> totals;
  int dealer;

  int current = 0;
  int turnIndex = 0;
  int _nextMeldId = 0;

  /// Per seat: has this player broken the opening threshold yet this round?
  List<bool> opened = [];

  /// Per seat: has this player laid any meld this round (drives the
  /// never-melded penalty)?
  List<bool> everMeld = [];

  /// Set once a player picks the top of the discard; they may not put it
  /// straight back when [RamiRules.mustUsePickedDiscard] is on.
  Card? pickedThisTurn;

  bool drewThisTurn = false;
  bool discardedThisTurn = false;
  int? wentOutSeat;
  RamiRoundResult? result;

  int get seats => rules.seats;
  bool get roundOver => result != null;

  /// Every card is always in exactly one of these piles. The fuzz test in the
  /// suite asserts this after every single action.
  int get cardsInPlay =>
      stock.length +
      discardPile.length +
      hands.fold<int>(0, (a, h) => a + h.length) +
      melds.fold<int>(0, (a, m) => a + m.cards.length);

  List<Card> handOf(int seat) => hands[seat];
  int handCount(int seat) => hands[seat].length;

  // -- setup ---------------------------------------------------------------

  /// Deals a fresh round for [seed]. Deterministic.
  factory RamiState.newRound({
    int seed = 0,
    RamiRules rules = RamiRules.tunisian,
  }) {
    final deck = Deck.shuffled(rules.deckSpec, seed);
    final s = RamiState._(
      rules: rules,
      seed: seed,
      stock: deck.cards,
      hands: List.generate(rules.seats, (_) => <Card>[]),
      discardPile: [],
      totals: List<int>.filled(rules.seats, 0),
    );
    for (var i = 0; i < rules.handSize; i++) {
      for (var seat = 0; seat < rules.seats; seat++) {
        if (s.stock.isNotEmpty) s.hands[seat].add(s.stock.removeLast());
      }
    }
    if (s.stock.isNotEmpty) s.discardPile.add(s.stock.removeLast());
    s.opened = List<bool>.filled(rules.seats, false);
    s.everMeld = List<bool>.filled(rules.seats, false);
    s.current = (rules.seats > 1) ? 1 : 0; // left of the dealer opens
    return s;
  }

  /// Test/fixture constructor: build an exact position from notation.
  ///
  /// Card ids are assigned from the deck catalogue so two cards with the same
  /// notation still get distinct ids (the two copies in a double deck).
  factory RamiState.fromCards({
    List<String> stock = const [],
    List<List<String>> hands = const [],
    List<String> discarded = const [],
    List<int> totals = const [],
    RamiRules rules = RamiRules.tunisian,
    int seed = 0,
    int dealer = 0,
    int current = 0,
  }) {
    final nextId = _IdGen();
    final build = (List<String> notes) =>
        notes.map((n) => nextId.card(Card.parse(n))).toList();

    final s = RamiState._(
      rules: rules,
      seed: seed,
      stock: build(stock),
      hands: List.generate(
        rules.seats,
        (i) => i < hands.length ? build(hands[i]) : <Card>[],
      ),
      discardPile: build(discarded),
      totals: totals.isEmpty
          ? List<int>.filled(rules.seats, 0)
          : List<int>.from(totals),
      dealer: dealer,
    );
    s.opened = List<bool>.filled(rules.seats, false);
    s.everMeld = List<bool>.filled(rules.seats, false);
    s.current = current;
    s.drewThisTurn = false;
    s.discardedThisTurn = false;
    return s;
  }

  // -- turn flow -----------------------------------------------------------

  /// Takes one card. From the stock by default, or from the face-up discard
  /// when [fromDiscard] is set.
  Card? draw(int seat, {bool fromDiscard = false}) {
    _assertTurn(seat);
    if (drewThisTurn) {
      throw StateError('seat $seat already drew this turn');
    }
    Card card;
    if (fromDiscard) {
      if (discardPile.isEmpty) throw StateError('the discard pile is empty');
      card = discardPile.removeLast();
      pickedThisTurn = card;
    } else {
      if (stock.isEmpty) throw StateError('the stock is empty');
      card = stock.removeLast();
    }
    hands[seat].add(card);
    drewThisTurn = true;
    return card;
  }

  /// The value of a meld for the opening threshold, honouring
  /// [RamiRules.openingFrancOnly].
  int meldValue(MeldShape shape) {
    if (rules.openingFrancOnly && !shape.franc) return 0;
    return shape.layout.fold<int>(0, (a, c) => a + ramiValue(c, rules));
  }

  /// Is [cardIds] a legal meld for [seat] right now?
  ///
  /// Checks the shape, the per-meld joker limit, the opening threshold for a
  /// player who has not opened yet, and that the cards really are in the hand.
  MeldShape? canMeld(int seat, List<int> cardIds) {
    final picked = _pick(seat, cardIds);
    if (picked == null) return null;
    final shape = solveMeld(picked, rules);
    if (shape == null) return null;
    if (!opened[seat] && !_breaksOpening(shape)) return null;
    return shape;
  }

  bool _breaksOpening(MeldShape shape) {
    if (rules.openingThreshold <= 0) return true;
    return meldValue(shape) >= rules.openingThreshold;
  }

  /// Lays a meld from the hand.
  RamiMove meld(int seat, List<int> cardIds) {
    _assertTurn(seat);
    final shape = canMeld(seat, cardIds);
    if (shape == null) {
      throw StateError('seat $seat cannot meld ${cardIds.join(",")}');
    }
    for (final c in _pick(seat, cardIds)!) {
      hands[seat].remove(c);
    }
    final m = RamiMeld(
      id: _nextMeldId++,
      owner: seat,
      shape: shape,
      sourceIds: List<int>.from(cardIds),
    );
    melds.add(m);
    opened[seat] = true;
    everMeld[seat] = true;
    return RamiMove(
      seat: seat,
      drewFromStock: drewThisTurn && pickedThisTurn == null,
      drewFromDiscard: pickedThisTurn,
      melded: [m],
    );
  }

  /// Adds cards to a meld already on the table, growing or completing it.
  ///
  /// Gated on [RamiRules.progressiveMelds]; [RamiRules.openMelds] additionally
  /// allows adding to *another* player's meld.
  RamiMove addToMeld(int seat, int meldId, List<int> cardIds) {
    _assertTurn(seat);
    if (!rules.progressiveMelds) {
      throw StateError('this table does not allow extending melds');
    }
    final m = melds.firstWhere(
      (x) => x.id == meldId,
      orElse: () => throw StateError('no meld #$meldId'),
    );
    if (m.owner != seat && !rules.openMelds) {
      throw StateError('seat $seat cannot touch seat ${m.owner}\'s meld');
    }
    final picked = _pick(seat, cardIds);
    if (picked == null) throw StateError('those cards are not in seat $seat\'s hand');

    // A joker already in the meld cannot be "moved": re-solve the whole thing.
    final combined = [...m.cards, ...picked];
    final shape = solveMeld(combined, rules);
    if (shape == null) {
      throw StateError('that does not complete meld #$meldId');
    }
    if (!opened[seat] && !_breaksOpening(shape)) {
      throw StateError('seat $seat has not broken ${rules.openingThreshold} yet');
    }
    for (final c in picked) {
      hands[seat].remove(c);
    }
    m.shape = shape;
    m.sourceIds.addAll(picked.map((c) => c.id));
    opened[seat] = true;
    everMeld[seat] = true;
    return RamiMove(
      seat: seat,
      drewFromStock: drewThisTurn && pickedThisTurn == null,
      drewFromDiscard: pickedThisTurn,
      extended: {m.id: shape},
    );
  }

  /// Can [cardId] legally be discarded right now?
  bool canDiscard(int seat, int cardId) {
    if (discardedThisTurn) return false;
    if (hands[seat].isEmpty) return false;
    final c = _byId(hands[seat], cardId);
    if (c == null) return false;
    if (rules.mustUsePickedDiscard && c == pickedThisTurn) return false;
    return true;
  }

  /// Ends the turn by discarding one card, and passes play on.
  RamiMove discard(int seat, int cardId) {
    _assertTurn(seat);
    if (!canDiscard(seat, cardId)) {
      throw StateError('seat $seat cannot discard card $cardId now');
    }
    final c = hands[seat].firstWhere((x) => x.id == cardId);
    hands[seat].remove(c);
    discardPile.add(c);
    discardedThisTurn = true;
    return _endTurn(seat, discarded: c);
  }

  RamiMove _endTurn(int seat, {Card? discarded}) {
    final wentOut = hands[seat].isEmpty;
    final notes = <String>[];
    if (wentOut) {
      wentOutSeat = seat;
      notes.add('seat$seat went out');
      _scoreRound();
      return RamiMove(
        seat: seat,
        drewFromStock: drewThisTurn && pickedThisTurn == null,
        drewFromDiscard: pickedThisTurn,
        discarded: discarded,
        wentOut: true,
        notes: notes,
      );
    }
    turnIndex++;
    current = (seat + 1) % seats;
    drewThisTurn = false;
    discardedThisTurn = false;
    pickedThisTurn = null;
    return RamiMove(
      seat: seat,
      drewFromStock: false,
      discarded: discarded,
      notes: notes,
    );
  }

  /// Passes the turn without melding or discarding. Only allowed when the
  /// player has drawn, so it cannot be used to stall forever.
  RamiMove pass(int seat) {
    _assertTurn(seat);
    if (!drewThisTurn) {
      throw StateError('seat $seat must draw before passing');
    }
    return _endTurn(seat);
  }

  void _assertTurn(int seat) {
    if (roundOver) throw StateError('the round is already over');
    if (seat != current) {
      throw StateError('it is seat $current\'s turn, not seat $seat\'s');
    }
  }

  // -- scoring -------------------------------------------------------------

  RamiRoundResult _scoreRound() {
    final bills = <RamiBill>[];
    for (var seat = 0; seat < seats; seat++) {
      final wentOut = seat == wentOutSeat;
      final loose = hands[seat].fold<int>(0, (a, c) => a + ramiValue(c, rules));
      final melded = melds
          .where((m) => m.owner == seat)
          .fold<int>(0, (a, m) => a + ramiMeldValue(m, rules));
      int charge;
      if (wentOut) {
        charge = 0;
      } else if (!everMeld[seat] && rules.neverMeldedPenalty > 0) {
        charge = rules.neverMeldedPenalty;
      } else {
        charge = loose;
      }
      bills.add(RamiBill(
        seat: seat,
        wentOut: wentOut,
        everMeld: everMeld[seat],
        looseValue: loose,
        meldedValue: melded,
        charge: charge,
      ));
      totals[seat] += charge;
    }
    final r = RamiRoundResult(
      bills: bills,
      totals: List<int>.from(totals),
      winner: wentOutSeat,
      matchOver: totals.any((t) => t >= rules.matchTarget),
    );
    result = r;
    return r;
  }

  // -- snapshot ------------------------------------------------------------

  Map<String, dynamic> toJson() => {
        'rules': rules.name,
        'seed': seed,
        'dealer': dealer,
        'current': current,
        'turnIndex': turnIndex,
        'drewThisTurn': drewThisTurn,
        'discardedThisTurn': discardedThisTurn,
        'pickedThisTurn': pickedThisTurn?.id,
        'stock': stock.map((c) => c.id).toList(),
        'hands': hands.map((h) => h.map((c) => c.id).toList()).toList(),
        'discard': discardPile.map((c) => c.id).toList(),
        'melds': melds
            .map((m) => {
                  'id': m.id,
                  'owner': m.owner,
                  'kind': m.shape.kind.name,
                  'franc': m.shape.franc,
                  'sourceIds': m.sourceIds,
                  'layout': m.shape.layout
                      .map((c) => c.joker
                          ? 'J${c.rank.name}/${c.suit.name}'
                          : c.notation)
                      .toList(),
                })
            .toList(),
        'totals': totals,
        'opened': opened,
        'everMeld': everMeld,
        'wentOutSeat': wentOutSeat,
      };

  /// Rebuilds a round from [toJson]. Ids are preserved exactly, so a restored
  /// match replays identically - this is what the online event log relies on.
  factory RamiState.fromJson(Map<String, dynamic> j) {
    const byName = {
      'tunisian': RamiRules.tunisian,
      'tunisian-61': RamiRules.tunisian61,
      'tallage-71': RamiRules.tallage71,
      'simple': RamiRules.simple,
    };
    final rules = byName[j['rules'] as String] ?? RamiRules.tunisian;

    // The joker layout of a meld is re-derived by re-solving it, so the
    // snapshot only has to store the physical card ids.
    final all = <int, Card>{};
    Card byId(int id) => all[id]!;
    void reg(List<dynamic> raw) {
      for (final id in raw.cast<int>()) {
        if (all.containsKey(id)) continue;
        final card = _cardById(id, rules);
        all[id] = card;
      }
    }

    final s = RamiState._(
      rules: rules,
      seed: j['seed'] as int,
      stock: [],
      hands: List.generate(rules.seats, (_) => <Card>[]),
      discardPile: [],
      totals: List<int>.from(j['totals'].cast<int>()),
      dealer: j['dealer'] as int? ?? 0,
    );
    reg(j['stock'].cast<dynamic>());
    for (var seat = 0; seat < rules.seats; seat++) {
      final raw = (j['hands'][seat] as List).cast<dynamic>();
      reg(raw);
      s.hands[seat] = raw.cast<int>().map(byId).toList();
    }
    reg(j['discard'].cast<dynamic>());
    s.discardPile = (j['discard'] as List).cast<int>().map(byId).toList();
    s.stock = (j['stock'] as List).cast<int>().map(byId).toList();

    for (final raw in (j['melds'] as List).cast<Map<String, dynamic>>()) {
      final ids = (raw['sourceIds'] as List).cast<int>();
      reg(ids);
      final shape = solveMeld(ids.map(byId).toList(), rules);
      if (shape == null) {
        throw FormatException('meld ${raw['id']} does not re-solve', '$raw');
      }
      s.melds.add(RamiMeld(
        id: raw['id'] as int,
        owner: raw['owner'] as int,
        shape: shape,
        sourceIds: List<int>.from(ids),
      ));
    }
    s._nextMeldId = s.melds.isEmpty
        ? 0
        : s.melds.map((m) => m.id).reduce((a, b) => a > b ? a : b) + 1;
    s.current = j['current'] as int;
    s.turnIndex = j['turnIndex'] as int? ?? 0;
    s.drewThisTurn = j['drewThisTurn'] as bool? ?? false;
    s.discardedThisTurn = j['discardedThisTurn'] as bool? ?? false;
    final picked = j['pickedThisTurn'] as int?;
    s.pickedThisTurn = picked == null ? null : byId(picked);
    s.opened = List<bool>.from(j['opened'].cast<bool>());
    s.everMeld = List<bool>.from(j['everMeld'].cast<bool>());
    s.wentOutSeat = j['wentOutSeat'] as int?;
    if (s.wentOutSeat != null) s._scoreRound();
    return s;
  }

  /// Rebuilds a single card from a real deck id, using the same catalogue
  /// order as [Deck.shuffled] (decks, then suits, then ranks, then jokers).
  static Card _cardById(int id, RamiRules rules) {
    var n = id;
    for (var d = 0; d < rules.decks; d++) {
      for (final suit in Suit.values) {
        for (final rank in rules.deckSpec.ranks) {
          if (n-- == 0) return Card(id: id, rank: rank, suit: suit);
        }
      }
    }
    for (var i = 0; i < rules.jokers; i++) {
      if (n-- == 0) {
        return Card(id: id, rank: Rank.ace, suit: Suit.clubs, joker: true);
      }
    }
    throw RangeError('card id $id is outside the ${rules.name} deck');
  }

  // -- helpers -------------------------------------------------------------

  List<Card>? _pick(int seat, List<int> ids) {
    final out = <Card>[];
    for (final id in ids) {
      final c = _byId(hands[seat], id);
      if (c == null) return null;
      out.add(c);
    }
    return out;
  }

  /// Finds a card by id in a hand. Written by hand rather than with
  /// `firstOrNull` so the engine keeps zero package dependencies.
  static Card? _byId(List<Card> hand, int id) {
    for (final c in hand) {
      if (c.id == id) return c;
    }
    return null;
  }

  @override
  String toString() => 'RamiState(${rules.name} seed=$seed seat$current '
      'hands=${hands.map((h) => h.length).toList()} '
      'stock=${stock.length} discard=${discardPile.length} melds=${melds.length})';
}
