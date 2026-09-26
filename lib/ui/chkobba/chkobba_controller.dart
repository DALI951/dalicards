import 'dart:async';
import 'dart:math';

import 'package:engine/engine.dart';
import 'package:flutter/foundation.dart';

/// Who you are playing against.
enum ChkobbaMode {
  /// One human, one bot. The bot's hand stays face down.
  solo,

  /// Two humans on one device: you pass the phone. The opponent's hand stays
  /// face down, because a hotseat game that shows both hands is just a
  /// two-handed single player game.
  hotseat;

  static ChkobbaMode byName(String name) => ChkobbaMode.values.firstWhere(
        (m) => m.name == name,
        orElse: () => ChkobbaMode.solo,
      );
}

/// Everything chosen before the first card is dealt. Immutable, so the setup
/// screen can rebuild while this stays untouched.
class ChkobbaSetup {
  const ChkobbaSetup({
    this.mode = ChkobbaMode.solo,
    this.level = BotLevel.normal,
    this.faceValues = FaceValues.tunisian,
    this.targetScore = 21,
    this.dealSize = 3,
    this.capturePriority = CapturePriority.singleFirst,
  });

  final ChkobbaMode mode;
  final BotLevel level;
  final FaceValues faceValues;
  final int targetScore;
  final int dealSize;
  final CapturePriority capturePriority;

  ChkobbaRules get rules => ChkobbaRules(
        faceValues: faceValues,
        seats: 2,
        dealSize: dealSize,
        targetScore: targetScore,
        capturePriority: capturePriority,
      );

  ChkobbaSetup copyWith({
    ChkobbaMode? mode,
    BotLevel? level,
    FaceValues? faceValues,
    int? targetScore,
    int? dealSize,
    CapturePriority? capturePriority,
  }) {
    return ChkobbaSetup(
      mode: mode ?? this.mode,
      level: level ?? this.level,
      faceValues: faceValues ?? this.faceValues,
      targetScore: targetScore ?? this.targetScore,
      dealSize: dealSize ?? this.dealSize,
      capturePriority: capturePriority ?? this.capturePriority,
    );
  }

  /// Stable id, so the web URL can carry the whole setup as `#/game/chkobba?mode=…`
  /// and a link replays the same table.
  String get query => 'mode=${mode.name}'
      '&level=${level.name}'
      '&fv=${faceValues.jack}-${faceValues.queen}'
      '&target=$targetScore'
      '&deal=$dealSize'
      '&cap=${capturePriority.index}';

  static ChkobbaSetup fromQuery(String? query) {
    if (query == null || query.isEmpty) return const ChkobbaSetup();
    final map = <String, String>{};
    for (final pair in query.split('&')) {
      final i = pair.indexOf('=');
      if (i > 0) map[pair.substring(0, i)] = pair.substring(i + 1);
    }
    final fv = (map['fv'] ?? '').split('-');
    final jack = int.tryParse(fv.isNotEmpty ? fv[0] : '');
    final queen = int.tryParse(fv.length > 1 ? fv[1] : '');
    return ChkobbaSetup(
      mode: ChkobbaMode.byName(map['mode'] ?? ''),
      level: BotLevel.byName(map['level'] ?? ''),
      faceValues: (jack != null && queen != null)
          ? FaceValues(jack: jack, queen: queen, king: 10)
          : FaceValues.tunisian,
      targetScore: int.tryParse(map['target'] ?? '') ?? 21,
      dealSize: int.tryParse(map['deal'] ?? '') ?? 3,
      capturePriority: CapturePriority
          .values[(int.tryParse(map['cap'] ?? '') ?? 0).clamp(0, 1)],
    );
  }
}

/// Drives one Chkobba match: owns the engine state, plays the bot's turns, and
/// raises the Chkobba moment.
///
/// The engine stays the single source of truth for the rules - this class never
/// re-implements a rule, it only decides *who* moves and *when*, and mirrors the
/// move into the UI. That is the same split the online server will use.
class ChkobbaController extends ChangeNotifier {
  ChkobbaController({
    required this.setup,
    int? seed,
    this.botDelay = const Duration(milliseconds: 620),
    this.flashDuration = const Duration(milliseconds: 1500),
  })  : _seed = seed ?? DateTime.now().millisecondsSinceEpoch,
        _bot = ChkobbaBot(level: setup.level, seed: seed ?? 0) {
    _state = ChkobbaState.newMatch(rules: setup.rules, seed: _seed);
    _redealIfNeeded();
  }

  final ChkobbaSetup setup;
  final Duration botDelay;
  final Duration flashDuration;

  final int _seed;
  late final ChkobbaBot _bot;
  late ChkobbaState _state;

  Timer? _botTimer;
  Timer? _flashTimer;
  bool _disposed = false;
  bool _roundCommitted = false;
  int _redealGuard = 0;
  int? _selectedCardId;
  List<CaptureOption> _selectedOptions = const [];
  List<RoundScore> _roundScores = const [];
  bool _flashing = false;

  ChkobbaState get state => _state;
  int get seed => _seed;

  /// The hand on screen. In solo it is always seat 0; in hotseat it is whoever
  /// is on turn, which is the whole point of passing the phone.
  int get viewerSeat {
    if (setup.mode == ChkobbaMode.solo) return 0;
    return _state.current < 0 ? 0 : _state.current;
  }

  int get opponentSeat => 1 - viewerSeat;

  bool get roundFinished => _state.roundFinished;

  int get matchWinner => _state.matchWinner();

  bool get matchOver => _state.roundFinished && matchWinner >= 0;

  bool get isMyTurn => !_state.roundFinished && _state.current == viewerSeat;

  bool get botThinking =>
      setup.mode == ChkobbaMode.solo && !_state.roundFinished && !isMyTurn;

  /// Points won in the round that just ended, with the reasons spelled out.
  List<RoundScore> get roundScores => _roundScores;

  List<int> get teamPoints => _state.teamPoints;

  int get stockCount => _state.stockCount;

  bool get chkobbaFlashing => _flashing;

  int? get selectedCardId => _selectedCardId;

  List<CaptureOption> get selectedOptions => _selectedOptions;

  /// The card the player has lifted, if any.
  Card? get selectedCard {
    final id = _selectedCardId;
    if (id == null) return null;
    for (final c in _state.handOf(viewerSeat)) {
      if (c.id == id) return c;
    }
    return null;
  }

  /// Total cards each seat has collected - the Karta race, on screen.
  int cardsHeldBy(int seat) => _state.capturedOf(seat).length;

  int chkobbasBy(int seat) => _state.chkobbasOf(seat);

  List<Card> handOf(int seat) => _state.handOf(seat);

  List<Card> tableCards() => _state.table;

  /// A single card of the 40 must never sit on the table twice, but the Chkobba
  /// marker is the played card shown face up after a sweep, so the table can
  /// look like it holds a card the engine has already banked.
  Card? get chkobbaMarker => _state.chkobbaMarker;

  // -- playing --------------------------------------------------------------

  /// Lifts a card out of the hand. Lifting it again puts it back down, which is
  /// how a player changes their mind before the table is committed.
  void toggleCard(int cardId) {
    if (!isMyTurn) return;
    if (_selectedCardId == cardId) {
      clearSelection();
      return;
    }
    for (final c in _state.handOf(viewerSeat)) {
      if (c.id == cardId) {
        _selectedCardId = cardId;
        _selectedOptions = _state.capturesFor(c);
        notifyListeners();
        return;
      }
    }
  }

  void clearSelection() {
    if (_selectedCardId == null) return;
    _selectedCardId = null;
    _selectedOptions = const [];
    notifyListeners();
  }

  /// True when the lifted card offers more than one legal capture, so the player
  /// genuinely has to choose and the UI has to ask.
  bool get needsCaptureChoice => _selectedOptions.length > 1;

  /// Plays the lifted card. [optionIndex] only matters when the card has several
  /// captures; null lets the engine take the single best one.
  void playSelected({int? optionIndex}) {
    final id = _selectedCardId;
    if (id == null || !isMyTurn) return;
    if (optionIndex != null &&
        (optionIndex < 0 || optionIndex >= _selectedOptions.length)) {
      return;
    }
    _selectedCardId = null;
    _selectedOptions = const [];
    _commit(viewerSeat, id, optionIndex: optionIndex);
  }

  /// Plays [cardId] straight away, used by the UI when there is only one legal
  /// thing to do and asking would be a wasted tap.
  void playCard(int cardId, {int? optionIndex}) {
    if (!isMyTurn) return;
    _commit(viewerSeat, cardId, optionIndex: optionIndex);
  }

  /// The one and only place a card is committed to the engine.
  ///
  /// The player and the bot both come through here on purpose. The Chkobba
  /// shout, the round close and the next bot turn used to be handled in two
  /// near-identical places, and a sweep by the human was the one move that
  /// skipped the shout - so the loudest moment of the game went silent exactly
  /// when the player earned it. One path, no such gap.
  ChkobbaMove? _commit(int seat, int cardId, {int? optionIndex}) {
    final move = _state.play(seat, cardId, optionIndex: optionIndex);
    if (move.chkobba) _raiseChkobba();
    if (_state.roundFinished) _closeRound();
    notifyListeners();
    // Harmless when the bot has no turn: it re-arms only if the turn is really
    // its own, so hotseat never starts a timer.
    _scheduleBot();
    return move;
  }

  // -- bot ------------------------------------------------------------------

  void _scheduleBot() {
    _botTimer?.cancel();
    _botTimer = null;
    if (_disposed) return;
    if (!botThinking) return;
    _botTimer = Timer(botDelay, _botMoves);
  }

  void _botMoves() {
    _botTimer = null;
    if (_disposed || _state.roundFinished) return;
    final move = _bot.chooseMove(_state);
    _commit(_state.current, move.cardId, optionIndex: move.optionIndex);
  }

  /// Re-runs the bot's schedule, e.g. after a language change rebuilds the tree.
  void resume() {
    if (_disposed) return;
    _scheduleBot();
  }

  // -- round and match flow ------------------------------------------------

  void _closeRound() {
    if (_roundCommitted) return;
    _roundCommitted = true;
    _roundScores = _state.scoreRound();
    _state.commitRound();
  }

  /// Deals the next round of the same match, keeping the running totals.
  void nextRound() {
    if (!_state.roundFinished) return;
    _state = _state.nextRound();
    _roundCommitted = false;
    _roundScores = const [];
    _selectedCardId = null;
    _selectedOptions = const [];
    _redealIfNeeded();
    notifyListeners();
    _scheduleBot();
  }

  /// Throws the match away and deals a new one.
  void restart() {
    _botTimer?.cancel();
    _botTimer = null;
    _state = ChkobbaState.newMatch(rules: setup.rules, seed: _nextSeed());
    _roundCommitted = false;
    _roundScores = const [];
    _selectedCardId = null;
    _selectedOptions = const [];
    _redealGuard = 0;
    _redealIfNeeded();
    notifyListeners();
    _scheduleBot();
  }

  int _nextSeed() {
    final r = Random(
        _seed ^ _state.turnIndex ^ (DateTime.now().microsecondsSinceEpoch));
    return r.nextInt(0x7fffffff);
  }

  /// Three or four of one rank on the opening table is an illegal deal, so the
  /// rules ask for a redeal. Done here, once, rather than making the player tap
  /// "redeal" on a hand they never saw.
  void _redealIfNeeded() {
    while (_state.redealNeeded && _redealGuard < 8) {
      _redealGuard++;
      final next = ChkobbaState.newMatch(
        rules: _state.rules,
        seed: _state.seed + 0x9E3779B9 + _redealGuard,
        startSeat: _state.dealer,
      );
      next.teamPoints = List<int>.from(_state.teamPoints);
      _state = next;
    }
  }

  // -- the Chkobba moment ---------------------------------------------------

  void _raiseChkobba() {
    _flashing = true;
    _flashTimer?.cancel();
    _flashTimer = Timer(flashDuration, () {
      _flashTimer = null;
      if (_disposed) return;
      _flashing = false;
      notifyListeners();
    });
  }

  @override
  void dispose() {
    _disposed = true;
    _botTimer?.cancel();
    _flashTimer?.cancel();
    _botTimer = null;
    _flashTimer = null;
    super.dispose();
  }
}
