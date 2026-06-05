// lib/theme/app_colors.dart
//
// All color constants for the Literature app.
// Named after what they LOOK LIKE, not where they're used,
// so you can reuse them freely across screens.

import 'package:flutter/material.dart';

class AppColors {
  AppColors._(); // prevents accidental instantiation

  // ── Backgrounds ────────────────────────────────────────────────
  /// The darkest background — used for the main scaffold
  static const Color backgroundDeep = Color(0xFF0C1A10);

  /// Slightly lighter panel/card surface
  static const Color backgroundCard = Color(0xFF15281A);

  /// Even lighter surface — for elevated panels like player slots
  static const Color backgroundElevated = Color(0xFF1E3824);

  /// The green felt of the game table
  static const Color tableFelt = Color(0xFF1A4D2E);

  // ── Brand / Accent ─────────────────────────────────────────────
  /// Primary peach-salmon — used for the LITERATURE logo,
  /// the "Host Game" button, and active bottom-nav icons
  static const Color peach = Color(0xFFF4A76F);

  /// A softer peach tint — for backgrounds or light fills
  static const Color peachLight = Color(0xFFFBD5B5);

  /// Teal — used for the "Join Game" button
  static const Color teal = Color(0xFF7FD8C8);

  // ── Text ───────────────────────────────────────────────────────
  static const Color textPrimary   = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xFF8AAF90);   // muted green-white
  static const Color textHint      = Color(0xFF4A6E50);   // very muted

  // ── Team colors ────────────────────────────────────────────────
  /// Team A — teal header in the lobby mockup
  static const Color teamA = Color(0xFF6ECFCF);

  /// Team B — peach/amber header in the lobby mockup
  static const Color teamB = Color(0xFFF4A76F);

  /// Blue avatar ring (used on the game board for Team Blue players)
  static const Color teamBlueRing  = Color(0xFF4A90E2);

  /// Orange avatar ring (Team Red/Orange players)
  static const Color teamOrangeRing = Color(0xFFE2844A);

  // ── Status ─────────────────────────────────────────────────────
  static const Color statusReady   = Color(0xFF4CAF50);  // green check
  static const Color statusWaiting = Color(0xFF8AAF90);  // muted

  // ── UI chrome ──────────────────────────────────────────────────
  /// Thin border around panels and slots
  static const Color border        = Color(0xFF2A4A30);

  /// Dashed border for "Invite Friend" empty slots
  static const Color borderDashed  = Color(0xFF3A6040);

  /// Bottom nav bar background
  static const Color navBackground = Color(0xFF101E13);

  // ── Buttons ────────────────────────────────────────────────────
  static const Color buttonAsk     = Color(0xFF4A90E2);   // blue "Ask for Card"
  static const Color buttonDeclare = Color(0xFFF4C430);   // yellow "Declare Set"

  // ── Overlays ───────────────────────────────────────────────────
  static const Color overlay = Color(0xAA000000); // semi-transparent black
}
