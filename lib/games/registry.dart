import 'package:flutter/widgets.dart';

import 'l10n/app_strings.dart';
import 'ui/game/table_screen.dart';

/// How far along a game is. Honest about it: Chkobba and Rami have finished,
/// tested engines, so they are not "planned" any more, but there is no table
/// to sit at until M4 and M5.
enum GameStatus {
  /// Playable end to end.
  playable,

  /// Rules engine shipped and tested, table UI still being built.
  tableInProgress,

  /// Named on the list, nothing built.
  planned,
}

typedef GameBuilder = Widget Function(BuildContext context, GameEntry game);

/// One game in the hub. Adding a game means adding one entry here and one
/// screen builder, nothing else.
@immutable
class GameEntry {
  const GameEntry({
    required this.id,
    required this.name,
    required this.tagline,
    required this.players,
    required this.status,
    required this.milestone,
    required this.builder,
  });

  final String id;
  final L10nText name;
  final L10nText tagline;
  final L10nText players;
  final GameStatus status;

  /// Which milestone delivers the table, shown on the coming-soon screen.
  final String milestone;

  final GameBuilder builder;

  /// True when tapping should go somewhere. A planned game only grumbles.
  bool get isOpen => status != GameStatus.planned;
}

class GameRegistry {
  const GameRegistry._();

  static const List<GameEntry> all = <GameEntry>[
    GameEntry(
      id: 'chkobba',
      name: L10nText('Chkobba', 'شكوببا', 'Chkobba'),
      tagline: L10nText(
        'Sweep the table. Shout CHKOBBAAA!',
        'نظّف الطاولة. وصّح: شكوببا!',
        'Balaye la table. Crie CHKOBBAAA !',
      ),
      players: L10nText('2 or 4', '2 أو 4', '2 ou 4'),
      status: GameStatus.tableInProgress,
      milestone: 'M4',
      builder: _table,
    ),
    GameEntry(
      id: 'rami',
      name: L10nText('Rami', 'رامي', 'Rami'),
      tagline: L10nText(
        'Melds, jokers, and a 51-point opening',
        'مجموعات، جوكر، وفتح بـ51 نقطة',
        'Combinaisons, jokers, et ouverture à 51 points',
      ),
      players: L10nText('2-4', '2-4', '2-4'),
      status: GameStatus.tableInProgress,
      milestone: 'M5',
      builder: _table,
    ),
    GameEntry(
      id: 'belote',
      name: L10nText('Belote', 'بلوت', 'Belote'),
      tagline: L10nText(
        'The classic trick game',
        'لعبة بلوت الكلاسيكية',
        'Le classique de la prise',
      ),
      players: L10nText('2 or 4', '2 أو 4', '2 ou 4'),
      status: GameStatus.planned,
      milestone: 'later',
      builder: _table,
    ),
  ];

  static GameEntry? byId(String id) {
    for (final entry in all) {
      if (entry.id == id) return entry;
    }
    return null;
  }

  static String routeFor(String id) => '/game/$id';

  /// Named routes, so navigation is a string and the hub needs no imports of
  /// the screens it opens.
  static Map<String, WidgetBuilder> get routes => <String, WidgetBuilder>{
        for (final entry in all)
          routeFor(entry.id): (context) => entry.builder(context, entry),
      };

  static Widget _table(BuildContext context, GameEntry game) =>
      TableScreen(game: game);
}
