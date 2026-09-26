/// The Chkobba bot: reads the table, enumerates every legal capture, scores
/// them, and picks one.
///
/// Pure Dart and seeded, so a bot match is exactly reproducible from its seed -
/// which is what lets the online mode hand a seat to a bot and still replay the
/// whole match from the event log.
library;

import 'dart:math';

import '../cards.dart';
import '../chkobba.dart';

/// How hard the bot tries. [easy] is a real opponent for a beginner, [normal] is
/// a solid greedy player, [hard] looks one move ahead.
enum BotLevel {
  easy,
  normal,
  hard;

  static BotLevel byName(String name) => BotLevel.values.firstWhere(
        (level) => level.name == name,
        orElse: () => BotLevel.normal,
      );
}

/// A chosen action: which card to play, and which of its capture options to
/// take. A null [optionIndex] means "whatever the engine considers best", which
/// is correct whenever the table offers only one legal capture.
class BotMove {
  const BotMove(this.cardId, [this.optionIndex]);

  final int cardId;
  final int? optionIndex;

  @override
  String toString() => 'BotMove(card $cardId, option ${optionIndex ?? 'auto'})';
}

/// Scores and plays Chkobba.
///
/// The scoring is deliberately simple and readable rather than tuned: Chkobba is
/// a game of small positional choices, so "how many cards do I take, and what do
/// they leave behind" beats any deep search. [hard] adds one ply of "what can
/// the opponent take right now", which is the single most useful thing to know
/// in this game.
class ChkobbaBot {
  ChkobbaBot({
    this.level = BotLevel.normal,
    int seed = 0,
  }) : _rng = Random(seed);

  final BotLevel level;
  final Random _rng;

  /// Fraction of turns [BotLevel.easy] plays a random legal card instead of the
  /// best one. Not a move it would never make: any card in hand is legal, it
  /// either captures or joins the table.
  static const double easyRandomness = 0.4;

  /// Picks the move for whoever is on turn. Throws if the round is over or the
  /// turn is not [state]'s to play, exactly like the engine.
  BotMove chooseMove(ChkobbaState state) {
    if (state.roundFinished) {
      throw StateError('round already finished');
    }
    final seat = state.current;
    final hand = state.handOf(seat);
    if (hand.isEmpty) {
      throw StateError('seat $seat has no card to play');
    }

    if (level == BotLevel.easy && _rng.nextDouble() < easyRandomness) {
      return BotMove(hand[_rng.nextInt(hand.length)].id);
    }

    final ranked = _rankMoves(state, seat);
    if (ranked.isEmpty) {
      // Unreachable for a real hand, but a bot that throws mid-game is worse
      // than one that plays something legal.
      return BotMove(hand.first.id);
    }
    final best = ranked.first;
    return BotMove(best.card.id, best.optionIndex);
  }

  /// Every legal move for [seat], best first. Exposed for tests and for the
  /// hard level's own lookahead.
  List<ScoredMove> rankMoves(ChkobbaState state, int seat) =>
      _rankMoves(state, seat);

  List<ScoredMove> _rankMoves(ChkobbaState state, int seat) {
    final out = <ScoredMove>[];
    for (final card in state.handOf(seat)) {
      final options = state.capturesFor(card);
      if (options.isEmpty) {
        // No capture: the card joins the table. Always legal, so it is always a
        // candidate, and it keeps the bot from ever being stuck.
        out.add(ScoredMove(card, null, _scoreNoCapture(state, card)));
        continue;
      }
      for (var i = 0; i < options.length; i++) {
        out.add(ScoredMove(
          card,
          i,
          _scoreCapture(state, card, options[i]) - _dumpCost(state, card),
        ));
      }
    }
    out.sort((a, b) => b.score.compareTo(a.score));
    if (level == BotLevel.hard && out.isNotEmpty) {
      out[0] = out[0].withPenalty(_opponentBestGain(state, out[0].card, seat));
    }
    return out;
  }

  // -- scoring --------------------------------------------------------------

  /// Low cards are worth less to hold, so playing one is mildly attractive.
  double _dumpCost(ChkobbaState state, Card card) =>
      state.rules.valueOf(card) * 0.35;

  /// Playing a card that cannot capture: the table grows by one, which is mild
  /// upside for everybody but the very next player.
  double _scoreNoCapture(ChkobbaState state, Card card) =>
      1.0 - _dumpCost(state, card) + (state.rules.tableCards * 0.1);

  /// The heart of the bot: how good is taking [option] with [card].
  double _scoreCapture(ChkobbaState state, Card card, CaptureOption option) {
    final taken = option.cards.where((c) => c.id != card.id).toList();
    var score = 0.0;

    // Every table card taken is a real card, and Karta is about card count.
    score += 2.2 * taken.length;

    // Scoring categories the round actually pays for.
    score += 3.0 * taken.where((c) => c.suit == Suit.diamonds).length;
    score += 2.0 * taken.where((c) => c.rank == Rank.seven).length;
    if (taken.any((c) => c.rank == Rank.seven && c.suit == Suit.diamonds)) {
      // Sabaa el-Haya is a guaranteed point, so it is worth more than the sum
      // of its two parts.
      score += 4.0;
    }

    // Face cards are the hardest to replace in a 40-card pack.
    score += 1.2 *
        taken
            .where((c) =>
                c.rank == Rank.jack ||
                c.rank == Rank.queen ||
                c.rank == Rank.king)
            .length;

    // What the table looks like afterwards is the real decision.
    final left = state.table.length - taken.length;
    if (left == 0) {
      // A Chkobba, if the rules allow it on this card. Worth a point and a
      // clean table, so the bot loves it.
      score += state.rules.chkobbaOnFinalCard || !state.isFinalCardOfRound
          ? 14.0
          : 6.0;
    } else if (left == 1) {
      // One card from a sweep for whoever moves next.
      score += 7.0;
    } else if (left == 2) {
      score += 2.5;
    }

    return score;
  }

  /// Hard level: the most the opponent could take on their very next turn, used
  /// as a penalty on our best move. Cheap - it only looks at the move we
  /// already picked, not at every line.
  double _opponentBestGain(ChkobbaState state, Card ourCard, int seat) {
    final opponent = (seat + 1) % state.seats;
    final hand = state.handOf(opponent);
    if (hand.isEmpty || state.table.isEmpty) return 0;
    var best = 0;
    for (final card in hand) {
      for (final option in state.capturesFor(card)) {
        if (option.size > best) best = option.size;
      }
    }
    // One extra card they can take is worth roughly one of ours.
    return best * 1.1;
  }
}

/// One candidate move with the score that ranked it.
class ScoredMove {
  const ScoredMove(this.card, this.optionIndex, this.score);

  final Card card;

  /// Index into `ChkobbaState.capturesFor(card)`, or null when the card cannot
  /// capture and simply joins the table.
  final int? optionIndex;

  final double score;

  ScoredMove withPenalty(double penalty) =>
      ScoredMove(card, optionIndex, score - penalty);

  @override
  String toString() =>
      'ScoredMove(${card.notation}, option $optionIndex, ${score.toStringAsFixed(2)})';
}
