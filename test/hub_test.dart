import 'package:dalicards/games/registry.dart';
import 'package:dalicards/l10n/app_strings.dart';
import 'package:dalicards/main.dart';
import 'package:dalicards/ui/game/table_screen.dart';
import 'package:dalicards/ui/hub/hub_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('hub', () {
    testWidgets('lists every registered game and the online actions',
        (tester) async {
      await tester.pumpWidget(const DaliCardsApp());
      await tester.pumpAndSettle();

      expect(find.text('DaliCards'), findsOneWidget);
      // SectionLabel renders small-caps, so the widget text is already upper.
      expect(find.text('PICK A GAME'), findsOneWidget);

      for (final game in GameRegistry.all) {
        expect(find.text(game.name.en), findsOneWidget);
      }
      expect(find.text('Chkobba'), findsOneWidget);
      expect(find.text('Rami'), findsOneWidget);
      expect(find.text('Belote'), findsOneWidget);

      expect(find.text('Create a table'), findsOneWidget);
      expect(find.text('Add a friend'), findsOneWidget);
    });

    testWidgets('honest status: nothing is playable yet, two are building',
        (tester) async {
      await tester.pumpWidget(const DaliCardsApp());
      await tester.pumpAndSettle();

      expect(find.text('BUILDING'), findsNWidgets(2));
      expect(find.text('PLANNED'), findsOneWidget);
      expect(find.text('PLAYABLE'), findsNothing);
    });

    testWidgets('tapping Chkobba opens its table, and back returns',
        (tester) async {
      await tester.pumpWidget(const DaliCardsApp());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Chkobba'));
      await tester.pumpAndSettle();

      expect(find.byType(TableScreen), findsOneWidget);
      expect(find.text('Rules engine ready'), findsOneWidget);
      expect(find.text('M4'), findsOneWidget);
      // The table screen is its own route, so the hub is gone.
      expect(find.byType(HubScreen), findsNothing);

      await tester.tap(find.text('Back to games'));
      await tester.pumpAndSettle();
      expect(find.byType(HubScreen), findsOneWidget);
    });

    testWidgets('tapping Rami opens the Rami table', (tester) async {
      await tester.pumpWidget(const DaliCardsApp());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Rami'));
      await tester.pumpAndSettle();

      expect(find.text('M5'), findsOneWidget);
      expect(find.text('Melds, jokers, and a 51-point opening'), findsOneWidget);
    });

    testWidgets('a planned game refuses to open', (tester) async {
      await tester.pumpWidget(const DaliCardsApp());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Belote'));
      await tester.pumpAndSettle();

      expect(find.byType(TableScreen), findsNothing);
      expect(find.textContaining('not built yet'), findsOneWidget);
    });

    testWidgets('the brand accent is the only red in the app', (tester) async {
      await tester.pumpWidget(const DaliCardsApp());
      await tester.pumpAndSettle();

      final context = tester.element(find.text('DaliCards'));
      final scheme = Theme.of(context).colorScheme;
      expect(scheme.primary, const Color(0xFFDC2626));
    });
  });

  group('languages', () {
    testWidgets('Arabic renders and mirrors the whole screen',
        (tester) async {
      tester.view.physicalSize = const Size(412, 915);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        const DaliCardsApp(initialLocale: AppLocales.arabic),
      );
      await tester.pumpAndSettle();

      // RTL comes from the MaterialApp locale, not from us guessing.
      expect(
        Directionality.of(tester.element(find.text('DaliCards'))),
        TextDirection.rtl,
      );
      expect(find.text('اختر لعبة'), findsOneWidget);
      expect(find.textContaining('العب ضد بوت'), findsOneWidget);
      expect(find.text('أنشئ طاولة'), findsOneWidget);
      expect(find.text('قيد الإنشاء'), findsNWidgets(2));
      expect(find.text('مخططة'), findsOneWidget);
    });

    testWidgets('the chevron points the way the language reads',
        (tester) async {
      // Tall on purpose: the English hero is longer than the Arabic one, so a
      // phone-sized viewport can leave the tiles below the fold and a ListView
      // will not have built them.
      tester.view.physicalSize = const Size(412, 1800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(const DaliCardsApp());
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.chevron_right_rounded), findsNWidgets(2));
      expect(find.byIcon(Icons.chevron_left_rounded), findsNothing);

      await tester.pumpWidget(
        const DaliCardsApp(initialLocale: AppLocales.arabic),
      );
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.chevron_left_rounded), findsNWidgets(2));
      expect(find.byIcon(Icons.chevron_right_rounded), findsNothing);
    });

    testWidgets('French translates the shell', (tester) async {
      await tester.pumpWidget(
        const DaliCardsApp(initialLocale: AppLocales.french),
      );
      await tester.pumpAndSettle();

      expect(
        Directionality.of(tester.element(find.text('DaliCards'))),
        TextDirection.ltr,
      );
      // SectionLabel upper-cases, so the label is shouted in French too.
      expect(find.text('CHOISIS UN JEU'), findsOneWidget);
      expect(find.text('Créer une table'), findsOneWidget);
      expect(find.text('Ajouter un ami'), findsOneWidget);
      expect(find.text('EN COURS'), findsNWidgets(2));
    });

    testWidgets('the language menu switches the running app', (tester) async {
      await tester.pumpWidget(const DaliCardsApp());
      await tester.pumpAndSettle();
      expect(find.text('Create a table'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.language_rounded));
      await tester.pumpAndSettle();
      expect(find.text('العربية'), findsOneWidget);

      await tester.tap(find.text('العربية'));
      await tester.pumpAndSettle();

      expect(find.text('أنشئ طاولة'), findsOneWidget);
      expect(find.text('Create a table'), findsNothing);
      expect(
        Directionality.of(tester.element(find.text('DaliCards'))),
        TextDirection.rtl,
      );
    });

    test('every locale has all three languages filled in', () {
      for (final game in GameRegistry.all) {
        for (final text in [game.name, game.tagline, game.players]) {
          for (final locale in AppLocales.supported) {
            expect(text.of(locale).trim(), isNotEmpty,
                reason: '${game.id} is empty in $locale');
          }
        }
      }
    });

    test('?lang= is read, and an unknown or missing code is harmless', () {
      expect(AppLocales.fromQuery(), isNull);
      expect(AppLocales.byCode('zz'), AppLocales.english);
      expect(AppLocales.byCode('ar'), AppLocales.arabic);
      expect(AppLocales.byCode('fr'), AppLocales.french);
    });
  });

  group('responsive', () {
    testWidgets('phone width lays out without overflow', (tester) async {
      tester.view.physicalSize = const Size(360, 740);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(const DaliCardsApp());
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.byType(HubScreen), findsOneWidget);
    });

    testWidgets('desktop width keeps the content column centred',
        (tester) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(const DaliCardsApp());
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      // The hero is inside a 720-wide box, so it cannot span a 1440 screen.
      final hero = tester.getRect(find.text('Tunisian card games'));
      expect(hero.left, greaterThan(0));
      expect(hero.right, lessThan(1440));
    });

    testWidgets('a long Arabic word does not overflow on a small phone',
        (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        const DaliCardsApp(initialLocale: AppLocales.arabic),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  });
}
