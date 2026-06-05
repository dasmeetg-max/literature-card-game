// lib/widgets/playing_card.dart
import 'package:flutter/material.dart';

class PlayingCard extends StatelessWidget {
  final String rank;
  final String suit;
  final Color color;
  final double size;
  final double rightMargin;

  const PlayingCard({
    required this.rank,
    required this.suit,
    required this.color,
    this.size = 1.0,
    this.rightMargin = 6.0,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 80 * size,
      height: 120 * size,
      margin: EdgeInsets.only(right: rightMargin),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8 * size),
        border: Border.all(color: Colors.black12, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 4 * size,
            offset: Offset(2 * size, 2 * size),
          ),
        ],
      ),
      // THE FIX: Use a Stack to layer the corner text and the center graphic
      child: Stack(
        children: [
          // 1. Top-Left Corner Index (Visible in the fan)
          Positioned(
            top: 4 * size,
            left: 6 * size,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  rank,
                  style: TextStyle(
                    fontSize: 14 * size, // Small font for the corner
                    fontWeight: FontWeight.bold,
                    color: color,
                    height: 1.0, // Tighten vertical space
                  ),
                ),
                Text(
                  suit,
                  style: TextStyle(
                    fontSize: 14 * size, // Small font for the corner
                    color: color,
                    height: 1.0,
                  ),
                ),
              ],
            ),
          ),

          // 2. Center Graphic (Reduced size to stay hidden behind overlaps)
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  rank,
                  style: TextStyle(
                    fontSize: 18 * size, // Reduced from 24
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
                Text(
                  suit,
                  style: TextStyle(
                    fontSize: 24 * size, // Reduced from 32
                    color: color,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
