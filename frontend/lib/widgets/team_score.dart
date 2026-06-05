// lib/widgets/team_score.dart
//
// Faithful to the mockup:
//   • Team name label sits ABOVE the pill, in its team colour
//   • The pill contains ONLY the large score number
//   • Number colour: warm tan Color(0xFFC8956C) — matches mockup
//   • Pill background: dark Color(0xFF15281A)
//   • Pill border: team colour, full opacity, 2px, StadiumBorder
//   • Pill is landscape (wide, short) via horizontal padding

import 'package:flutter/material.dart';

class TeamScore extends StatelessWidget {
  final String teamName;
  final int score;
  final Color teamColor;

  const TeamScore({
    super.key,
    required this.teamName,
    required this.score,
    required this.teamColor,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      // Team name above the pill, left-aligned with it
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // ── Team name label ──────────────────────────────────
        // Small caps, team colour, sits directly above the pill.
        Text(
          teamName.toUpperCase(),
          style: TextStyle(
            color: teamColor,
            fontSize: 12,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.8,
          ),
        ),

        const SizedBox(height: 4),

        // ── Score pill ───────────────────────────────────────
        // Wide landscape pill containing only the score number.
        // StadiumBorder gives fully rounded ends exactly like
        // the mockup shows.
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: 24,
            vertical: 8,
          ),
          decoration: BoxDecoration(
            color: const Color(0xFF15281A),
            borderRadius: BorderRadius.circular(40), // StadiumBorder equivalent
            border: Border.all(color: teamColor, width: 2),
          ),
          child: Text(
            '$score',
            style: const TextStyle(
              // Warm tan/brown matching the mockup number colour
              color: Color(0xFFC8956C),
              fontSize: 32,
              fontWeight: FontWeight.w900,
              height: 1.0,
            ),
          ),
        ),
      ],
    );
  }
}
