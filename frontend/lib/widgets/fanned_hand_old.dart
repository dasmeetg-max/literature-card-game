// lib/widgets/fanned_hand.dart
//
// Fanned card hand — replaces TabbedHand.
//
// SORTING: Cards are sorted suit-first (♠ ♥ ♦ ♣), then by rank
// within each suit (A 2 3 4 5 6 8 9 10 J Q K), so the fan always
// presents a consistent, readable hand.
//
// FAN GEOMETRY:
//   Each card gets three transforms applied via a Positioned widget:
//     1. Horizontal offset — spreads cards across the width
//     2. Vertical offset   — outer cards drop lower (arc curve)
//     3. Rotation          — outer cards tilt, centre stays upright
//
// SELECTION:
//   Tapping a card toggles it. Selected card lifts by _liftAmount
//   and gets a white glow BoxShadow.

import 'dart:math';
import 'package:flutter/material.dart';
import 'playing_card.dart';

class FannedHand extends StatefulWidget {
  final List<Map<String, dynamic>> myHand;
  const FannedHand({super.key, required this.myHand});

  @override
  State<FannedHand> createState() => _FannedHandState();
}

class _FannedHandState extends State<FannedHand> {
  int? _selectedIndex;

  // ── Fan geometry constants ─────────────────────────────────────
  static const double _cardSpacing =
      36.0; // horizontal gap between card origins
  static const double _maxRotation =
      pi / 10; // max tilt of outermost card (~18°)
  static const double _arcDepth = 18.0; // how far outer cards drop (px)
  static const double _liftAmount = 18.0; // selected card rises by this much
  static const double _cardSize = 0.65;
  static const double _cardWidth = 80 * _cardSize; // 52 px
  static const double _cardHeight = 120 * _cardSize; // 78 px

  // ── Suit order ────────────────────────────────────────────────
  // ♠ ♥ ♦ ♣  — standard bridge suit order
  static const List<String> _suitOrder = ['♠', '♥', '♦', '♣'];

  // ── Rank order ─────────────────────────────────────────────────
  static int _rankValue(String rank) {
    switch (rank) {
      case 'A':
        return 1;
      case '2':
        return 2;
      case '3':
        return 3;
      case '4':
        return 4;
      case '5':
        return 5;
      case '6':
        return 6;
      case '8':
        return 8; // 7 is removed in Literature
      case '9':
        return 9;
      case '10':
        return 10;
      case 'J':
        return 11;
      case 'Q':
        return 12;
      case 'K':
        return 13;
      default:
        return 0;
    }
  }

  // ── Sort cards: suit-first, then rank within suit ──────────────
  List<Map<String, dynamic>> _sorted(List<Map<String, dynamic>> hand) {
    final copy = List<Map<String, dynamic>>.from(hand);
    copy.sort((a, b) {
      final suitA = _suitOrder.indexOf(a['suit'] as String);
      final suitB = _suitOrder.indexOf(b['suit'] as String);
      if (suitA != suitB) return suitA.compareTo(suitB);
      return _rankValue(a['rank'] as String)
          .compareTo(_rankValue(b['rank'] as String));
    });
    return copy;
  }

  @override
  Widget build(BuildContext context) {
    final cards = _sorted(widget.myHand);
    final n = cards.length;

    if (n == 0) {
      return const SizedBox(
        height: 90,
        child: Center(
          child: Text(
            'No cards in hand',
            style: TextStyle(color: Color(0xFF4A6E50), fontSize: 13),
          ),
        ),
      );
    }

    // Fan occupies (n-1) * spacing + one card width
    // final double fanWidth = (n - 1) * _cardSpacing + _cardWidth;
    double currentSpacing = _cardSpacing;
    double fanWidth = (n - 1) * currentSpacing + _cardWidth;
    final double availableWidth = MediaQuery.of(context).size.width - 32;
    if (fanWidth > availableWidth) {
      currentSpacing = (availableWidth - _cardWidth) / (n - 1);
      fanWidth = (n - 1) * currentSpacing + _cardWidth;
    }
    final double startX = (availableWidth - fanWidth) / 2;
    const double stackHeight = _cardHeight + _liftAmount + _arcDepth + 8;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: SizedBox(
        height: stackHeight,
        child: Stack(
          clipBehavior: Clip.none,
          children: List.generate(n, (i) {
            // normPos in [-1, 1]: 0 = centre card
            final double normPos = n == 1 ? 0.0 : (i / (n - 1)) * 2 - 1;

            final double rotation = normPos * _maxRotation;
            final double arcOffset = normPos.abs() * _arcDepth;
            final double xPos = startX + i * _cardSpacing;
            final bool isSelected = _selectedIndex == i;

            // Selected card lifts above the arc
            final double yPos =
                isSelected ? arcOffset - _liftAmount : arcOffset;

            final String suit = cards[i]['suit'] as String;
            final String rank = cards[i]['rank'] as String;
            final Color color =
                (suit == '♥' || suit == '♦') ? Colors.red : Colors.black;

            return Positioned(
              left: xPos,
              top: yPos,
              child: GestureDetector(
                onTap: () => setState(() {
                  _selectedIndex = isSelected ? null : i;
                }),
                child: Transform.rotate(
                  angle: rotation,
                  // Rotate around bottom-centre so all cards fan from
                  // the same point, like a real hand of cards
                  alignment: Alignment.bottomCenter,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    curve: Curves.easeOut,
                    decoration: isSelected
                        ? BoxDecoration(
                            borderRadius: BorderRadius.circular(8 * _cardSize),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.white.withValues(alpha: 0.55),
                                blurRadius: 10,
                                spreadRadius: 1,
                              ),
                            ],
                          )
                        : null,
                    child: PlayingCard(
                      rank: rank,
                      suit: suit,
                      color: color,
                      size: _cardSize,
                      rightMargin: 0,
                    ),
                  ),
                ),
              ),
            );
          }),
        ),
      ),
    );
  }
}
