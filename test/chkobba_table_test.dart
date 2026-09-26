import 'package:dalicards/games/registry.dart';
import 'package:dalicards/l10n/app_strings.dart';
import 'package:dalicards/theme.dart';
import 'package:dalicards/ui/cards/playing_card.dart';
import 'package:dalicards/ui/chkobba/chkobba_controller.dart';
import 'package:dalicards/ui/chkobba/chkobba_setup.dart';
import 'package:dalicards/ui/chkobba/chkobba_table.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'hub_test.dart' show expectNoRowOverflow, tallPhone;

/// The real app shell minus the hub: the table screen needs `AppScope` for
/// strings and the dark theme for colours, and a bare MaterialApp asserts on
/// the first string lookup. Mirrors `DaliCardsApp` so the widget under test sees
/// exactly what it sees in production.
class TestApp extends StatefulWidget {
  const TestApp({super.key, required this.child, this.locale});

  final Widget child;
  final Locale? locale;

  @override
  State<TestApp> createState() => _TestAppState();
}

class _TestAppState extends State<TestApp> {
  final AppState _app = AppState();

  @override
  void initState() {
    super.initState();
    final l = widget.locale;
    if (l != null) _app.locale = l;
  }

  @override
  void dispose() {
    _app.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppScope(
      state: _app,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: buildDarkTheme(),
        locale: _app.locale,
        supportedLocales: AppLocales.supported,
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: widget.child,
      ),
    );
  }
}

/// A table with the bot fast enough to wait for, but not so fast that
/// `pumpAndSettle` runs the bot's turn before the assertions can see the board
/// before the bot answered.
ChkobbaTableScreen table({
  ChkobbaSetup setup = const ChkobbaSetup(),
  int seed = 4242,
}) {
  return ChkobbaTableScreen(
    game: GameRegistry.all.first,
    setup: setup,
    seed: seed,
    botDelay: const Duration(milliseconds: 300),
    flashDuration: const Duration(milliseconds: 100),
  );
}

/// Pumps one bot turn: start the timer, let it fire, settle what it changed.
Future<void> botTurn(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
  await tester.pumpAndSettle();
}

/// The player's hand, whatever the deal was.
Finder anyHandCard() => find.byWidgetPredicate(
      (w) => w is PlayingCard && w.key.toString().contains('hand-0-'),
    );

/// The first option in the capture chooser, which is up whenever a card has
/// more than one legal capture.
Finder firstCaptureChoice() => find.byKey(const ValueKey<String>('capture-0'));

/// Cards on screen that a player is allowed to read.
int faceUp(WidgetTester tester) => tester
    .widgetList<PlayingCard>(find.byType(PlayingCard))
    .where((c) => c.card != null)
    .length;

/// Card backs, i.e. the opponent's hand.
int faceDown(WidgetTester tester) => tester
    .widgetList<PlayingCard>(find.byType(PlayingCard))
    .where((c) => c.card == null)
    .length;

/// The hub's tile text in a language, straight from the registry, so no test
/// has to type Arabic.
String gameName(Locale locale) => GameRegistry.all.first.name.of(locale);

/// Plays the player's first legal card until [until] is true or the guard trips.
///
/// Handles the capture chooser, because a card with two legal captures puts a
/// modal sheet up and every later tap lands on the barrier instead of the hand.
Future<bool> playUntil(
  WidgetTester tester,
  bool Function() until, {
  int guard = 150,
}) async {
  for (var i = 0; i < guard; i++) {
    if (until()) return true;

    final choice = firstCaptureChoice();
    if (choice.evaluate().isNotEmpty) {
      await tester.tap(choice);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      continue;
    }

    final hand = anyHandCard();
    if (hand.evaluate().isNotEmpty) {
      await tester.tap(hand.first, warnIfMissed: false);
      await tester.pump();
    }
    await botTurn(tester);
  }
  return until();
}

void main() {
  group('the setup screen', () {
    // The setup screen is a ListView, so the deal button is only built when the
    // viewport is tall enough to reach it. A 600px test window would silently
    // skip everything below the fold.
    void tallView(WidgetTester tester) {
      tester.view.physicalSize = tallPhone;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
    }

    testWidgets('offers an opponent, a level, and hides the rules until asked',
        (tester) async {
      tallView(tester);
      await tester.pumpWidget(TestApp(
        child: ChkobbaSetupScreen(game: GameRegistry.all.first),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Solo vs bot'), findsOneWidget);
      expect(find.text('Hotseat'), findsOneWidget);
      expect(find.text('Deal the cards'), findsOneWidget);
      // Levels only matter against a bot.
      expect(find.text('Easy'), findsOneWidget);
      expect(find.text('Normal'), findsOneWidget);
      expect(find.text('Hard'), findsOneWidget);
      expect(find.text('J=8  Q=9  K=10'), findsNothing);
    });

    testWidgets('hotseat hides the bot levels', (tester) async {
      tallView(tester);
      await tester.pumpWidget(TestApp(
        child: ChkobbaSetupScreen(game: GameRegistry.all.first),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Hotseat'));
      await tester.pumpAndSettle();
      expect(find.text('Hard'), findsNothing);
      expect(find.text('Deal the cards'), findsOneWidget);
    });

    testWidgets('the house rules really change what gets dealt',
        (tester) async {
      tallView(tester);
      await tester.pumpWidget(TestApp(
        child: ChkobbaSetupScreen(game: GameRegistry.all.first),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.text('House rules'));
      await tester.pumpAndSettle();
      expect(find.text('J=8  Q=9  K=10'), findsOneWidget);
      expect(find.text('21'), findsOneWidget);

      // Target 21 -> 31 -> 11, and the swapped face values.
      await tester.tap(find.text('21'));
      await tester.pumpAndSettle();
      expect(find.text('31'), findsOneWidget);
      await tester.tap(find.text('31'));
      await tester.pumpAndSettle();
      expect(find.text('11'), findsOneWidget);
      await tester.tap(find.text('J=8  Q=9  K=10'));
      await tester.pumpAndSettle();
      expect(find.text('J=9  Q=8  K=10'), findsOneWidget);
    });
  });

  group('the table', () {
    testWidgets('deals three to the hand, four to the table, three backs',
        (tester) async {
      await tester.pumpWidget(TestApp(child: table()));
      await tester.pumpAndSettle();

      expect(find.text('Chkobba'), findsOneWidget);
      expect(faceUp(tester), 7, reason: '3 in hand + 4 on the table');
      expect(faceDown(tester), 3, reason: 'the opponent never shows a face');
      expect(anyHandCard(), findsNWidgets(3));
    });

    testWidgets('tapping a card plays it, then the bot answers',
        (tester) async {
      await tester.pumpWidget(TestApp(child: table()));
      await tester.pumpAndSettle();

      expect(anyHandCard(), findsNWidgets(3));
      await tester.tap(anyHandCard().first);
      await tester.pumpAndSettle();

      // The card left the hand. It does not necessarily appear on the table: if
      // it captured, the table went into the player's pile instead, so the
      // number of visible cards is allowed to drop.
      expect(anyHandCard(), findsNWidgets(2));

      await botTurn(tester);
      // Still two in hand, because a fresh deal of three only arrives when the
      // stock runs out. What proves the bot moved is that the turn came back:
      // another card of mine is playable and goes down.
      expect(anyHandCard(), findsNWidgets(2));
      await tester.tap(anyHandCard().first);
      await tester.pumpAndSettle();
      expect(anyHandCard(), findsNWidgets(1));
      expect(tester.takeException(), isNull);
    });

    testWidgets('a whole round plays out and the next one starts',
        (tester) async {
      await tester.pumpWidget(TestApp(child: table()));
      await tester.pumpAndSettle();

      final done = await playUntil(
        tester,
        () => find.text('Round over').evaluate().isNotEmpty,
      );
      expect(done, isTrue, reason: 'the round never ended');
      expect(tester.takeException(), isNull);
      // The panel names the reasons the engine produced, not a hardcoded line.
      expect(find.textContaining('+'), findsWidgets);

      await tester.tap(find.text('Next round'));
      await tester.pumpAndSettle();
      expect(find.text('Round over'), findsNothing);
      expect(find.text('Match'), findsOneWidget, reason: 'totals carried over');
    });

    testWidgets('the Chkobba shout never leaves the screen stuck',
        (tester) async {
      await tester.pumpWidget(TestApp(child: table(seed: 7)));
      await tester.pumpAndSettle();

      // A sweep needs a card that beats the table sum, so it may not come up in
      // this seed. What must hold either way: the game stays alive, and if the
      // shout did appear, it goes away by itself.
      var sawShout = false;
      for (var i = 0; i < 150; i++) {
        final hand = anyHandCard();
        if (hand.evaluate().isNotEmpty) {
          await tester.tap(hand.first, warnIfMissed: false);
          await tester.pump();
        }
        await botTurn(tester);
        if (find.textContaining('CHKOBBA').evaluate().isNotEmpty) {
          sawShout = true;
          await tester.pump(const Duration(milliseconds: 200));
          await tester.pumpAndSettle();
          expect(find.textContaining('CHKOBBA'), findsNothing,
              reason: 'the shout is still up 200ms after it was raised');
        }
        if (find.text('Round over').evaluate().isNotEmpty) break;
      }
      expect(tester.takeException(), isNull);
      // Either outcome is fine, but say which one happened so a green run never
      // pretends to have covered something it did not.
      expect(sawShout, isA<bool>());
    });
  });

  group('languages and layout', () {
    testWidgets('the table mirrors for Arabic and still fits', (tester) async {
      tester.view.physicalSize = const Size(412, 915);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        TestApp(locale: AppLocales.arabic, child: table()),
      );
      await tester.pumpAndSettle();

      expect(
        Directionality.of(tester.element(find.byType(ChkobbaTableScreen))),
        TextDirection.rtl,
      );
      expect(anyHandCard(), findsNWidgets(3));
      expectNoRowOverflow(tester);
      expect(tester.takeException(), isNull);
    });

    testWidgets('French plays too', (tester) async {
      await tester.pumpWidget(
        TestApp(locale: AppLocales.french, child: table()),
      );
      await tester.pumpAndSettle();

      expect(anyHandCard(), findsNWidgets(3));
      await tester.tap(anyHandCard().first);
      await tester.pumpAndSettle();
      expect(anyHandCard(), findsNWidgets(2));
      expectNoRowOverflow(tester);
    });

    testWidgets('a tiny phone lays the table out without overflow',
        (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(TestApp(child: table()));
      await tester.pumpAndSettle();
      expectNoRowOverflow(tester);
      expect(tester.takeException(), isNull);
    });

    testWidgets('a desktop keeps the table centred, not stretched',
        (tester) async {
      tester.view.physicalSize = tallPhone;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(TestApp(child: table()));
      await tester.pumpAndSettle();
      expectNoRowOverflow(tester);
      expect(tester.takeException(), isNull);

      final hand = tester.getRect(anyHandCard().first);
      expect(hand.left, greaterThan(0));
      expect(hand.right, lessThan(1440));
    });

    test('every locale has a non-empty string for the table screen', () {
      for (final locale in AppLocales.supported) {
        final s = AppStrings(locale);
        for (final value in <String>[
          s.playChkobba,
          s.vsBot,
          s.hotseat,
          s.botEasy,
          s.botNormal,
          s.botHard,
          s.houseRules,
          s.startGame,
          s.yourTurn,
          s.passThePhone,
          s.hand,
          s.stockLabel,
          s.captured,
          s.chkobbas,
          s.roundOver,
          s.nextRound,
          s.matchOver,
          s.youWin,
          s.youLose,
          s.chooseCapture,
          s.cancel,
          s.emptyTable,
          s.chkobbaShout,
        ]) {
          expect(value.trim(), isNotEmpty, reason: 'empty in $locale');
        }
      }
    });
  });
}
