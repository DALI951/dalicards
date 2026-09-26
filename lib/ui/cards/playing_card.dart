import 'dart:math' as math;

import 'package:dalicards/theme.dart';
import 'package:engine/engine.dart';
// Flutter ships its own `Card` widget. Hide it so `Card` unambiguously means the
// engine's playing card in this file.
import 'package:flutter/material.dart' hide Card;

/// Card surface colours, kept next to the theme so the table and the theme can
/// never disagree.
class CardSkin {
  const CardSkin._();

  static const face = Color(0xFFF4F5F8);
  static const faceEdge = Color(0xFFC9CDD6);
  static const ink = Color(0xFF14161C);
  static const red = AppColors.cardRed;

  static const backTop = Color(0xFF2A2F3A);
  static const backBottom = Color(0xFF14161C);
}

/// Width / height of a playing card. 2.5in x 3.5in is the real thing.
const double cardAspect = 5 / 7;

/// Draws a suit glyph as a vector path in a 100x100 box, then scales it.
///
/// Deliberately not the Unicode characters ♠♥♦♣: those depend on the font
/// actually shipping the glyph, and a missing one is a tofu box in the middle of
/// a game rather than an error anyone can trace.
class SuitPainter extends CustomPainter {
  const SuitPainter({
    required this.suit,
    required this.color,
    this.joker = false,
  });

  final Suit suit;
  final Color color;

  /// A joker has no real suit, so it gets a star instead of pretending.
  final bool joker;

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path();
    if (joker) {
      _star(path);
    } else {
      switch (suit) {
        case Suit.hearts:
          _heart(path);
        case Suit.diamonds:
          _diamond(path);
        case Suit.clubs:
          _club(path);
        case Suit.spades:
          _spade(path);
      }
    }
    canvas.save();
    canvas.scale(size.width / 100, size.height / 100);
    canvas.drawPath(path, Paint()..color = color);
    canvas.restore();
  }

  // Each path is authored in a 100x100 box, y downwards.

  static void _heart(Path p) {
    p.moveTo(50, 92);
    p.cubicTo(12, 64, 4, 45, 4, 33);
    p.cubicTo(4, 18, 15, 7, 29, 7);
    p.cubicTo(39, 7, 47, 12, 50, 20);
    p.cubicTo(53, 12, 61, 7, 71, 7);
    p.cubicTo(85, 7, 96, 18, 96, 33);
    p.cubicTo(96, 45, 88, 64, 50, 92);
    p.close();
  }

  static void _diamond(Path p) {
    p.moveTo(50, 3);
    p.lineTo(95, 50);
    p.lineTo(50, 97);
    p.lineTo(5, 50);
    p.close();
  }

  static void _club(Path p) {
    p.addOval(const Rect.fromLTWH(22, 6, 36, 36));
    p.addOval(const Rect.fromLTWH(42, 6, 36, 36));
    p.addOval(const Rect.fromLTWH(32, 32, 36, 36));
    p.moveTo(44, 58);
    p.lineTo(56, 58);
    p.lineTo(64, 97);
    p.lineTo(36, 97);
    p.close();
  }

  static void _spade(Path p) {
    p.moveTo(50, 8);
    p.cubicTo(88, 36, 96, 55, 96, 67);
    p.cubicTo(96, 82, 85, 93, 71, 93);
    p.cubicTo(61, 93, 53, 88, 50, 80);
    p.cubicTo(47, 88, 39, 93, 29, 93);
    p.cubicTo(15, 93, 4, 82, 4, 67);
    p.cubicTo(4, 55, 12, 36, 50, 8);
    p.close();
    p.moveTo(44, 76);
    p.lineTo(56, 76);
    p.lineTo(63, 97);
    p.lineTo(37, 97);
    p.close();
  }

  static void _star(Path p) {
    for (var i = 0; i < 10; i++) {
      final r = i.isEven ? 48.0 : 20.0;
      final a = -math.pi / 2 + i * math.pi / 5;
      final x = 50 + r * math.cos(a);
      final y = 50 + r * math.sin(a);
      if (i == 0) {
        p.moveTo(x, y);
      } else {
        p.lineTo(x, y);
      }
    }
    p.close();
  }

  @override
  bool shouldRepaint(SuitPainter old) =>
      old.suit != suit || old.color != color || old.joker != joker;
}

/// One playing card, face up or face down.
///
/// [width] drives everything else, so the same widget is a big card in a hand
/// and a small one in a captured column.
class PlayingCard extends StatelessWidget {
  const PlayingCard({
    super.key,
    required this.width,
    this.card,
    this.faceDown = false,
    this.selected = false,
    this.dimmed = false,
    this.showValue = false,
    this.onTap,
  });

  /// A null [card] renders a face-down card, which is how a bot's hand - and a
  /// hotseat opponent you are not meant to peek at - is shown.
  final Card? card;

  final double width;
  final bool faceDown;
  final bool selected;
  final bool dimmed;

  /// Shows the capture value in a corner pill. Chkobba needs it: the shipped
  /// variant values J=8 Q=9 K=10 while the other widespread table plays J=9 Q=8,
  /// so the letter on its own is not enough to play by.
  final bool showValue;

  final VoidCallback? onTap;

  double get height => width / cardAspect;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(width * 0.11);
    final face = faceDown || card == null
        ? _CardBack(width: width, height: height, radius: radius)
        : _CardFace(
            card: card!,
            width: width,
            height: height,
            radius: radius,
            showValue: showValue,
          );

    Widget child = face;
    if (onTap != null) {
      child = GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: child,
      );
    }

    return Opacity(
      opacity: dimmed ? 0.45 : 1,
      // The glow lives outside the slide so the selection ring stays put while
      // the card lifts, which is what makes the lift read as "picked up".
      child: Container(
        decoration: BoxDecoration(
          borderRadius: radius,
          boxShadow: selected
              ? const [
                  BoxShadow(
                    color: AppColors.acc,
                    blurRadius: 14,
                    spreadRadius: 1,
                  ),
                ]
              : null,
        ),
        child: AnimatedSlide(
          offset: selected ? const Offset(0, -0.13) : Offset.zero,
          duration: const Duration(milliseconds: 140),
          child: child,
        ),
      ),
    );
  }
}

class _CardBack extends StatelessWidget {
  const _CardBack({
    required this.width,
    required this.height,
    required this.radius,
  });

  final double width;
  final double height;
  final BorderRadius radius;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        borderRadius: radius,
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [CardSkin.backTop, CardSkin.backBottom],
        ),
        border: Border.all(color: AppColors.line),
      ),
      alignment: Alignment.center,
      child: SizedBox(
        width: width * 0.40,
        height: width * 0.40,
        child: const CustomPaint(
          painter: SuitPainter(suit: Suit.diamonds, color: AppColors.acc),
        ),
      ),
    );
  }
}

class _CardFace extends StatelessWidget {
  const _CardFace({
    required this.card,
    required this.width,
    required this.height,
    required this.radius,
    required this.showValue,
  });

  final Card card;
  final double width;
  final double height;
  final BorderRadius radius;
  final bool showValue;

  bool get _isRed =>
      card.joker || card.suit == Suit.hearts || card.suit == Suit.diamonds;

  String get _rankLabel {
    if (card.joker) return 'JK';
    return switch (card.rank) {
      Rank.ace => 'A',
      Rank.two => '2',
      Rank.three => '3',
      Rank.four => '4',
      Rank.five => '5',
      Rank.six => '6',
      Rank.seven => '7',
      Rank.jack => 'J',
      Rank.queen => 'Q',
      Rank.king => 'K',
      Rank.eight => '8',
      Rank.nine => '9',
      Rank.ten => 'T',
    };
  }

  @override
  Widget build(BuildContext context) {
    final ink = _isRed ? CardSkin.red : CardSkin.ink;
    final rankSize = (width * 0.30).clamp(9.0, 22.0);
    final pip = width * 0.20;

    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: CardSkin.face,
        borderRadius: radius,
        border: Border.all(color: CardSkin.faceEdge),
      ),
      child: Stack(
        children: [
          // Big centre pip, nudged down so it never collides with the corner.
          Positioned.fill(
            child: Padding(
              padding: EdgeInsets.only(top: height * 0.18),
              child: Center(
                child: SizedBox(
                  width: width * 0.44,
                  height: width * 0.44,
                  child: CustomPaint(
                    painter: SuitPainter(
                      suit: card.suit,
                      color: ink,
                      joker: card.joker,
                    ),
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            left: width * 0.07,
            top: height * 0.03,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _rankLabel,
                  style: TextStyle(
                    color: ink,
                    fontSize: rankSize,
                    fontWeight: FontWeight.w900,
                    height: 1,
                  ),
                ),
                SizedBox(
                  width: pip,
                  height: pip,
                  child: CustomPaint(
                    painter: SuitPainter(
                      suit: card.suit,
                      color: ink,
                      joker: card.joker,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (showValue)
            Positioned(
              right: width * 0.07,
              top: height * 0.03,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                decoration: BoxDecoration(
                  color: ink,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  '${FaceValues.tunisian.value(card.rank)}',
                  style: TextStyle(
                    color: CardSkin.face,
                    fontSize: (width * 0.20).clamp(8.0, 14.0),
                    fontWeight: FontWeight.w900,
                    height: 1,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
