import 'package:dalicards/games/registry.dart';
import 'package:dalicards/l10n/app_strings.dart';
import 'package:dalicards/theme.dart';
import 'package:dalicards/ui/cards/playing_card.dart';
import 'package:dalicards/ui/chkobba/chkobba_controller.dart';
import 'package:engine/engine.dart';
// Flutter has its own `Card` widget; the engine has the card. Hide the widget so
// `Card` means the playing card everywhere in this file.
import 'package:flutter/material.dart' hide Card;
import 'package:flutter/services.dart';

/// The Chkobba table. Everything here is driven by [ChkobbaController], which
/// owns the engine state, so this file only decides how the position looks and
/// where a finger lands.
class ChkobbaTableScreen extends StatefulWidget {
  const ChkobbaTableScreen({
    super.key,
    required this.game,
    required this.setup,
    this.seed,
    this.botDelay = const Duration(milliseconds: 620),
    this.flashDuration = const Duration(milliseconds: 1500),
  });

  final GameEntry game;
  final ChkobbaSetup setup;

  /// Fixed seed for tests and for "replay this exact deal".
  final int? seed;

  /// How long the bot "thinks". Zero in tests, so a turn is one pump away.
  final Duration botDelay;

  /// How long the Chkobba shout stays up.
  final Duration flashDuration;

  @override
  State<ChkobbaTableScreen> createState() => _ChkobbaTableScreenState();
}

class _ChkobbaTableScreenState extends State<ChkobbaTableScreen> {
  late final ChkobbaController _controller = ChkobbaController(
    setup: widget.setup,
    seed: widget.seed,
    botDelay: widget.botDelay,
    flashDuration: widget.flashDuration,
  );

  /// The last thing that happened, shown as a line under the table. Chkobba is
  /// a game of small decisions and "who took what" is the information a player
  /// actually wants back.
  String? _lastAction;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _play(int cardId) {
    final card = _selectedCardOf(cardId);
    final options = _controller.state.capturesFor(card);
    final s = AppScope.stringsOf(context);
    if (options.length > 1) {
      _askCapture(card, options);
      return;
    }
    _controller.playCard(cardId);
    _lastAction = options.isEmpty
        ? '${_notation(card)} ${s.playedOnTable}'
        : '${_notation(card)} ${s.tookCards} ${options.first.cards.length - 1}';
    HapticFeedback.selectionClick();
  }

  Card _selectedCardOf(int cardId) => _controller.state
      .handOf(_controller.viewerSeat)
      .firstWhere((c) => c.id == cardId);

  static String _notation(Card c) => c.notation;

  void _askCapture(Card card, List<CaptureOption> options) {
    final s = AppScope.stringsOf(context);
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  s.chooseCapture,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 12),
                for (var i = 0; i < options.length; i++)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _CaptureChoice(
                      key: ValueKey<String>('capture-$i'),
                      option: options[i],
                      onTap: () {
                        Navigator.of(sheetContext).pop();
                        _controller.playCard(card.id, optionIndex: i);
                        _lastAction =
                            '${_notation(card)} ${s.tookCards} ${options[i].cards.length - 1}';
                        HapticFeedback.selectionClick();
                      },
                    ),
                  ),
                Align(
                  alignment: AlignmentDirectional.centerEnd,
                  child: TextButton(
                    onPressed: () => Navigator.of(sheetContext).pop(),
                    child: Text(s.cancel),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = AppScope.stringsOf(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.game.name.of(s.locale)),
        actions: [
          ListenableBuilder(
            listenable: _controller,
            builder: (context, _) => _ScoreBar(controller: _controller),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Stack(
        // Both children are Positioned, and Scaffold hands its body LOOSE
        // constraints. A Stack with nothing but positioned children sizes itself
        // to `constraints.smallest`, so without this the entire table collapsed
        // to 0x0 - the opponent strip, the table and the hand all laid out at
        // zero width and overflowed themselves.
        fit: StackFit.expand,
        children: [
          Positioned.fill(child: _buildBody(context, s)),
          ListenableBuilder(
            listenable: _controller,
            builder: (context, _) {
              if (!_controller.chkobbaFlashing) return const SizedBox.shrink();
              return Positioned.fill(
                child: _ChkobbaFlash(
                  text: s.isRtl ? s.chkobbaShoutAr : s.chkobbaShout,
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildBody(BuildContext context, AppStrings s) {
    return ListenableBuilder(
      listenable: _controller,
      builder: (context, _) {
        final wide = MediaQuery.sizeOf(context).width >= 720;
        return Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: wide ? 860 : 560),
            // SizedBox is what makes the width tight. Under `Center` the
            // constraints above are loose, so a bare Column would shrink to its
            // widest child and every `width: double.infinity` inside it would
            // collapse to nothing - the opponent strip and the hand row came
            // out 0px wide, and their children overflowed.
            child: SizedBox(
              width: double.infinity,
              child: Column(
                children: [
                  _OpponentStrip(
                    controller: _controller,
                    opponentName: _opponentName(s),
                  ),
                  Expanded(
                    child: _TableSurface(
                      controller: _controller,
                      lastAction: _lastAction,
                      wide: wide,
                    ),
                  ),
                  _HandBar(controller: _controller, onPlay: _play),
                  if (_controller.roundFinished)
                    _EndPanel(
                      controller: _controller,
                      onNextRound: () {
                        setState(() => _lastAction = null);
                        _controller.nextRound();
                      },
                      onRestart: () {
                        setState(() => _lastAction = null);
                        _controller.restart();
                      },
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  String _opponentName(AppStrings s) {
    if (_controller.setup.mode == ChkobbaMode.solo) return s.bot;
    return _controller.opponentSeat == 0 ? s.playerOne : s.playerTwo;
  }
}

/// Match points, always visible, because a Chkobba match is a race to 21 and
/// the race is the point.
class _ScoreBar extends StatelessWidget {
  const _ScoreBar({required this.controller});

  final ChkobbaController controller;

  @override
  Widget build(BuildContext context) {
    final s = AppScope.stringsOf(context);
    final points = controller.teamPoints;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < points.length; i++) ...[
          if (i > 0)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 5),
              child: Text(
                '-',
                style: TextStyle(color: AppColors.muted, fontSize: 13),
              ),
            ),
          Text(
            '${points[i]}',
            style: TextStyle(
              color:
                  i == controller.viewerSeat ? AppColors.text : AppColors.muted,
              fontSize: 15,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
        const SizedBox(width: 8),
        Text(
          s.matchTotal,
          style: const TextStyle(color: AppColors.muted, fontSize: 11),
        ),
      ],
    );
  }
}

/// The opponent: face-down cards, how many they hold, and what they have
/// banked. Never their faces - not for a bot, and not in hotseat either.
class _OpponentStrip extends StatelessWidget {
  const _OpponentStrip({required this.controller, required this.opponentName});

  final ChkobbaController controller;
  final String opponentName;

  @override
  Widget build(BuildContext context) {
    final s = AppScope.stringsOf(context);
    final seat = controller.opponentSeat;
    final hand = controller.handOf(seat);
    final thinking = controller.botThinking;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      color: AppColors.bg2,
      child: Row(
        children: [
          SizedBox(
            height: 34,
            child: Row(
              children: [
                for (final _ in hand)
                  const Padding(
                    padding: EdgeInsetsDirectional.only(end: 3),
                    child: PlayingCard(width: 22),
                  ),
                if (hand.isEmpty)
                  Text(
                    s.emptyTable,
                    style:
                        const TextStyle(color: AppColors.muted, fontSize: 12),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        opponentName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    if (thinking) ...[
                      const SizedBox(width: 6),
                      const SizedBox(
                        width: 10,
                        height: 10,
                        child: CircularProgressIndicator(strokeWidth: 1.6),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  '${s.captured} ${controller.cardsHeldBy(seat)}  ·  '
                  '${s.chkobbas} ${controller.chkobbasBy(seat)}  ·  '
                  '${s.stockLabel} ${controller.stockCount}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: AppColors.muted, fontSize: 11),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The middle: the table pile, the Chkobba marker, and the last move.
class _TableSurface extends StatelessWidget {
  const _TableSurface({
    required this.controller,
    required this.lastAction,
    required this.wide,
  });

  final ChkobbaController controller;
  final String? lastAction;
  final bool wide;

  @override
  Widget build(BuildContext context) {
    final s = AppScope.stringsOf(context);
    final table = controller.tableCards();
    final marker = controller.chkobbaMarker;
    final cardWidth = wide
        ? 44.0
        : (MediaQuery.sizeOf(context).width * 0.19).clamp(30.0, 46.0);

    return Container(
      width: double.infinity,
      color: AppColors.bg,
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 6),
      child: Column(
        children: [
          Expanded(
            child: Center(
              child: table.isEmpty && marker == null
                  ? Text(
                      s.emptyTable,
                      style:
                          const TextStyle(color: AppColors.muted, fontSize: 13),
                    )
                  : Wrap(
                      alignment: WrapAlignment.center,
                      runAlignment: WrapAlignment.center,
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        for (final c in table)
                          PlayingCard(
                            key: ValueKey<String>('table-${c.id}'),
                            card: c,
                            width: cardWidth,
                            showValue: true,
                          ),
                        // The Chkobba marker is the played card left face up
                        // after a sweep. It is already in the capturer's pile in
                        // the engine, so it is drawn here and not counted twice.
                        if (marker != null)
                          PlayingCard(
                            key: const ValueKey<String>('chkobba-marker'),
                            card: marker,
                            width: cardWidth,
                            showValue: true,
                            dimmed: true,
                          ),
                      ],
                    ),
            ),
          ),
          if (lastAction != null)
            Padding(
              padding: const EdgeInsets.only(top: 4, bottom: 2),
              child: Text(
                lastAction!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.muted, fontSize: 12),
              ),
            ),
        ],
      ),
    );
  }
}

/// Your hand, plus the one button that matters: play the lifted card.
class _HandBar extends StatelessWidget {
  const _HandBar({required this.controller, required this.onPlay});

  final ChkobbaController controller;
  final void Function(int cardId) onPlay;

  @override
  Widget build(BuildContext context) {
    final s = AppScope.stringsOf(context);
    final seat = controller.viewerSeat;
    final hand = controller.handOf(seat);
    final myTurn = controller.isMyTurn;
    final selected = controller.selectedCardId;
    final wide = MediaQuery.sizeOf(context).width >= 720;
    final cardWidth = wide ? 58.0 : 50.0;

    return Container(
      width: double.infinity,
      color: AppColors.bg2,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  myTurn
                      ? (controller.setup.mode == ChkobbaMode.hotseat
                          ? '${s.passThePhone} · ${s.hand}'
                          : '${s.yourTurn} · ${s.hand}')
                      : '${controller.opponentSeat == 0 ? s.playerOne : s.playerTwo} · ${s.hand}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: myTurn ? AppColors.acc : AppColors.muted,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (hand.isNotEmpty)
                Text(
                  '${hand.length}',
                  style: const TextStyle(
                    color: AppColors.muted,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: cardWidth / cardAspect + 20,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  for (final c in hand)
                    Padding(
                      padding: const EdgeInsetsDirectional.only(end: 6),
                      child: PlayingCard(
                        // Keyed by seat and card id so a test can tap one exact
                        // card instead of guessing by position.
                        key: ValueKey<String>('hand-$seat-${c.id}'),
                        card: c,
                        width: cardWidth,
                        showValue: true,
                        selected: myTurn && selected == c.id,
                        onTap: myTurn ? () => onPlay(c.id) : null,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Round and match end. The reasons come straight from the engine, so the UI
/// never re-implements scoring - the same list the online server will store.
class _EndPanel extends StatelessWidget {
  const _EndPanel({
    required this.controller,
    required this.onNextRound,
    required this.onRestart,
  });

  final ChkobbaController controller;
  final VoidCallback onNextRound;
  final VoidCallback onRestart;

  @override
  Widget build(BuildContext context) {
    final s = AppScope.stringsOf(context);
    final over = controller.matchOver;
    final winner = controller.matchWinner;
    final youWon = winner >= 0 && winner == controller.viewerSeat;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      decoration: const BoxDecoration(
        color: AppColors.card,
        border: Border(top: BorderSide(color: AppColors.line)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  over ? s.matchOver : s.roundOver,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              if (over)
                Text(
                  youWon ? s.youWin : s.youLose,
                  style: TextStyle(
                    color: youWon ? AppColors.good : AppColors.acc,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          for (final score in controller.roundScores)
            Padding(
              padding: const EdgeInsets.only(bottom: 3),
              child: Text(
                '${score.team == controller.viewerSeat ? s.yourPile : s.captured}: '
                '+${score.points}  ·  ${score.reasons.join(' · ')}',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: AppColors.muted, fontSize: 12),
              ),
            ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: FilledButton(
                  onPressed: onNextRound,
                  child: Text(over ? s.newMatch : s.nextRound),
                ),
              ),
              if (over) ...[
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton(
                    onPressed: onRestart,
                    child: Text(s.changeRules),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

/// One possible capture in the chooser, drawn as the actual cards it takes.
class _CaptureChoice extends StatelessWidget {
  const _CaptureChoice({super.key, required this.option, required this.onTap});

  final CaptureOption option;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.bg2,
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            children: [
              for (final c in option.cards)
                Padding(
                  padding: const EdgeInsetsDirectional.only(end: 4),
                  child: PlayingCard(card: c, width: 34, showValue: true),
                ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  '${option.size}',
                  style: const TextStyle(
                    color: AppColors.muted,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// THE moment. A red flash, the shout, and a short shake - then it is gone.
///
/// Hand-rolled from a TweenAnimationBuilder rather than a controller so it
/// always finishes: an animation that can hang makes `pumpAndSettle` throw in
/// the widget tests, and a Chkobba flash that never fades is worse than none.
class _ChkobbaFlash extends StatelessWidget {
  const _ChkobbaFlash({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    HapticFeedback.heavyImpact();
    return IgnorePointer(
      child: TweenAnimationBuilder<double>(
        tween: Tween<double>(begin: 0, end: 1),
        duration: const Duration(milliseconds: 520),
        curve: Curves.easeOut,
        builder: (context, t, _) {
          // Shake: a few decaying oscillations, back to centre at both ends.
          final shake = (1 - t) * 10 * _wave(t * 6);
          return Transform.translate(
            offset: Offset(shake, 0),
            child: Opacity(
              opacity: t < 0.15 ? t / 0.15 : 1,
              child: Container(
                color: AppColors.accSoft,
                alignment: Alignment.center,
                child: Text(
                  text,
                  textDirection: TextDirection.ltr,
                  style: TextStyle(
                    color: AppColors.acc,
                    fontSize: 46 * (0.7 + 0.3 * t),
                    fontWeight: FontWeight.w900,
                    letterSpacing: 2,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  /// sin() without importing dart:math into a widget file, for 6 fixed samples.
  static double _wave(double x) {
    const table = <double>[0, 0.866, 0.866, 0, -0.866, -0.866];
    final i = x.floor();
    if (i < 0 || i >= table.length) return 0;
    final f = x - i;
    final a = table[i];
    // Bounds-checked rather than `?? 0`: the analyzer is right that the element
    // is non-null, and it would be wrong to index past the end.
    final b = i + 1 < table.length ? table[i + 1] : 0.0;
    return a + (b - a) * f;
  }
}
