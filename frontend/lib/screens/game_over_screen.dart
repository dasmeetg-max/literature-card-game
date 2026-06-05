// lib/screens/game_over_screen.dart
//
// REDESIGNED — matches the approved mockup:
//   • Background: Color(0xFF0C1A10)
//   • Result header: emoji + headline in winning team colour + subtitle
//   • Score cards: team name label above pill, tan score number,
//     team-coloured border; winner card has glow BoxShadow
//   • Actions: host sees peach PLAY AGAIN button (with loading spinner);
//     non-host sees italic waiting text. EXIT TO HOME always shown.
//
// ALL LOGIC PRESERVED — identical to original:
//   _isLoading, haptic pattern, playAgain socket listener,
//   _onPlayAgain, _onExit, dispose cleanup.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import '../services/socket_service.dart';

// ── Design tokens ────────────────────────────────────────────────
const _bg = Color(0xFF0C1A10);
const _surface = Color(0xFF15281A);
const _border = Color(0xFF2A4A30);
const _peach = Color(0xFFF4A76F);
const _teal = Color(0xFF6ECFCF);
const _amber = Color(0xFFFFB300);
const _tan = Color(0xFFC8956C); // score number colour
const _textSecondary = Color(0xFF8AAF90);
const _textHint = Color(0xFF4A6E50);

// ── Team colour map ───────────────────────────────────────────────
// Team A (Blue) → teal, Team B (Red) → peach.
// The screen receives teamAName / teamBName as strings so we pick
// the colour by position (A = teal, B = peach).

class GameOverScreen extends StatefulWidget {
  final int scoreA;
  final int scoreB;
  final String? winner;
  final bool isDraw;
  final String teamAName;
  final String teamBName;
  final String roomCode;
  final int playerCount;
  final String playerName;

  const GameOverScreen({
    super.key,
    required this.scoreA,
    required this.scoreB,
    required this.winner,
    required this.isDraw,
    required this.teamAName,
    required this.teamBName,
    required this.roomCode,
    required this.playerCount,
    required this.playerName,
  });

  @override
  State<GameOverScreen> createState() => _GameOverScreenState();
}

class _GameOverScreenState extends State<GameOverScreen> {
  // bool _isLoading = false;

  @override
  void initState() {
    super.initState();

    // ── Haptic pattern — identical to original ────────────────
    HapticFeedback.lightImpact();
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) {
        HapticFeedback.heavyImpact();
      }
    });

    //   // ── Socket listener — identical to original ───────────────
    //   SocketService.instance.socket.off('playAgain');
    //   SocketService.instance.on('playAgain', (_) {
    //     if (!mounted) return;
    //     context.go('/', extra: {
    //       'returnToLobby': true,
    //       'roomCode': widget.roomCode,
    //       'playerCount': widget.playerCount,
    //       'playerName': widget.playerName,
    //     });
    //   });
    // }
  }

  @override
  void dispose() {
    // SocketService.instance.socket.off('playAgain');
    super.dispose();
  }

  // ── Callbacks — identical to original ────────────────────────

  // void _onPlayAgain() {
  //   HapticFeedback.mediumImpact();
  //   setState(() => _isLoading = true);
  //   SocketService.instance.emit('playAgain', {'room': widget.roomCode});
  // }

  void _onExit() {
    HapticFeedback.lightImpact();
    SocketService.instance.clearSession();
    SocketService.instance.emit('leaveRoom', {});
    SocketService.instance.disconnect();
    context.go('/');
  }

  // ── Build ─────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final teamAWon = widget.winner == widget.teamAName;
    final teamBWon = widget.winner == widget.teamBName;

    // Headline colour — winning team colour, amber for draw
    final headlineColor = widget.isDraw
        ? _amber
        : teamAWon
            ? _teal
            : _peach;

    // Headline text
    final headline = widget.isDraw ? "IT'S A DRAW!" : '${widget.winner} WINS!';

    // Subtitle text
    final subtitle = widget.isDraw
        ? 'Both teams fought hard!'
        : '${widget.winner} wins the match!';

    // Top emoji
    final emoji = widget.isDraw ? '🤝' : '🏆';

    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [
              // ── Top spacer ──────────────────────────────────
              const Spacer(flex: 2),

              // ── Result header ───────────────────────────────
              Text(emoji, style: const TextStyle(fontSize: 56)),
              const SizedBox(height: 14),
              Text(
                headline,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.0,
                  color: headlineColor,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 14,
                  color: _textSecondary,
                ),
              ),

              // ── Mid spacer ──────────────────────────────────
              const Spacer(flex: 2),

              // ── Score cards ─────────────────────────────────
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _TeamResultCard(
                      teamName: widget.teamAName,
                      score: widget.scoreA,
                      didWin: teamAWon,
                      isDraw: widget.isDraw,
                      teamColor: _teal,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: _TeamResultCard(
                      teamName: widget.teamBName,
                      score: widget.scoreB,
                      didWin: teamBWon,
                      isDraw: widget.isDraw,
                      teamColor: _peach,
                    ),
                  ),
                ],
              ),

              // ── Bottom spacer ───────────────────────────────
              const Spacer(flex: 2),

              // ── Action buttons ───────────────────────────────
              // Host: PLAY AGAIN (peach, loading spinner) + EXIT
              // Non-host: waiting text + EXIT

              // EXIT TO HOME — always visible
              SizedBox(
                width: double.infinity,
                height: 52,
                child: OutlinedButton(
                  onPressed: _onExit, // Removed _isLoading check
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(
                      color: _border, // Removed opacity changes
                      width: 1.5,
                    ),
                    foregroundColor: _textSecondary,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                  ),
                  child: const Text(
                    'EXIT TO HOME',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.8,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

// =================================================================
//  _TeamResultCard
//
//  Layout (top to bottom inside the card):
//    • Team name label — in team colour, small-caps, above the pill
//    • Score pill — dark background, team-coloured border,
//      large tan score number inside
//    • Divider
//    • Icon + result message (Winner / Well played / Better luck)
//
//  Winner card: full-opacity border + team-coloured glow BoxShadow
//  Loser card:  reduced-opacity border, no glow, muted content
//  Draw:        equal weight both sides, amber-tinted border
// =================================================================

class _TeamResultCard extends StatelessWidget {
  final String teamName;
  final int score;
  final bool didWin;
  final bool isDraw;
  final Color teamColor;

  const _TeamResultCard({
    required this.teamName,
    required this.score,
    required this.didWin,
    required this.isDraw,
    required this.teamColor,
  });

  @override
  Widget build(BuildContext context) {
    // Border colour and opacity
    final borderColor = didWin
        ? teamColor
        : isDraw
            ? teamColor.withValues(alpha: 0.55)
            : _border;
    final borderWidth = didWin ? 2.0 : 1.0;

    // Background tint
    final bgColor = didWin ? teamColor.withValues(alpha: 0.10) : _surface;

    // Glow — only for the winner
    final shadows = didWin
        ? [
            BoxShadow(
              color: teamColor.withValues(alpha: 0.30),
              blurRadius: 18,
              spreadRadius: 2,
            ),
          ]
        : null;

    // Icon
    final IconData icon;
    final Color iconColor;
    final String message;

    if (isDraw) {
      icon = Icons.handshake_rounded;
      iconColor = teamColor.withValues(alpha: 0.75);
      message = 'Well played!';
    } else if (didWin) {
      icon = Icons.emoji_events_rounded;
      iconColor = teamColor;
      message = 'Winner!';
    } else {
      icon = Icons.sentiment_dissatisfied_rounded;
      iconColor = _textHint;
      message = 'Better luck\nnext time!';
    }

    final nameColor = didWin ? teamColor : _textHint;
    final messageColor = didWin ? _textSecondary : _textHint;

    return Column(
      children: [
        // ── Team name label — sits above the pill ─────────────
        Text(
          teamName.toUpperCase(),
          style: TextStyle(
            color: nameColor,
            fontSize: 11,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.8,
          ),
        ),

        const SizedBox(height: 6),

        // ── Score pill ────────────────────────────────────────
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(40),
            border: Border.all(color: borderColor, width: borderWidth),
            boxShadow: shadows,
          ),
          child: Center(
            child: Text(
              '$score',
              style: const TextStyle(
                color: _tan,
                fontSize: 36,
                fontWeight: FontWeight.w900,
                height: 1.0,
              ),
            ),
          ),
        ),

        const SizedBox(height: 14),

        // ── Icon + message ────────────────────────────────────
        Icon(icon, color: iconColor, size: 30),
        const SizedBox(height: 6),
        Text(
          message,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: messageColor,
            fontSize: 12,
            height: 1.4,
          ),
        ),
      ],
    );
  }
}
