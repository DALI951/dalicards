/// Chkobba (شكبة) - the Tunisian national card game.
///
/// Scopa-derived fishing game: play one card, capture it together with any
/// table cards whose values equal it (one card, or a sum of several), sweep the
/// table for a Chkobba.
///
/// Every rule that differs from table to table is a field on [ChkobbaRules],
/// never a branch buried in the logic, so a rules change is a settings change
/// and the online server can validate a move against the same flags.
library;

import 'dart:math';

import 'cards.dart';

// ---------------------------------------------------------------------------
// Rules
// ---------------------------------------------------------------------------

/// How a card value ties are broken and whether the player may decline a
/// capture. Kept as an enum so the server can store it as a small int.
enum CapturePriority {
  /// A matching single always beats a matching sum (the common Tunisian rule).
  singleFirst,

  /// The player picks whichever capture they like, including none.
  bestSum,
}

class ChkobbaRules {
  const ChkobbaRules({
    this.faceValues = FaceValues.tunisian,
    this.seats = 2,
    this.partners = false,
    this.dealSize = 3,
    this.tableCards = 4,
    this.targetScore = 21,
    this.winByTwo = true,
    this.capturePriority = CapturePriority.singleFirst,
    this.chkobbaOnFinalCard = false,
    this.redealOnThreeSameRank = true,
    this.scoreKarta = true,
    this.scoreDinari = true,
    this.scoreBarmila = true,
    this.scoreSabaa = true,
    this.scoreChkobba = true,
    this.barmilaTiebreakOnSixes = true,
  });

  /// Dali's table: 2 players, 3 cards a deal, first to 21, win by 2,
  /// J=8 Q=9 K=10, a single capture beats a sum, no Chkobba on the last card.
  static const ChkobbaRules tunisianDefault = ChkobbaRules();

  /// Same, but four players sitting in two partnerships.
  static const ChkobbaRules twoVTwo = ChkobbaRules(
    seats: 4,
    partners: true,
  );

  final FaceValues faceValues;
  final int seats;
  final bool partners;
  final int dealSize;
  final int tableCards;
  final int targetScore;
  final bool winByTwo;
  final CapturePriority capturePriority;
  final bool chkobbaOnFinalCard;
  final bool redealOnThreeSameRank;

  final bool scoreKarta;
  final bool scoreDinari;
  final bool scoreBarmila;
  final bool scoreSabaa;
  final bool scoreChkobba;
  final bool barmilaTiebreakOnSixes;

  DeckSpec get deckSpec => DeckSpec.chkobba;

  int valueOf(Card c) => faceValues.value(c.rank);

  /// Team index for a seat. In 2v2 partners sit opposite each other.
  int teamOf(int seat) => partners ? seat % 2 : seat;

  int get teamCount => partners ? 2 : seats;

  Map<String, dynamic> toJson() => {
        'faceValues': {
          'jack': faceValues.jack,
          'queen': faceValues.queen,
          'king': faceValues.king,
        },
        'seats': seats,
        'partners': partners,
        'dealSize': dealSize,
        'tableCards': tableCards,
        'targetScore': targetScore,
        'winByTwo': winByTwo,
        'capturePriority': capturePriority.index,
        'chkobbaOnFinalCard': chkobbaOnFinalCard,
        'redealOnThreeSameRank': redealOnThreeSameRank,
        'scoreKarta': scoreKarta,
        'scoreDinari': scoreDinari,
        'scoreBarmila': scoreBarmila,
        'scoreSabaa': scoreSabaa,
        'scoreChkobba': scoreChkobba,
        'barmilaTiebreakOnSixes': barmilaTiebreakOnSixes,
      };

  static ChkobbaRules fromJson(Map<String, dynamic> j) {
    final fv = (j['faceValues'] ?? {}) as Map<String, dynamic>;
    return ChkobbaRules(
      faceValues: FaceValues(
        jack: (fv['jack'] ?? 8) as int,
        queen: (fv['queen'] ?? 9) as int,
        king: (fv['king'] ?? 10) as int,
      ),
      seats: (j['seats'] ?? 2) as int,
      partners: (j['partners'] ?? false) as bool,
      dealSize: (j['dealSize'] ?? 3) as int,
      tableCards: (j['tableCards'] ?? 4) as int,
      targetScore: (j['targetScore'] ?? 21) as int,
      winByTwo: (j['winByTwo'] ?? true) as bool,
      capturePriority: CapturePriority.values[
          (j['capturePriority'] ?? 0) as int],
      chkobbaOnFinalCard: (j['chkobbaOnFinalCard'] ?? false) as bool,
      redealOnThreeSameRank: (j['redealOnThreeSameRank'] ?? true) as bool,
      scoreKarta: (j['scoreKarta'] ?? true) as bool,
      scoreDinari: (j['scoreDinari'] ?? true) as bool,
      scoreBarmila: (j['scoreBarmila'] ?? true) as bool,
      scoreSabaa: (j['scoreSabaa'] ?? true) as bool,
      scoreChkobba: (j['scoreChkobba'] ?? true) as bool,
      barmilaTiebreakOnSixes: (j['barmilaTiebreakOnSixes'] ?? true) as bool,
    );
  }
}

// ---------------------------------------------------------------------------
// Captures
// ---------------------------------------------------------------------------

/// One legal way for a played card to take cards off the table.
class CaptureOption {
  const CaptureOption(this.cards, {this.isSingle = false});

  /// The table cards taken, including the played card itself as the first
  /// element, so callers never have to remember to add it.
  final List<Card> cards;
  final bool isSingle;

  int get size => cards.length;
}

class ChkobbaMove {
  const ChkobbaMove({
    required this.seat,
    required this.card,
    required this.captured,
    required this.chkobba,
    required this.cardLeftOnTable,
    required this.turnIndex,
  });

  final int seat;
  final Card card;

  /// Cards moved to [ChkobbaState.captured] (played card first). Empty when the
  /// card could not capture and was left on the table.
  final List<Card> captured;

  /// True when this move emptied the table - a Chkobba, worth a point.
  final bool chkobba;

  /// True when the card simply joined the table.
  final bool cardLeftOnTable;

  /// Global move counter, used to detect the final card of the round.
  final int turnIndex;
}

// ---------------------------------------------------------------------------
// Scoring
// ---------------------------------------------------------------------------

class RoundScore {
  const RoundScore({
    required this.team,
    required this.points,
    required this.reasons,
  });

  final int team;
  final int points;

  /// Human-readable reasons, e.g. `['Karta', 'Chkobba x2']`. Kept in the engine
  /// so the UI never re-implements scoring.
  final List<String> reasons;

  @override
  String toString() => 'team $team +$points ($reasons)';
}

// ---------------------------------------------------------------------------
// State
// ---------------------------------------------------------------------------

class ChkobbaState {
  ChkobbaState._({
    required this.rules,
    required this.seed,
    required this.dealer,
    required this.stock,
    required this.hands,
    required this.table,
    required this.captured,
    required this.chkobbas,
    required this.teamPoints,
    required this.roundPoints,
    required this.current,
    required this.lastCapturer,
    required this.turnIndex,
    required this.playedThisDeal,
    required this.dealIndex,
    required this.roundFinished,
    required this.redealNeeded,
  });

  /// Starts match [seed] at [startSeat] and deals the opening hand.
  factory ChkobbaState.newMatch({
    ChkobbaRules rules = ChkobbaRules.tunisianDefault,
    required int seed,
    int startSeat = 0,
  }) {
    final deck = Deck.shuffled(rules.deckSpec, seed);
    final hands = List.generate(rules.seats, (_) => <Card>[]);
    final empty = List.generate(rules.seats, (_) => <Card>[]);
    var s = ChkobbaState._(
      rules: rules,
      seed: seed,
      dealer: startSeat,
      stock: deck.cards,
      hands: hands,
      table: <Card>[],
      captured: empty,
      chkobbas: List.filled(rules.seats, 0),
      teamPoints: List.filled(rules.teamCount, 0),
      roundPoints: List.filled(rules.teamCount, 0),
      current: startSeat,
      lastCapturer: -1,
      turnIndex: 0,
      playedThisDeal: 0,
      dealIndex: 0,
      roundFinished: false,
      redealNeeded: false,
    );
    s._dealOpening();
    s.current = startSeat;
    return s;
  }

  /// Builds a state directly from explicit cards, skipping the deal.
  ///
  /// Used by the rule tests and by the cross-language fixtures the PHP server
  /// is verified against, so both sides are fed the exact same position.
  factory ChkobbaState.fromCards({
    ChkobbaRules rules = ChkobbaRules.tunisianDefault,
    required List<Card> table,
    required Map<int, List<Card>> hands,
    List<Card> stock = const [],
    Map<int, List<Card>> captured = const {},
    List<int> chkobbas = const [],
    List<int> teamPoints = const [],
    int current = 0,
    int dealer = 0,
    int lastCapturer = -1,
    int turnIndex = 0,
    int playedThisDeal = 0,
    int dealIndex = 0,
    int seed = 0,
  }) {
    final handsList = List.generate(rules.seats, (s) => <Card>[...?hands[s]]);
    return ChkobbaState._(
      rules: rules,
      seed: seed,
      dealer: dealer,
      stock: List<Card>.from(stock),
      hands: handsList,
      table: List<Card>.from(table),
      captured: List.generate(
          rules.seats, (s) => <Card>[...?captured[s]]),
      chkobbas: chkobbas.isEmpty
          ? List.filled(rules.seats, 0)
          : List<int>.from(chkobbas),
      teamPoints: teamPoints.isEmpty
          ? List.filled(rules.teamCount, 0)
          : List<int>.from(teamPoints),
      roundPoints: List.filled(rules.teamCount, 0),
      current: current,
      lastCapturer: lastCapturer,
      turnIndex: turnIndex,
      playedThisDeal: playedThisDeal,
      dealIndex: dealIndex,
      roundFinished: false,
      redealNeeded: false,
    );
  }

  final ChkobbaRules rules;

  /// The match seed. Every shuffle in the match derives from it, so a match is
  /// exactly reproducible from `seed` + the move list - which is what lets the
  /// online event log be authoritative.
  final int seed;

  int dealer;
  List<Card> stock;
  List<List<Card>> hands;
  List<Card> table;
  List<List<Card>> captured;
  List<int> chkobbas;
  List<int> teamPoints;
  List<int> roundPoints;
  int current;
  int lastCapturer;
  int turnIndex;

  /// Cards played since the last deal (a deal is [ChkobbaRules.dealSize] per
  /// seat).
  int playedThisDeal;
  int dealIndex;

  bool roundFinished;

  /// Set when the opening table cards are illegal and the hand must be re-dealt.
  bool redealNeeded;

  int get seats => rules.seats;
  int get teamCount => rules.teamCount;

  List<Card> handOf(int seat) => hands[seat];
  List<Card> capturedOf(int seat) => captured[seat];
  int chkobbasOf(int seat) => chkobbas[seat];
  int pointsOf(int seat) => teamPoints[rules.teamOf(seat)];

  /// Cards still in the stock, i.e. not yet dealt.
  int get stockCount => stock.length;

  /// Total cards unaccounted for by hands+table+captured. Must always be the
  /// stock size; asserted by the fuzz test.
  int get cardsInPlay =>
      hands.fold<int>(0, (a, h) => a + h.length) +
      table.length +
      captured.fold<int>(0, (a, c) => a + c.length);

  bool get isFinalCardOfRound =>
      stock.isEmpty && hands.every((h) => h.isEmpty);

  // -- setup ---------------------------------------------------------------

  void _dealOpening() {
    for (var i = 0; i < rules.dealSize; i++) {
      for (var seat = 0; seat < seats; seat++) {
        final c = stock.removeLast();
        if (c != null) hands[seat].add(c);
      }
    }
    for (var i = 0; i < rules.tableCards; i++) {
      final c = stock.removeLast();
      if (c != null) table.add(c);
    }
    if (rules.redealOnThreeSameRank && _tableHasTriple()) {
      redealNeeded = true;
    }
  }

  bool _tableHasTriple() {
    final counts = <int, int>{};
    for (final c in table) {
      counts[rules.valueOf(c)] = (counts[rules.valueOf(c)] ?? 0) + 1;
    }
    return counts.values.any((n) => n >= 3);
  }

  // -- capture resolution --------------------------------------------------

  /// Every legal capture for [card], best-first. Empty means "no capture, the
  /// card joins the table".
  ///
  /// Singles always come before sums when [CapturePriority.singleFirst], which
  /// is what makes a 5 beat a 2+3 on the table.
  List<CaptureOption> capturesFor(Card card) {
    final v = rules.valueOf(card);
    final singles = table.where((c) => rules.valueOf(c) == v).toList();

    if (rules.capturePriority == CapturePriority.singleFirst && singles.isNotEmpty) {
      return [CaptureOption([card, ...singles], isSingle: true)];
    }

    final options = <CaptureOption>[];
    if (singles.isNotEmpty) {
      options.add(CaptureOption([card, ...singles], isSingle: true));
    }
    options.addAll(_sumCaptures(card, v));
    options.sort((a, b) => b.size.compareTo(a.size));
    return options;
  }

  /// Subset-sum search over the table. Pruned by the running total, so it stays
  /// instant even when the table grows.
  List<CaptureOption> _sumCaptures(Card card, int target) {
    final results = <CaptureOption>[];
    final picked = <Card>[];

    void walk(int start, int sum) {
      if (sum == target) {
        // Single cards are reported separately; only report 2+ card sums here.
        if (picked.length >= 2) {
          final set = picked.toSet();
          final tableCards = table.where(set.contains).toList();
          if (tableCards.length == picked.length) {
            results.add(CaptureOption([card, ...tableCards]));
          }
        }
        return;
      }
      if (sum > target) return;
      for (var i = start; i < table.length; i++) {
        picked.add(table[i]);
        walk(i + 1, sum + rules.valueOf(table[i]));
        picked.removeLast();
      }
    }

    walk(0, 0);
    return results;
  }

  /// The single capture the player has no choice about, or null when the player
  /// must pick (several equal sums) or may decline.
  CaptureOption? forcedCapture(Card card) {
    final options = capturesFor(card);
    if (options.isEmpty) return null;
    if (rules.capturePriority == CapturePriority.singleFirst &&
        options.first.isSingle) {
      return options.first;
    }
    if (options.length == 1) return options.first;
    return null;
  }

  // -- playing -------------------------------------------------------------

  /// Plays [cardId] from [seat]'s hand. When several captures are legal the
  /// caller must pass [optionIndex] from [capturesFor]; with none available the
  /// card is left on the table.
  ChkobbaMove play(int seat, int cardId, {int? optionIndex}) {
    if (roundFinished) {
      throw StateError('round already finished');
    }
    if (seat != current) {
      throw StateError('not seat $seat\'s turn (current=$current)');
    }
    final idx = hands[seat].indexWhere((c) => c.id == cardId);
    if (idx < 0) {
      throw StateError('card $cardId is not in seat $seat\'s hand');
    }
    final card = hands[seat].removeAt(idx);

    final options = capturesFor(card);
    List<Card>? taken;
    if (options.isNotEmpty) {
      final chosen = optionIndex == null
          ? options.first
          : options[optionIndex.clamp(0, options.length - 1)];
      taken = chosen.cards;
    }

    if (taken == null) {
      table.add(card);
      final move = ChkobbaMove(
        seat: seat,
        card: card,
        captured: const [],
        chkobba: false,
        cardLeftOnTable: true,
        turnIndex: turnIndex,
      );
      _afterMove(move);
      return move;
    }

    // Remove the captured table cards, then take everything including the
    // played card.
    final takenSet = taken.toSet();
    table.removeWhere(takenSet.contains);
    captured[seat].addAll(taken);

    var isChkobba = table.isEmpty;
    if (isChkobba && !rules.chkobbaOnFinalCard && seat == dealer &&
        isFinalCardOfRound) {
      isChkobba = false;
    }
    if (isChkobba) {
      // The played card stays visible on the table as the marker of the sweep.
      table.add(card);
      chkobbas[seat]++;
    }

    lastCapturer = seat;
    final move = ChkobbaMove(
      seat: seat,
      card: card,
      captured: taken,
      chkobba: isChkobba,
      cardLeftOnTable: false,
      turnIndex: turnIndex,
    );
    _afterMove(move);
    return move;
  }

  void _afterMove(ChkobbaMove move) {
    turnIndex++;
    playedThisDeal++;

    if (playedThisDeal >= rules.dealSize * seats) {
      playedThisDeal = 0;
      dealIndex++;
      final exhausted = hands.every((h) => h.isEmpty);
      if (exhausted) {
        _finishRound();
      } else {
        for (var i = 0; i < rules.dealSize; i++) {
          for (var seat = 0; seat < seats; seat++) {
            final c = stock.isEmpty ? null : stock.removeLast();
            if (c != null) hands[seat].add(c);
          }
        }
      }
    } else {
      current = (current + 1) % seats;
    }
  }

  void _finishRound() {
    // The final sweep: whatever is left on the table goes to the last player
    // who captured. It is not a Chkobba.
    if (table.isNotEmpty && lastCapturer >= 0) {
      captured[lastCapturer].addAll(table);
      table = <Card>[];
    }
    roundFinished = true;
    current = -1;
  }

  // -- scoring -------------------------------------------------------------

  /// Points earned in the round that just finished, per team.
  List<RoundScore> scoreRound() {
    final r = rules;
    final per = List.generate(r.teamCount, (_) => <String>[]);

    if (r.scoreKarta) {
      final counts = List<int>.filled(r.teamCount, 0);
      for (var seat = 0; seat < seats; seat++) {
        counts[r.teamOf(seat)] += captured[seat].length;
      }
      final best = counts.reduce((a, b) => a > b ? a : b);
      if (counts.where((n) => n == best).length == 1) {
        per[counts.indexOf(best)].add('Karta');
      }
    }

    if (r.scoreDinari) {
      final counts = List<int>.filled(r.teamCount, 0);
      for (var seat = 0; seat < seats; seat++) {
        counts[r.teamOf(seat)] +=
            captured[seat].where((c) => c.suit == Suit.diamonds).length;
      }
      final best = counts.reduce((a, b) => a > b ? a : b);
      if (counts.where((n) => n == best).length == 1 && best > 0) {
        per[counts.indexOf(best)].add('Dinari');
      }
    }

    if (r.scoreBarmila) {
      final sevens = List<int>.filled(r.teamCount, 0);
      final sixes = List<int>.filled(r.teamCount, 0);
      for (var seat = 0; seat < seats; seat++) {
        for (final c in captured[seat]) {
          if (c.rank == Rank.seven) {
            sevens[r.teamOf(seat)]++;
          } else if (c.rank == Rank.six) {
            sixes[r.teamOf(seat)]++;
          }
        }
      }
      var bestTeam = -1;
      final top = sevens.reduce((a, b) => a > b ? a : b);
      if (top > 0) {
        final tied = <int>[];
        for (var t = 0; t < r.teamCount; t++) {
          if (sevens[t] == top) tied.add(t);
        }
        if (tied.length == 1) {
          bestTeam = tied.first;
        } else if (r.barmilaTiebreakOnSixes) {
          final topSix = sixes.reduce((a, b) => a > b ? a : b);
          final sixTied = tied.where((t) => sixes[t] == topSix).toList();
          if (sixTied.length == 1) bestTeam = sixTied.first;
        }
      }
      if (bestTeam >= 0) per[bestTeam].add('Barmila');
    }

    if (r.scoreSabaa) {
      for (var seat = 0; seat < seats; seat++) {
        final hasIt = captured[seat]
            .any((c) => c.rank == Rank.seven && c.suit == Suit.diamonds);
        if (hasIt) {
          final t = r.teamOf(seat);
          if (!per[t].contains('Sabaa el-Haya')) per[t].add('Sabaa el-Haya');
          break;
        }
      }
    }

    if (r.scoreChkobba) {
      for (var seat = 0; seat < seats; seat++) {
        if (chkobbas[seat] > 0) {
          final t = r.teamOf(seat);
          per[t].add('Chkobba x${chkobbas[seat]}');
        }
      }
    }

    final out = <RoundScore>[];
    for (var t = 0; t < r.teamCount; t++) {
      final pts = per[t].length;
      roundPoints[t] = pts;
      if (pts > 0) out.add(RoundScore(team: t, points: pts, reasons: per[t]));
    }
    return out;
  }

  /// Applies [scoreRound] to the running match totals.
  void commitRound() {
    for (var t = 0; t < teamCount; t++) {
      teamPoints[t] += roundPoints[t];
    }
  }

  /// The winning team, or -1 when the match must continue. With
  /// [ChkobbaRules.winByTwo] a team needs the target *and* a 2-point lead;
  /// otherwise the round is played again.
  int matchWinner() {
    final r = rules;
    for (var t = 0; t < teamCount; t++) {
      if (teamPoints[t] >= r.targetScore) {
        final others = <int>[];
        for (var o = 0; o < teamCount; o++) {
          if (o != t) others.add(teamPoints[o]);
        }
        final bestOther = others.isEmpty ? 0 : others.reduce((a, b) => a > b ? a : b);
        if (!r.winByTwo || teamPoints[t] - bestOther >= 2) return t;
      }
    }
    return -1;
  }

  /// Deals the next round, keeping the running match totals. Returns the new
  /// state; the old one is left untouched so tests can compare.
  ChkobbaState nextRound({int? nextSeed}) {
    final s = ChkobbaState.newMatch(
      rules: rules,
      seed: nextSeed ?? _deriveSeed(),
      startSeat: (dealer + 1) % seats,
    );
    s.teamPoints = List<int>.from(teamPoints);
    s.dealer = (dealer + 1) % seats;
    s.current = s.dealer;
    return s;
  }

  int _deriveSeed() {
    final r = Random(seed ^ (turnIndex * 2654435761) ^ (dealIndex * 40503));
    return r.nextInt(0x7fffffff);
  }

  // -- snapshot ------------------------------------------------------------

  Map<String, dynamic> toJson() => {
        'v': 1,
        'game': 'chkobba',
        'seed': seed,
        'dealer': dealer,
        'current': current,
        'lastCapturer': lastCapturer,
        'turnIndex': turnIndex,
        'playedThisDeal': playedThisDeal,
        'dealIndex': dealIndex,
        'roundFinished': roundFinished,
        'redealNeeded': redealNeeded,
        'stock': stock.map((c) => c.id).toList(),
        'table': table.map((c) => c.id).toList(),
        'hands': hands.map((h) => h.map((c) => c.id).toList()).toList(),
        'captured': captured.map((c) => c.map((x) => x.id).toList()).toList(),
        'chkobbas': chkobbas,
        'teamPoints': teamPoints,
        'roundPoints': roundPoints,
        'rules': rules.toJson(),
      };

  /// Rebuilds a state from a snapshot plus the rules' card catalogue. Card ids
  /// are stable per match seed, so the catalogue is regenerated by replaying
  /// the seed.
  static ChkobbaState fromJson(Map<String, dynamic> j) {
    final rules = ChkobbaRules.fromJson((j['rules'] ?? {}) as Map<String, dynamic>);
    final catalogue = _catalogue(rules);
    Card c(int id) => catalogue[id];

    List<Card> ids(dynamic list) =>
        (list as List<dynamic>).map((e) => c(e as int)).toList();

    return ChkobbaState._(
      rules: rules,
      seed: j['seed'] as int,
      dealer: j['dealer'] as int,
      stock: ids(j['stock']),
      hands: (j['hands'] as List<dynamic>)
          .map((h) => ids(h))
          .toList(),
      table: ids(j['table']),
      captured: (j['captured'] as List<dynamic>)
          .map((h) => ids(h))
          .toList(),
      chkobbas: List<int>.from(j['chkobbas'] as List<dynamic>),
      teamPoints: List<int>.from(j['teamPoints'] as List<dynamic>),
      roundPoints: List<int>.from(j['roundPoints'] as List<dynamic>),
      current: j['current'] as int,
      lastCapturer: j['lastCapturer'] as int,
      turnIndex: j['turnIndex'] as int,
      playedThisDeal: j['playedThisDeal'] as int,
      dealIndex: j['dealIndex'] as int,
      roundFinished: j['roundFinished'] as bool,
      redealNeeded: j['redealNeeded'] as bool,
    );
  }

  /// id -> Card for one match. Ids are assigned in deck-build order (suit
  /// outer, rank inner) and never shuffled, so this is deterministic.
  static Map<int, Card> _catalogue(ChkobbaRules rules) {
    final map = <int, Card>{};
    var id = 0;
    for (final suit in Suit.values) {
      for (final rank in rules.deckSpec.ranks) {
        map[id++] = Card(id: id - 1, rank: rank, suit: suit);
      }
    }
    return map;
  }

  /// Human-readable snapshot for the test suite and for bug reports.
  String debug() {
    final b = StringBuffer()
      ..writeln('seed=$seed dealer=$dealer current=$current '
          'turn=$turnIndex stock=$stockCount finished=$roundFinished');
    for (var s = 0; s < seats; s++) {
      b.writeln(' seat$s hand=${hands[s].map((c) => _short(c)).toList()} '
          'captured=${captured[s].length} chkobbas=${chkobbas[s]}');
    }
    b.writeln(' table=${table.map(_short).toList()}');
    b.writeln(' inPlay=$cardsInPlay stock=$stockCount '
        'total=${cardsInPlay + stockCount}');
    return b.toString();
  }
}

String _short(Card c) =>
    c.joker ? 'J' : '${c.rank.name[0].toUpperCase()}${_suitLetter(c.suit)}';

String _suitLetter(Suit s) => switch (s) {
      Suit.hearts => 'h',
      Suit.diamonds => 'd',
      Suit.clubs => 'c',
      Suit.spades => 's',
    };
