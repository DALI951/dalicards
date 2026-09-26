import 'package:flutter/material.dart';

import 'theme.dart';
import 'ui/hub/hub_screen.dart';

void main() {
  runApp(const DaliCardsApp());
}

class DaliCardsApp extends StatelessWidget {
  const DaliCardsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'DaliCards',
      debugShowCheckedModeBanner: false,
      theme: buildDarkTheme(),
      home: const HubScreen(),
    );
  }
}
