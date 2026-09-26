import 'package:flutter/widgets.dart';

/// The three languages DaliCards ships.
///
/// French because a lot of Tunisians read it easily, Arabic because that is the
/// language the tables are actually played in.
class AppLocales {
  const AppLocales._();

  static const Locale english = Locale('en');
  static const Locale arabic = Locale('ar');
  static const Locale french = Locale('fr');

  static const List<Locale> supported = <Locale>[english, arabic, french];

  /// Shown in the picker in its own language, the way every language list
  /// should be, so nobody has to guess what "FR" means.
  static String nativeName(Locale locale) => switch (locale.languageCode) {
        'ar' => 'العربية',
        'fr' => 'Français',
        _ => 'English',
      };

  static Locale byCode(String code) => switch (code) {
        'ar' => arabic,
        'fr' => french,
        _ => english,
      };

  /// Reads `?lang=ar` / `?lang=fr` from the address bar.
  ///
  /// Two uses: Dali can open a link on his phone to check the Arabic layout
  /// without hunting through the menu, and CI can screenshot the RTL build by
  /// loading a different URL instead of needing a build flag.
  static Locale? fromQuery() {
    try {
      final code = Uri.base.queryParameters['lang'];
      if (code == null || code.isEmpty) return null;
      return byCode(code);
    } catch (_) {
      // Not a web context, so there is no query string to read.
      return null;
    }
  }
}

/// A string in all three languages, kept next to its translations.
class L10nText {
  const L10nText(this.en, this.ar, this.fr);

  final String en;
  final String ar;
  final String fr;

  String of(Locale locale) => switch (locale.languageCode) {
        'ar' => ar,
        'fr' => fr,
        _ => en,
      };
}

/// Every string the shell needs, resolved for one locale.
///
/// Hand written instead of generated: the vocabulary here is small and fixed,
/// and generated l10n would add a build step that CI has to run before it can
/// even analyze the code. When the vocabulary grows for the game screens in
/// M4/M5, switch to `gen_l10n` then.
class AppStrings {
  const AppStrings(this.locale);

  final Locale locale;

  bool get isRtl => locale.languageCode == 'ar';

  String _t(String en, String ar, String fr) => switch (locale.languageCode) {
        'ar' => ar,
        'fr' => fr,
        _ => en,
      };

  // -- shell ---------------------------------------------------------------

  String get appTitle => 'DaliCards';
  String get language => _t('Language', 'اللغة', 'Langue');
  String get settings => _t('Settings', 'الإعدادات', 'Réglages');
  String get settingsSoon =>
      _t('Settings arrive in M10', 'الإعدادات في M10', 'Réglages en M10');
  String get backToGames =>
      _t('Back to games', 'ارجع للألعاب', 'Retour aux jeux');

  // -- hub -----------------------------------------------------------------

  String get heroTitle =>
      _t('Tunisian card games', 'ألعاب الورق التونسية', 'Jeux de cartes tunisiens');
  String get heroBody => _t(
        'Play a bot, pass the phone, or send a link and play a friend online.',
        'العب ضد بوت، ولا مرّر الهاتف لصديقك، ولا أرسل رابط والعب مع صديقك أونلاين.',
        'Joue contre un bot, passe le téléphone, ou envoie un lien pour jouer avec un ami.',
      );
  String get pickAGame => _t('Pick a game', 'اختر لعبة', 'Choisis un jeu');
  String get playAFriend =>
      _t('Play a friend', 'العب مع صديق', 'Joue avec un ami');
  String get playAFriendBody => _t(
        'Create a table, share the link, and play in real time. No account '
            'needed.',
        'أنشئ طاولة، شارك الرابط، والعب مباشرة. صديقك ما يحتاجش حساب.',
        'Crée une table, partage le lien et joue en direct. Aucun compte '
            'nécessaire.',
      );
  String get createTable =>
      _t('Create a table', 'أنشئ طاولة', 'Créer une table');
  String get addFriend => _t('Add a friend', 'أضف صديق', 'Ajouter un ami');
  String get onlineSoon => _t(
        'Online tables arrive with M7',
        'الطاولات أونلاين في M7',
        'Les tables en ligne arrivent en M7',
      );
  String get friendsSoon => _t(
        'Friend codes arrive with M6',
        'أكواد الأصدقاء في M6',
        'Les codes d\'amis arrivent en M6',
      );
  String get plannedYet => _t(
        'Belote is on the list, not built yet.',
        'بلوت في القائمة، برك ما وصلتش.',
        'Belote est sur la liste, pas encore construite.',
      );

  // -- status chips --------------------------------------------------------

  String get statusPlayable => _t('PLAYABLE', 'متاحة', 'JOUABLE');
  String get statusBuilding => _t('BUILDING', 'قيد الإنشاء', 'EN COURS');
  String get statusPlanned => _t('PLANNED', 'مخططة', 'PRÉVU');

  // -- table screen --------------------------------------------------------

  String get engineReady =>
      _t('Rules engine ready', 'محرك القواعد جاهز', 'Moteur de règles prêt');
  String get tableComing => _t(
        'The rules are finished and tested. The playable table lands next.',
        'القواعد خلصت واختبرت. الطاولة الجاية هي اللي تنلعب.',
        'Les règles sont finies et testées. La table jouable arrive ensuite.',
      );
}

/// App-wide state that survives navigation: for now just the chosen language.
class AppState extends ChangeNotifier {
  Locale _locale = AppLocales.english;
  Locale get locale => _locale;

  set locale(Locale value) {
    if (value.languageCode == _locale.languageCode) return;
    _locale = value;
    notifyListeners();
  }

  AppStrings get strings => AppStrings(_locale);
}

/// Makes [AppState] reachable from any widget, and rebuilds them when it
/// changes. Sits above `MaterialApp` so every route can see it.
class AppScope extends InheritedNotifier<AppState> {
  const AppScope({super.key, required AppState state, required super.child})
      : super(notifier: state);

  static AppState of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AppScope>();
    assert(scope != null, 'No AppScope above this widget.');
    return scope!.notifier!;
  }

  static AppStrings stringsOf(BuildContext context) => of(context).strings;

  @override
  bool updateShouldNotify(AppScope oldWidget) => oldWidget.notifier != notifier;
}
