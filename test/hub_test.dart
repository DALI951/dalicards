import 'package:dalicards/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('hub lists the games and the online actions', (tester) async {
    await tester.pumpWidget(const DaliCardsApp());
    await tester.pumpAndSettle();

    expect(find.text('DaliCards'), findsOneWidget);
    expect(find.text('Pick a game'), findsOneWidget);

    expect(find.text('Chkobba'), findsOneWidget);
    expect(find.text('Rami'), findsOneWidget);
    expect(find.text('Belote'), findsOneWidget);

    expect(find.text('Create a table'), findsOneWidget);
    expect(find.text('Add a friend'), findsOneWidget);
  });

  testWidgets('only Chkobba is unlocked so far', (tester) async {
    await tester.pumpWidget(const DaliCardsApp());
    await tester.pumpAndSettle();

    expect(find.text('BUILDING'), findsOneWidget);
    expect(find.text('PLANNED'), findsNWidgets(2));
    expect(find.text('PLAYABLE'), findsNothing);
  });

  testWidgets('the brand accent is the only red in the app', (tester) async {
    await tester.pumpWidget(const DaliCardsApp());
    await tester.pumpAndSettle();

    final context = tester.element(find.text('DaliCards'));
    final scheme = Theme.of(context).colorScheme;
    expect(scheme.primary, const Color(0xFFDC2626));
  });
}
