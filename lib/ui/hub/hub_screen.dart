import 'package:flutter/material.dart';

import '../../theme.dart';

/// One entry in the hub. A game only needs this record to be listed; the
/// actual screens are registered later (M4 Chkobba, M5 Rami).
class GameEntry {
  const GameEntry({
    required this.id,
    required this.name,
    required this.tagline,
    required this.players,
    required this.status,
    this.script = 'latin',
  });

  final String id;
  final String name;
  final String tagline;
  final String players;
  final GameStatus status;
  final String script;
}

enum GameStatus { playable, inProgress, planned }

class HubScreen extends StatefulWidget {
  const HubScreen({super.key});

  @override
  State<HubScreen> createState() => _HubScreenState();
}

class _HubScreenState extends State<HubScreen> {
  // Temporary catalogue until the game registry lands in M3.
  static const games = <GameEntry>[
    GameEntry(
      id: 'chkobba',
      name: 'Chkobba',
      tagline: 'Sweep the table. Shout CHKOBBAAA!',
      players: '2 or 4',
      status: GameStatus.inProgress,
    ),
    GameEntry(
      id: 'rami',
      name: 'Rami',
      tagline: 'Melds, jokers, 51-point opening drop',
      players: '2-4',
      status: GameStatus.planned,
    ),
    GameEntry(
      id: 'belote',
      name: 'Belote',
      tagline: 'The classic trick game',
      players: '2 or 4',
      status: GameStatus.planned,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('DaliCards'),
        actions: [
          IconButton(
            tooltip: 'Settings',
            onPressed: () => _toast('Settings land in M10'),
            icon: const Icon(Icons.tune_rounded, size: 20),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
            children: [
              const _Hero(),
              const SizedBox(height: 26),
              const SectionLabel('Pick a game'),
              const SizedBox(height: 12),
              for (final g in games) ...[
                _GameTile(game: g),
                const SizedBox(height: 10),
              ],
              const SizedBox(height: 22),
              const _OnlineCard(),
            ],
          ),
        ),
      ),
    );
  }

  void _toast(String msg) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(msg)));
  }
}

class _Hero extends StatelessWidget {
  const _Hero();

  @override
  Widget build(BuildContext context) {
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
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Tunisian card games',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                      ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Play solo against a bot, pass the phone, or send a link '
                  'and play a friend online.',
                  style: TextStyle(color: AppColors.muted, height: 1.4),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          const _MiniFan(),
        ],
      ),
    );
  }
}

/// Decorative card fan, drawn in code (no image assets anywhere in this app).
class _MiniFan extends StatelessWidget {
  const _MiniFan();

  @override
  Widget build(BuildContext context) {
    const labels = ['A', 'K', '7'];
    const colors = [
      AppColors.cardRed,
      AppColors.cardBlack,
      AppColors.acc,
    ];
    return SizedBox(
      width: 84,
      height: 74,
      child: Stack(
        alignment: Alignment.center,
        children: [
          for (var i = 0; i < labels.length; i++)
            Transform.rotate(
              angle: (i - 1) * 0.28,
              child: Container(
                width: 40,
                height: 58,
                decoration: BoxDecoration(
                  color: colors[i],
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: AppColors.line),
                ),
                alignment: Alignment.topLeft,
                padding: const EdgeInsets.all(4),
                child: Text(
                  labels[i],
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _GameTile extends StatelessWidget {
  const _GameTile({required this.game});

  final GameEntry game;

  @override
  Widget build(BuildContext context) {
    final locked = game.status != GameStatus.playable;
    return Opacity(
      opacity: locked ? 0.55 : 1,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(AppRadius.xl),
          border: Border.all(color: AppColors.line),
        ),
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: AppColors.card2,
                borderRadius: BorderRadius.circular(AppRadius.lg),
              ),
              alignment: Alignment.center,
              child: Text(
                game.name.characters.first,
                style: const TextStyle(
                  color: AppColors.acc,
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        game.name,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(width: 8),
                      _StatusChip(status: game.status),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    game.tagline,
                    style: const TextStyle(
                      color: AppColors.muted,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  game.players,
                  style: const TextStyle(
                    color: AppColors.muted,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Icon(
                  locked
                      ? Icons.lock_outline_rounded
                      : Icons.chevron_right_rounded,
                  size: 20,
                  color: locked ? AppColors.muted : AppColors.acc,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});

  final GameStatus status;

  @override
  Widget build(BuildContext context) {
    final (String label, Color color) = switch (status) {
      GameStatus.playable => ('PLAYABLE', AppColors.good),
      GameStatus.inProgress => ('BUILDING', AppColors.gold),
      GameStatus.planned => ('PLANNED', AppColors.muted),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 9,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}

class _OnlineCard extends StatelessWidget {
  const _OnlineCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: Border.all(color: AppColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.bolt_rounded, color: AppColors.acc, size: 18),
              const SizedBox(width: 8),
              Text(
                'Play a friend',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'Create a table, share the link, play in real time. Your friend '
            'does not even need an account.',
            style: TextStyle(color: AppColors.muted, fontSize: 13, height: 1.4),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: () => ScaffoldMessenger.of(context)
                    ..hideCurrentSnackBar()
                    ..showSnackBar(const SnackBar(
                      content:
                          Text('Online tables arrive with milestone M7'),
                    )),
                  icon: const Icon(Icons.add_link_rounded, size: 18),
                  label: const Text('Create a table'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => ScaffoldMessenger.of(context)
                    ..hideCurrentSnackBar()
                    ..showSnackBar(const SnackBar(
                      content: Text('Friend codes arrive with milestone M6'),
                    )),
                  icon: const Icon(Icons.person_add_alt_1_rounded, size: 18),
                  label: const Text('Add a friend'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
