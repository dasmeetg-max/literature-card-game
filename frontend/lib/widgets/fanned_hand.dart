// lib/widgets/fanned_hand.dart

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

  // ── Rotary State ──────────────────────────────────────────────
  double _scrollAngle = 0.0;

  // ── Geometry Constants ─────────────────────────────────────────
  static const double _cardSize = 0.65;
  static const double _cardWidth = 80 * _cardSize; // 52.0 px
  static const double _cardHeight = 120 * _cardSize; // 78.0 px
  static const double _liftAmount = 24.0;

  // ── Sorting Logic ─────────────────────────────────────────────
  static const List<String> _suitOrder = ['♠', '♥', '♦', '♣'];

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
        return 8;
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
  void didUpdateWidget(FannedHand oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_selectedIndex != null && _selectedIndex! >= widget.myHand.length) {
      _selectedIndex = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final cards = _sorted(widget.myHand);
    final n = cards.length;

    if (n == 0) {
      return const SizedBox(
        height: 160,
        child: Center(
          child: Text(
            'No cards in hand',
            style: TextStyle(color: Color(0xFF4A6E50), fontSize: 13),
          ),
        ),
      );
    }

    // THE FIX: Wrap the arc math and UI in a LayoutBuilder
    return LayoutBuilder(
      builder: (context, constraints) {
        // ── 1. Responsive Arc Calculations ──────────────────────────────
        // Use the parent constraint's width instead of the physical screen width
        final double availableWidth = constraints.maxWidth;

        final double dynamicRadius = availableWidth * 1.2;
        const double horizontalPadding = 32.0;
        final double safeWidth =
            availableWidth - _cardWidth - (_liftAmount * 2) - horizontalPadding;

        // Calculate the maximum angle the arc can spread without going off-screen.
        // Derived from chord length: 2 * radius * sin(theta/2) = chord
        final double ratio = (safeWidth / (2 * dynamicRadius)).clamp(0.0, 1.0);
        final double maxVisibleSpread = 2 * asin(ratio);

        // ── 2. Spacing & Scroll Logic (The 12-Card Threshold) ──────────
        const int maxVisibleCards = 12;

        // This is the tightest the cards are allowed to squeeze together.
        final double minAnglePerCard =
            maxVisibleSpread / max(1, maxVisibleCards - 1);

        // Cap the maximum spacing so small hands (e.g. 3 cards) don't look weirdly distant.
        const double maxAnglePerCard = 0.15;

        double idealSpacing = maxVisibleSpread / max(1, n - 1);
        double angleSpacing =
            idealSpacing.clamp(minAnglePerCard, maxAnglePerCard);

        double totalSpread = (n - 1) * angleSpacing;

        // Only allow scroll if the cards exceed the maximum visible spread.
        double maxScroll = max(0.0, (totalSpread - maxVisibleSpread) / 2);
        _scrollAngle = _scrollAngle.clamp(-maxScroll, maxScroll);

        // ── 3. Pivot Coordinates ────────────────────────────────────────
        final double pivotX = availableWidth / 2;

        // Set the peak of the arc. We want the top of the center card
        // to have room to lift without clipping the top of the Stack.
        const double topPadding = _liftAmount + 8.0;
        const double peakCenterY = topPadding + (_cardHeight / 2);

        // The pivot point for the invisible circle is directly below the peak.
        final double pivotY = peakCenterY + dynamicRadius;

        return GestureDetector(
          onPanUpdate: (details) {
            if (maxScroll > 0) {
              setState(() {
                _scrollAngle += details.delta.dx * 0.003;
                _scrollAngle = _scrollAngle.clamp(-maxScroll, maxScroll);
              });
            }
          },
          child: Container(
            color: Colors.transparent, // Ensures swipes register everywhere
            height: 160, // Fixed height to encapsulate the curve and lifts
            width: double.infinity,
            child: Stack(
              clipBehavior: Clip.none,
              children: List.generate(n, (i) {
                final bool isSelected = _selectedIndex == i;

                // Offset the card index so the middle card is at 0 radians
                double baseTheta = (i - (n - 1) / 2) * angleSpacing;
                double theta = baseTheta + _scrollAngle;

                // Lift expands the radius directly outward
                double currentRadius =
                    dynamicRadius + (isSelected ? _liftAmount : 0);

                // Calculate the position for the CENTER of the card
                double centerX = pivotX + currentRadius * sin(theta);
                double centerY = pivotY - currentRadius * cos(theta);

                // Shift top/left to account for card dimensions
                double left = centerX - (_cardWidth / 2);
                double top = centerY - (_cardHeight / 2);

                final String suit = cards[i]['suit'] as String;
                final String rank = cards[i]['rank'] as String;
                final Color color =
                    (suit == '♥' || suit == '♦') ? Colors.red : Colors.black;

                return Positioned(
                  left: left,
                  top: top,
                  child: GestureDetector(
                    onTap: () {
                      setState(() {
                        _selectedIndex = isSelected ? null : i;
                      });
                    },
                    // Crucial fix: Rotate around the CENTER of the card,
                    // which sits perfectly on the arc track.
                    child: Transform.rotate(
                      angle: theta,
                      alignment: Alignment.center,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        curve: Curves.easeOutBack,
                        decoration: isSelected
                            ? BoxDecoration(
                                borderRadius:
                                    BorderRadius.circular(8 * _cardSize),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.white.withValues(alpha: 0.6),
                                    blurRadius: 12,
                                    spreadRadius: 2,
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
      },
    );
  }
}
