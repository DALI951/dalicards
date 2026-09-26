import 'package:dalicards/games/registry.dart';
import 'package:dalicards/l10n/app_strings.dart';
import 'package:dalicards/theme.dart';
import 'package:flutter/material.dart';

/// The game picker. Reads the whole catalogue from [GameRegistry] so a new game
/// is one entry there, and every string from [AppStrings] so the whole screen
/// flips with the language.
class HubScreen extends StatelessWidget {
  const HubScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = AppScope.stringsOf(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(s.appTitle),
        actions: [
          const _LanguageButton(),
          IconButton(
            tooltip: s.settings,
            onPressed: () => _toast(context, s.settingsSoon),
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
              SectionLabel(s.pickAGame),
              const SizedBox(height: 12),
              for (final game in GameRegistry.all) ...[
                _GameTile(game: game),
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
}

void _toast(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}

/// Language picker in the app bar. One globe, the current language as a tick.
class _LanguageButton extends StatelessWidget {
  const _LanguageButton();

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final s = app.strings;
    return PopupMenuButton<String>(
      tooltip: s.language,
      icon: const Icon(Icons.language_rounded, size: 20),
      onSelected: (code) => app.locale = AppLocales.byCode(code),
      itemBuilder: (context) => [
        for (final locale in AppLocales.supported)
          PopupMenuItem<String>(
            value: locale.languageCode,
            child: Row(
              children: [
                if (locale.languageCode == app.locale.languageCode)
                  const Icon(
                    Icons.check_rounded,
                    size: 16,
                    color: AppColors.acc,
                  )
                else
                  const SizedBox(width: 16),
                const SizedBox(width: 10),
                Text(AppLocales.nativeName(locale)),
              ],
            ),
          ),
      ],
    );
  }
}

class _Hero extends StatelessWidget {
  const _Hero();

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
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  s.heroTitle,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                      ),
                ),
                const SizedBox(height: 6),
                Text(
                  s.heroBody,
                  style: const TextStyle(
                    color: AppColors.muted,
                    height: 1.4,
                  ),
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
/// Kept symmetric on purpose so it needs no mirroring in Arabic.
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
    final s = AppScope.stringsOf(context);
    final rtl = Directionality.of(context) == TextDirection.rtl;
    final planned = !game.isOpen;

    return Opacity(
      opacity: planned ? 0.55 : 1,
      child: Material(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.xl),
          onTap: () {
            if (planned) {
              _toast(context, s.plannedYet);
              return;
            }
            Navigator.of(context).pushNamed(GameRegistry.routeFor(game.id));
          },
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadius.xl),
              border: Border.all(color: AppColors.line),
            ),
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                _Monogram(name: game.name.of(s.locale)),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              game.name.of(s.locale),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Flexible(
                            child: _StatusChip(
                              status: game.status,
                              label: _statusLabel(s, game.status),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        game.tagline.of(s.locale),
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
                      game.players.of(s.locale),
                      style: const TextStyle(
                        color: AppColors.muted,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Icon(
                      planned
                          ? Icons.lock_outline_rounded
                          : (rtl
                              ? Icons.chevron_left_rounded
                              : Icons.chevron_right_rounded),
                      size: 20,
                      color: planned ? AppColors.muted : AppColors.acc,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static String _statusLabel(AppStrings s, GameStatus status) =>
      switch (status) {
        GameStatus.playable => s.statusPlayable,
        GameStatus.tableInProgress => s.statusBuilding,
        GameStatus.planned => s.statusPlanned,
      };
}

class _Monogram extends StatelessWidget {
  const _Monogram({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 46,
      height: 46,
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
          fontSize: 22,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status, required this.label});

  final GameStatus status;
  final String label;

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      GameStatus.playable => AppColors.good,
      GameStatus.tableInProgress => AppColors.gold,
      GameStatus.planned => AppColors.muted,
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
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
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
    final s = AppScope.stringsOf(context);
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
              Expanded(
                child: Text(
                  s.playAFriend,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            s.playAFriendBody,
            style: const TextStyle(
              color: AppColors.muted,
              fontSize: 13,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 14),
          // Wrap rather than a fixed Row: the buttons keep their natural width
          // and drop to a second row on a narrow phone instead of overflowing,
          // which they did at 320px with the longer Arabic labels.
          Wrap(
            spacing: 10,
            runSpacing: 10,
            alignment: WrapAlignment.center,
            children: [
              FilledButton.icon(
                onPressed: () => _toast(context, s.onlineSoon),
                icon: const Icon(Icons.add_link_rounded, size: 18),
                label: Text(s.createTable),
              ),
              OutlinedButton.icon(
                onPressed: () => _toast(context, s.friendsSoon),
                icon: const Icon(Icons.person_add_alt_1_rounded, size: 18),
                label: Text(s.addFriend),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
