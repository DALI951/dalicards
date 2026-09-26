import 'package:flutter/material.dart';

import '../../games/registry.dart';
import '../../l10n/app_strings.dart';
import '../../theme.dart';

/// Where a game goes once you tap it.
///
/// Today this says the honest thing: the rules are done, the table is next. M4
/// replaces the Chkobba half and M5 the Rami half, so the route, the app bar
/// and the back button are already proven before any card is drawn.
class TableScreen extends StatelessWidget {
  const TableScreen({super.key, required this.game});

  final GameEntry game;

  @override
  Widget build(BuildContext context) {
    final s = AppScope.stringsOf(context);
    return Scaffold(
      appBar: AppBar(title: Text(game.name.of(s.locale))),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
            children: [
              _Header(game: game),
              const SizedBox(height: 14),
              _EngineBadge(
                label: s.engineReady,
                milestone: game.milestone,
              ),
              const SizedBox(height: 20),
              Text(
                s.tableComing,
                style: const TextStyle(
                  color: AppColors.muted,
                  height: 1.5,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
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
}

class _Header extends StatelessWidget {
  const _Header({required this.game});

  final GameEntry game;

  @override
  Widget build(BuildContext context) {
    final s = AppScope.stringsOf(context);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: Border.all(color: AppColors.line),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.card, AppColors.bg2],
        ),
      ),
      child: Row(
        children: [
          _Monogram(name: game.name.of(s.locale)),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  game.name.of(s.locale),
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                      ),
                ),
                const SizedBox(height: 5),
                Text(
                  game.tagline.of(s.locale),
                  style: const TextStyle(
                    color: AppColors.muted,
                    fontSize: 13,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Monogram extends StatelessWidget {
  const _Monogram({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 52,
      height: 52,
      decoration: BoxDecoration(
        color: AppColors.card2,
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      alignment: Alignment.center,
      child: Text(
        // Safe: every registered game has a non-empty name.
        name.characters.first,
        style: const TextStyle(
          color: AppColors.acc,
          fontSize: 24,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _EngineBadge extends StatelessWidget {
  const _EngineBadge({required this.label, required this.milestone});

  final String label;
  final String milestone;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Icon(Icons.check_circle_rounded, color: AppColors.good, size: 17),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              color: AppColors.good,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: AppColors.card2,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: AppColors.line),
          ),
          // Latin milestone tag, so it stays readable inside an Arabic layout.
          child: Text(
            milestone,
            textDirection: TextDirection.ltr,
            style: const TextStyle(
              color: AppColors.muted,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}
