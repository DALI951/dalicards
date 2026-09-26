import 'package:dalicards/games/registry.dart';
import 'package:dalicards/l10n/app_strings.dart';
import 'package:dalicards/theme.dart';
import 'package:dalicards/ui/chkobba/chkobba_controller.dart';
import 'package:dalicards/ui/chkobba/chkobba_table.dart';
import 'package:engine/engine.dart';
import 'package:flutter/material.dart';

/// Everything you choose before the first card is dealt: who you play, how hard,
/// and which house rules your table actually plays.
///
/// Every toggle here is a flag on `ChkobbaRules`. Nothing on this screen needs
/// an engine change, which is the point: the engine shipped in M1 with the
/// variants already in it.
class ChkobbaSetupScreen extends StatefulWidget {
  const ChkobbaSetupScreen({super.key, required this.game, this.initialSetup});

  final GameEntry game;

  /// Lets a shared link carry the whole table setup.
  final ChkobbaSetup? initialSetup;

  @override
  State<ChkobbaSetupScreen> createState() => _ChkobbaSetupScreenState();
}

class _ChkobbaSetupScreenState extends State<ChkobbaSetupScreen> {
  late ChkobbaSetup _setup = widget.initialSetup ?? const ChkobbaSetup();
  bool _showRules = false;

  void _patch(ChkobbaSetup next) {
    setState(() => _setup = next);
  }

  void _deal() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ChkobbaTableScreen(game: widget.game, setup: _setup),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = AppScope.stringsOf(context);
    return Scaffold(
      appBar: AppBar(title: Text(s.playChkobba)),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
            children: [
              SectionLabel(s.pickAGame),
              const SizedBox(height: 12),
              _ModeCard(
                title: s.vsBot,
                body: s.vsBotBody,
                icon: Icons.smart_toy_rounded,
                selected: _setup.mode == ChkobbaMode.solo,
                onTap: () => _patch(_setup.copyWith(mode: ChkobbaMode.solo)),
              ),
              const SizedBox(height: 10),
              _ModeCard(
                title: s.hotseat,
                body: s.hotseatBody,
                icon: Icons.people_alt_rounded,
                selected: _setup.mode == ChkobbaMode.hotseat,
                onTap: () => _patch(_setup.copyWith(mode: ChkobbaMode.hotseat)),
              ),
              if (_setup.mode == ChkobbaMode.solo) ...[
                const SizedBox(height: 22),
                SectionLabel(s.bot),
                const SizedBox(height: 12),
                for (final level in BotLevel.values) ...[
                  _LevelCard(
                    level: level,
                    title: _levelName(s, level),
                    body: _levelBody(s, level),
                    selected: _setup.level == level,
                    onTap: () => _patch(_setup.copyWith(level: level)),
                  ),
                  const SizedBox(height: 10),
                ],
              ],
              const SizedBox(height: 22),
              _RulesBlock(
                setup: _setup,
                expanded: _showRules,
                onToggle: () => setState(() => _showRules = !_showRules),
                onPatch: _patch,
              ),
              const SizedBox(height: 22),
              FilledButton.icon(
                onPressed: _deal,
                icon: const Icon(Icons.style_rounded, size: 18),
                label: Text(s.startGame),
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: () => Navigator.of(context).maybePop(),
                icon: const Icon(Icons.arrow_back_rounded, size: 18),
                label: Text(s.backToGames),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _levelName(AppStrings s, BotLevel level) => switch (level) {
        BotLevel.easy => s.botEasy,
        BotLevel.normal => s.botNormal,
        BotLevel.hard => s.botHard,
      };

  static String _levelBody(AppStrings s, BotLevel level) => switch (level) {
        BotLevel.easy => s.botEasyBody,
        BotLevel.normal => s.botNormalBody,
        BotLevel.hard => s.botHardBody,
      };
}

class _ModeCard extends StatelessWidget {
  const _ModeCard({
    required this.title,
    required this.body,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String title;
  final String body;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return _Selectable(
      selected: selected,
      onTap: onTap,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            size: 20,
            color: selected ? AppColors.acc : AppColors.muted,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  body,
                  style: const TextStyle(
                    color: AppColors.muted,
                    fontSize: 13,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          _Radio(selected: selected),
        ],
      ),
    );
  }
}

class _LevelCard extends StatelessWidget {
  const _LevelCard({
    required this.level,
    required this.title,
    required this.body,
    required this.selected,
    required this.onTap,
  });

  final BotLevel level;
  final String title;
  final String body;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    // Three bars, filled by level: a level you can see at a glance.
    final filled = level.index + 1;
    return _Selectable(
      selected: selected,
      onTap: onTap,
      child: Row(
        children: [
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var i = 0; i < 3; i++)
                Container(
                  width: 4,
                  height: 12,
                  margin: const EdgeInsets.only(bottom: 3),
                  decoration: BoxDecoration(
                    color: i < filled ? AppColors.acc : AppColors.line,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  body,
                  style: const TextStyle(
                    color: AppColors.muted,
                    fontSize: 13,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          _Radio(selected: selected),
        ],
      ),
    );
  }
}

class _Selectable extends StatelessWidget {
  const _Selectable({
    required this.selected,
    required this.onTap,
    required this.child,
  });

  final bool selected;
  final VoidCallback onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColors.accSoft : AppColors.card,
      borderRadius: BorderRadius.circular(AppRadius.xl),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.xl),
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.xl),
            border: Border.all(
              color: selected ? AppColors.acc : AppColors.line,
            ),
          ),
          padding: const EdgeInsets.all(14),
          child: child,
        ),
      ),
    );
  }
}

class _Radio extends StatelessWidget {
  const _Radio({required this.selected});

  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 20,
      height: 20,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: selected ? AppColors.acc : AppColors.line,
          width: 2,
        ),
      ),
      alignment: Alignment.center,
      child: selected
          ? Container(
              width: 9,
              height: 9,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.acc,
              ),
            )
          : null,
    );
  }
}

/// The house rules, collapsed by default. Four flags, no code.
class _RulesBlock extends StatelessWidget {
  const _RulesBlock({
    required this.setup,
    required this.expanded,
    required this.onToggle,
    required this.onPatch,
  });

  final ChkobbaSetup setup;
  final bool expanded;
  final VoidCallback onToggle;
  final void Function(ChkobbaSetup) onPatch;

  @override
  Widget build(BuildContext context) {
    final s = AppScope.stringsOf(context);
    return Container(
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: Border.all(color: AppColors.line),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          InkWell(
            onTap: onToggle,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const Icon(Icons.tune_rounded,
                      size: 18, color: AppColors.muted),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          s.houseRules,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          s.houseRulesBody,
                          style: const TextStyle(
                            color: AppColors.muted,
                            fontSize: 12,
                            height: 1.35,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    expanded
                        ? Icons.expand_less_rounded
                        : Icons.expand_more_rounded,
                    size: 20,
                    color: AppColors.muted,
                  ),
                ],
              ),
            ),
          ),
          if (expanded) ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _FlagRow(
                    label: s.faceValues,
                    // Latin digits and letters, so it reads the same in an RTL
                    // layout instead of flipping into nonsense.
                    value: setup.faceValues == FaceValues.tunisian
                        ? s.faceValuesDefault
                        : s.faceValuesSwapped,
                    onTap: () => onPatch(
                      _setup.copyWith(
                        faceValues: setup.faceValues == FaceValues.tunisian
                            ? FaceValues.swapped
                            : FaceValues.tunisian,
                      ),
                    ),
                  ),
                  _FlagRow(
                    label: s.targetScore,
                    value: '${setup.targetScore}',
                    onTap: () {
                      const options = <int>[11, 21, 31];
                      final next = options[
                          (options.indexOf(setup.targetScore) + 1) %
                              options.length];
                      onPatch(_setup.copyWith(targetScore: next));
                    },
                  ),
                  _FlagRow(
                    label: s.dealSize,
                    value: '${setup.dealSize}',
                    onTap: () => onPatch(
                      _setup.copyWith(dealSize: setup.dealSize == 3 ? 4 : 3),
                    ),
                  ),
                  _FlagRow(
                    label: s.capturePriorityLabel,
                    value: setup.capturePriority == CapturePriority.singleFirst
                        ? s.singleBeatsSum
                        : s.bestSumWins,
                    onTap: () => onPatch(
                      _setup.copyWith(
                        capturePriority:
                            setup.capturePriority == CapturePriority.singleFirst
                                ? CapturePriority.bestSum
                                : CapturePriority.singleFirst,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  ChkobbaSetup get _setup => setup;
}

class _FlagRow extends StatelessWidget {
  const _FlagRow({
    required this.label,
    required this.value,
    required this.onTap,
  });

  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 4),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style:
                    const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              ),
            ),
            const SizedBox(width: 10),
            Flexible(
              child: Text(
                value,
                maxLines: 2,
                textAlign: TextAlign.end,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppColors.acc,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(width: 6),
            const Icon(Icons.swap_horiz_rounded,
                size: 16, color: AppColors.muted),
          ],
        ),
      ),
    );
  }
}
