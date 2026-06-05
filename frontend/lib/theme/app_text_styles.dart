// lib/theme/app_text_styles.dart
//
// Centralised text styles for the Literature app.
// Every screen imports this file instead of writing
// TextStyle(...) inline — making font changes a one-liner.

import 'package:flutter/material.dart';
import 'app_colors.dart';

class AppTextStyles {
  AppTextStyles._();

  // ── Display / Hero text ────────────────────────────────────────

  /// "LITERATURE" — the big logo in the top bar
  static const TextStyle logo = TextStyle(
    fontFamily: 'Poppins',       // add to pubspec.yaml (see note below)
    fontSize: 20,
    fontWeight: FontWeight.w800,
    letterSpacing: 2.0,
    color: AppColors.peach,
  );

  /// "READY TO FISH?" hero headline on home screen
  static const TextStyle hero = TextStyle(
    fontFamily: 'Poppins',
    fontSize: 28,
    fontWeight: FontWeight.w800,
    letterSpacing: 1.5,
    color: AppColors.textPrimary,
    height: 1.2,
  );

  /// Large italic italic word like "FISH?" in the hero
  static const TextStyle heroAccent = TextStyle(
    fontFamily: 'Poppins',
    fontSize: 28,
    fontWeight: FontWeight.w800,
    fontStyle: FontStyle.italic,
    letterSpacing: 1.5,
    color: AppColors.peach,
    height: 1.2,
  );

  // ── Section headings ───────────────────────────────────────────

  /// "TEAM A", "TEAM B" — team name labels in the lobby
  static const TextStyle teamHeading = TextStyle(
    fontFamily: 'Poppins',
    fontSize: 20,
    fontWeight: FontWeight.w800,
    letterSpacing: 1.5,
    color: AppColors.teamA,       // caller can override via .copyWith
  );

  /// "3 / 4 PLAYERS" — small pill next to team heading
  static const TextStyle playerCount = TextStyle(
    fontFamily: 'Poppins',
    fontSize: 12,
    fontWeight: FontWeight.w600,
    letterSpacing: 1.0,
    color: AppColors.textSecondary,
  );

  // ── Body / Labels ──────────────────────────────────────────────

  /// Player name inside a slot row — e.g. "Alex"
  static const TextStyle playerName = TextStyle(
    fontFamily: 'Poppins',
    fontSize: 16,
    fontWeight: FontWeight.w700,
    color: AppColors.textPrimary,
  );

  /// Status tag under a player name — "READY" or "WAITING..."
  static const TextStyle statusLabel = TextStyle(
    fontFamily: 'Poppins',
    fontSize: 12,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.8,
    color: AppColors.statusReady,   // caller overrides for waiting state
  );

  /// "ROOM CODE" small caps label above the code
  static const TextStyle roomCodeLabel = TextStyle(
    fontFamily: 'Poppins',
    fontSize: 11,
    fontWeight: FontWeight.w600,
    letterSpacing: 2.0,
    color: AppColors.textSecondary,
  );

  /// The actual room code — e.g. "J2K8"
  static const TextStyle roomCode = TextStyle(
    fontFamily: 'Poppins',
    fontSize: 36,
    fontWeight: FontWeight.w800,
    letterSpacing: 6.0,
    color: AppColors.peach,
  );

  /// Button labels — used for "Host Game", "Join Game", "START GAME"
  static const TextStyle button = TextStyle(
    fontFamily: 'Poppins',
    fontSize: 16,
    fontWeight: FontWeight.w700,
    letterSpacing: 0.5,
    color: AppColors.textPrimary,
  );

  /// Small caps section labels — "ENTER ROOM CODE", "RECENT STREAKS"
  static const TextStyle sectionLabel = TextStyle(
    fontFamily: 'Poppins',
    fontSize: 11,
    fontWeight: FontWeight.w600,
    letterSpacing: 2.0,
    color: AppColors.textSecondary,
  );

  /// Bottom nav bar label — "Home", "Friends", "Settings"
  static const TextStyle navLabel = TextStyle(
    fontFamily: 'Poppins',
    fontSize: 11,
    fontWeight: FontWeight.w500,
    color: AppColors.textSecondary,
  );

  /// Card count badge number on player avatars — "8", "9"
  static const TextStyle cardCount = TextStyle(
    fontFamily: 'Poppins',
    fontSize: 13,
    fontWeight: FontWeight.w700,
    color: AppColors.textPrimary,
  );

  /// "INVITE FRIEND" text inside dashed slot
  static const TextStyle inviteSlot = TextStyle(
    fontFamily: 'Poppins',
    fontSize: 13,
    fontWeight: FontWeight.w600,
    letterSpacing: 1.5,
    color: AppColors.textHint,
  );

  // ── Game board labels ──────────────────────────────────────────

  /// Score number inside the team score pill — "0"
  static const TextStyle scoreNumber = TextStyle(
    fontFamily: 'Poppins',
    fontSize: 28,
    fontWeight: FontWeight.w900,
    color: AppColors.textPrimary,
  );

  /// Team name inside the score pill — "TEAM BLUE"
  static const TextStyle scoreTeamName = TextStyle(
    fontFamily: 'Poppins',
    fontSize: 11,
    fontWeight: FontWeight.w700,
    letterSpacing: 1.0,
    color: AppColors.teamBlueRing,  // caller overrides per team
  );

  /// Event text inside the green table — "✓ CARD STOLEN:"
  static const TextStyle eventTitle = TextStyle(
    fontFamily: 'Poppins',
    fontSize: 14,
    fontWeight: FontWeight.w700,
    color: AppColors.statusReady,
  );

  static const TextStyle eventSubtitle = TextStyle(
    fontFamily: 'Poppins',
    fontSize: 12,
    fontWeight: FontWeight.w500,
    color: AppColors.textPrimary,
  );
}

// ── NOTE: Adding Poppins to your project ───────────────────────────
//
// 1.  Open frontend/pubspec.yaml
// 2.  Add under `dependencies:`:
//         google_fonts: ^6.2.1
//
// 3.  Then replace every `fontFamily: 'Poppins'` above with the
//     GoogleFonts approach, or add the font files manually under
//     assets/fonts/.  Example using google_fonts package:
//
//         import 'package:google_fonts/google_fonts.dart';
//         final style = GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.w800);
//
// For now, if Poppins is not installed, Flutter falls back to
// Roboto automatically — the layout will still be correct.
