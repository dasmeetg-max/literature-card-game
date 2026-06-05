// lib/widgets/unified_scoreboard.dart

import 'package:flutter/material.dart';

class UnifiedScoreboard extends StatelessWidget {
  final String teamAName;
  final int scoreA;
  final Color teamAColor;

  final String teamBName;
  final int scoreB;
  final Color teamBColor;

  final String roomCode;

  const UnifiedScoreboard({
    super.key,
    required this.teamAName,
    required this.scoreA,
    required this.teamAColor,
    required this.teamBName,
    required this.scoreB,
    required this.teamBColor,
    required this.roomCode,
  });

  @override
  Widget build(BuildContext context) {
    // Force solid colors for the text to ensure they don't inherit
    // any alpha values passed in accidentally from the parent screen.
    final solidTeamA = teamAColor.withValues(alpha: 1.0);
    final solidTeamB = teamBColor.withValues(alpha: 1.0);

    return Container(
      // Tightly constrained height and max width to clear the 3-dot menu
      height: 48,
      constraints: const BoxConstraints(maxWidth: 290),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(40),
        // 1. Hard 50/50 split of the team colors, heavily transparent
        gradient: LinearGradient(
          colors: [
            solidTeamA.withValues(alpha: 0.25),
            solidTeamA.withValues(alpha: 0.25),
            solidTeamB.withValues(alpha: 0.25),
            solidTeamB.withValues(alpha: 0.25),
          ],
          stops: const [0.0, 0.5, 0.5, 1.0],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        // 2. Contrasting border color (bright frosted white)
        border:
            Border.all(color: Colors.white.withValues(alpha: 0.6), width: 1.5),
        boxShadow: const [
          BoxShadow(
            color: Colors.black45,
            blurRadius: 8,
            offset: Offset(0, 4),
          )
        ],
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // ── Ambient Room Code (Pushed to the absolute top edge) ──
          Positioned(
            top: 2,
            child: Text(
              'ROOM: $roomCode',
              style: const TextStyle(
                color:
                    Colors.white70, // Lightened for the darker transparent bg
                fontSize: 8,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.0,
              ),
            ),
          ),

          // ── The Main Scoreboard Row (Dead center vertically) ──
          Padding(
            padding: const EdgeInsets.only(top: 2.0, left: 12, right: 12),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Team A Flank
                Text(
                  teamAName.toUpperCase(),
                  style: TextStyle(
                    color: solidTeamA, // Bright team color
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(width: 8),

                // Team A Score (3. Pure white, maximum boldness)
                Text(
                  '[ $scoreA ]',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    height: 1.0,
                  ),
                ),

                // A bit more space in the dead center since we removed the divider
                const SizedBox(width: 20),

                // Team B Score (3. Pure white, maximum boldness)
                Text(
                  '[ $scoreB ]',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    height: 1.0,
                  ),
                ),

                const SizedBox(width: 8),

                // Team B Flank
                Text(
                  teamBName.toUpperCase(),
                  style: TextStyle(
                    color: solidTeamB, // Bright team color
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
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
