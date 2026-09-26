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

  String get heroTitle => _t('Tunisian card games', 'ألعاب الورق التونسية',
      'Jeux de cartes tunisiens');
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

  // -- chkobba: setup ------------------------------------------------------

  String get playChkobba =>
      _t('Play Chkobba', 'العب شكوببا', 'Jouer à Chkobba');
  String get vsBot => _t('Solo vs bot', 'العب ضد بوت', 'Solo contre un bot');
  String get hotseat => _t('Hotseat', 'مع نفس الجهاز', 'Sur le même appareil');
  String get hotseatBody => _t(
        'Two players, one phone. Pass it across the table - neither hand is '
            'ever shown.',
        'لاعبّين، هاتف واحد. مرّره فوق الطاولة، وما تتبناش يدك ولا يد صاحبتك.',
        'Deux joueurs, un téléphone. Passez-le - aucune main n\'est montrée.',
      );
  String get vsBotBody => _t(
        'You against a bot. Three levels, and it never sees a card you do not '
            'see either.',
        'أنت ضد بوت. ثلاث مستويات، وهو ما يشوفش كرte ما تشوفهاش إنت.',
        'Toi contre un bot. Trois niveaux, et il ne voit aucune carte que tu '
            'ne vois pas.',
      );
  String get botEasy => _t('Easy', 'ساهل', 'Facile');
  String get botNormal => _t('Normal', 'عادي', 'Normal');
  String get botHard => _t('Hard', 'صعيب', 'Difficile');
  String get botEasyBody => _t(
        'Plays 4 cards in 10 by hand.',
        'يلعب 4 من 10 على البالعقل.',
        'Joue 4 cartes sur 10 au hasard.',
      );
  String get botNormalBody => _t(
        'Always takes the biggest capture.',
        'ديما ياخذ أكبر التقاط.',
        'Prend toujours la plus grande capture.',
      );
  String get botHardBody => _t(
        'Looks one move ahead, so it will not leave you a one-card table.',
        'ينبّص حركة قدّام، فما يخليكش تبلّغ طاولة بقرط واحد.',
        'Regarde un coup plus loin, ne te laissera pas une table à une carte.',
      );
  String get houseRules =>
      _t('House rules', 'قواعد الطابلة', 'Règles de la table');
  String get houseRulesBody => _t(
        'Every table in Tunisia plays slightly differently. These are flags, '
            'not code.',
        'كل طابلة في تونس تلعب كيما تحب شويّة. هذي خيارات، ماشي كود.',
        'Chaque table joue un peu différemment. Ce sont des options, pas du '
            'code.',
      );
  String get faceValues => _t('Face cards', 'الكور besar', 'Figures');
  String get faceValuesDefault =>
      _t('J=8  Q=9  K=10', 'J=8  Q=9  K=10', 'J=8  Q=9  K=10');
  String get faceValuesSwapped =>
      _t('J=9  Q=8  K=10', 'J=9  Q=8  K=10', 'J=9  Q=8  K=10');
  String get targetScore =>
      _t('Target score', 'النقطة المطلوبة', 'Score cible');
  String get dealSize => _t('Cards a deal', 'كروت القسمة', 'Cartes par donne');
  String get singleBeatsSum => _t(
        'A single capture beats a sum',
        'القرط يسبق الجمع',
        'La capture simple bat la somme',
      );
  String get bestSumWins => _t(
        'You pick the best capture',
        'إنت تختار أحسن قرط',
        'Tu choisis la meilleure capture',
      );
  String get capturePriorityLabel =>
      _t('When both work', 'كيما في إماّك', 'Quand les deux marchent');
  String get startGame => _t('Deal the cards', 'اقسم الكروت', 'Distribuer');
  String get changeRules =>
      _t('Change rules', 'بدّل القواعد', 'Changer les règles');

  // -- chkobba: the table --------------------------------------------------

  String get yourTurn => _t('Your turn', 'دورك', 'Ton tour');
  String get botTurn => _t('Thinking', 'يفكّر', 'Il réfléchit');
  String get passThePhone =>
      _t('Pass the phone', 'مرّر الهاتف', 'Passez le téléphone');
  String get tablePile => _t('Table', 'الطابلة', 'La table');
  String get yourPile => _t('Your pile', 'كروتك المجموعة', 'Ta pile');
  String get hand => _t('Hand', 'الكروت', 'Main');
  String get stockLabel => _t('Stock', 'الباقي', 'Reste');
  String get captured => _t('Captured', 'مقروض', 'Capturé');
  String get chkobbas => _t('Chkobbas', 'شكوببات', 'Chkobbas');
  String get matchTotal => _t('Match', 'المجموع', 'Match');
  String get roundOver => _t('Round over', 'خلصت الجولة', 'Manche terminée');
  String get nextRound => _t('Next round', 'جولة أخرى', 'Manche suivante');
  String get newMatch => _t('New match', 'مباراة جديدة', 'Nouvelle partie');
  String get matchOver => _t('Match over', 'خلصت المباراة', 'Partie terminée');
  String get youWin => _t('You win!', 'إنت ربحت!', 'Tu gagnes !');
  String get youLose => _t('You lose', 'خسرت', 'Tu perds');
  String get playerOne => _t('Player 1', 'اللاعب 1', 'Joueur 1');
  String get playerTwo => _t('Player 2', 'اللاعب 2', 'Joueur 2');
  String get bot => _t('Bot', 'بوت', 'Bot');
  String get chooseCapture =>
      _t('Take which cards?', 'تاخذ أڨرط؟', 'Tu prends quoi ?');
  String get takeNothing => _t('No capture', 'بلا قرط', 'Sans capture');
  String get cancel => _t('Cancel', 'بلاش', 'Annuler');
  String get emptyTable =>
      _t('The table is empty', 'الطابلة فارغة', 'La table est vide');
  String get dealAgain =>
      _t('Dealing again', 'ناقسم من جديد', 'Nouvelle donne');
  String get playedOnTable =>
      _t('left on the table', 'تركها على الطاولة', 'laissée sur la table');
  String get tookCards => _t('took', 'اخذ', 'a pris');

  /// The shout. Tunisian transliteration on purpose - this is the one string in
  /// the app that has to sound like the table, not like a menu.
  String get chkobbaShout => 'CHKOBBAAA!';
  String get chkobbaShoutAr => 'شكوببا!';
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
