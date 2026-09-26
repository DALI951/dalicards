import 'package:dalicards/games/registry.dart';
import 'package:dalicards/l10n/app_strings.dart';
import 'package:dalicards/theme.dart';
import 'package:dalicards/ui/hub/hub_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

void main() {
  // `?lang=ar` wins over the default so a link can pick the language.
  runApp(DaliCardsApp(initialLocale: AppLocales.fromQuery()));
}

class DaliCardsApp extends StatefulWidget {
  const DaliCardsApp({super.key, this.initialLocale});

  /// Overrides the default English. Tests pass a locale to check a language
  /// without going through the URL.
  final Locale? initialLocale;

  @override
  State<DaliCardsApp> createState() => _DaliCardsAppState();
}

class _DaliCardsAppState extends State<DaliCardsApp> {
  final AppState _app = AppState();

  @override
  void initState() {
    super.initState();
    final start = widget.initialLocale;
    if (start != null) _app.locale = start;
  }

  @override
  void didUpdateWidget(DaliCardsApp oldWidget) {
    super.didUpdateWidget(oldWidget);
    // initState only runs once per State, so a new initialLocale on a rebuilt
    // root would otherwise be ignored and the app would keep the old language.
    // main() builds this widget exactly once with a constant, so in the real app
    // this never fires; it exists for tests that re-pump the root in another
    // language. Deferred to after the frame because notifying the Listenable
    // builder mid-build would mark a descendant dirty during the build phase.
    final next = widget.initialLocale;
    if (next != null && next != oldWidget.initialLocale) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _app.locale = next;
      });
    }
  }

  @override
  void dispose() {
    _app.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _app,
      builder: (context, _) {
        return AppScope(
          state: _app,
          child: MaterialApp(
            // The name is the same in every language, so no lookup needed.
            onGenerateTitle: (context) => 'DaliCards',
            debugShowCheckedModeBanner: false,
            theme: buildDarkTheme(),
            locale: _app.locale,
            supportedLocales: AppLocales.supported,
            localizationsDelegates: const [
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            // No '/' entry: `home` below already claims the initial route, and
            // having both is a Flutter assert.
            routes: GameRegistry.routes,
            home: const HubScreen(),
          ),
        );
      },
    );
  }
}
