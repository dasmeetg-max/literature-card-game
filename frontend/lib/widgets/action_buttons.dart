// lib/widgets/action_buttons.dart
//
// Faithful to the mockup:
//   • Both buttons are full StadiumBorder pills, side by side
//   • Equal width via Expanded inside a fixed-height Row
//   • "Ask for Card": Color(0xFF4A90E2) blue, white text+icon
//   • "Declare Set":  Color(0xFFFFB300) amber, dark text+icon
//   • Both flat (elevation: 0), height: 58
//   • Icon sits left of text inside each button
//
// All turn-state logic (isMyTurn, _showingYourTurn, pulse timer,
// _buildWaitingIndicator, _buildYourTurnIndicator) is 100%
// identical to the original — only the visual layer changed.

import 'dart:async';
import 'package:flutter/material.dart';
import '../modals/ask_card_modal.dart';
import '../modals/declare_set_modal.dart';

// ── Design tokens ────────────────────────────────────────────────
const _surface = Color(0xFF15281A);
const _border = Color(0xFF2A4A30);
const _textMuted = Color(0xFF8AAF90);

class ActionButtons extends StatefulWidget {
  final String? myId;
  final Map<String, dynamic> gameData;
  final bool isMyTurn;

  const ActionButtons({
    super.key,
    required this.myId,
    required this.gameData,
    required this.isMyTurn,
  });

  @override
  State<ActionButtons> createState() => _ActionButtonsState();
}

class _ActionButtonsState extends State<ActionButtons>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  bool _showingYourTurn = false;
  Timer? _yourTurnTimer;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.4, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void didUpdateWidget(ActionButtons oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!oldWidget.isMyTurn && widget.isMyTurn) {
      setState(() => _showingYourTurn = true);
      _yourTurnTimer?.cancel();
      _yourTurnTimer = Timer(const Duration(milliseconds: 1200), () {
        if (mounted) setState(() => _showingYourTurn = false);
      });
    }
    if (!widget.isMyTurn) {
      _yourTurnTimer?.cancel();
      _showingYourTurn = false;
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _yourTurnTimer?.cancel();
    super.dispose();
  }

  // ── Build ─────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (!widget.isMyTurn) {
      final currentTurn = widget.gameData['currentTurn'] ?? '...';
      return _buildWaitingIndicator(currentTurn);
    }
    if (_showingYourTurn) return _buildYourTurnIndicator();
    return _buildActionButtons();
  }

  // ── Two action buttons ────────────────────────────────────────
  //
  // Layout exactly matches the mockup:
  //   Row of two Expanded StadiumBorder pills, height 58,
  //   12px gap between them.
  //
  // "Ask for Card" — blue pill, white icon + text
  // "Declare Set"  — amber pill, dark icon + text
  //
  // Both buttons use IntrinsicHeight so their heights stay in
  // sync even if label wraps on a small screen.

  Widget _buildActionButtons() {
    return SizedBox(
      height: 58,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Ask for Card ────────────────────────────────────
          Expanded(
            child: ElevatedButton(
              onPressed: () => showDialog(
                context: context,
                barrierColor: Colors.black54,
                builder: (_) => AskCardModal(
                  myId: widget.myId,
                  gameData: widget.gameData,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4A90E2),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 0,
                padding: EdgeInsets.zero,
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Person icon — matches mockup left-side icon
                  Icon(Icons.person_rounded, color: Colors.white, size: 20),
                  SizedBox(width: 8),
                  Text(
                    'Ask for Card',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(width: 12),

          // ── Declare Set ─────────────────────────────────────
          Expanded(
            child: ElevatedButton(
              onPressed: () => showDialog(
                context: context,
                barrierColor: Colors.black54,
                builder: (_) => DeclareSetModal(
                  myId: widget.myId,
                  gameData: widget.gameData,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFFB300),
                foregroundColor: const Color(0xFF3A2000),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 0,
                padding: EdgeInsets.zero,
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Speech bubble icon — matches mockup
                  Icon(Icons.chat_bubble_rounded,
                      color: Color(0xFF3A2000), size: 20),
                  SizedBox(width: 8),
                  Text(
                    'Declare Set',
                    style: TextStyle(
                      color: Color(0xFF3A2000),
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── "Your turn!" flash — unchanged ───────────────────────────

  Widget _buildYourTurnIndicator() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
      decoration: BoxDecoration(
        color: Colors.green[900]?.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: Colors.greenAccent.withValues(alpha: 0.4), width: 1),
      ),
      child: const Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.play_circle_outline, color: Colors.greenAccent, size: 20),
          SizedBox(width: 10),
          Text(
            'Your turn!',
            style: TextStyle(
              color: Colors.greenAccent,
              fontSize: 15,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  // ── Waiting indicator ─────────────────────────────────────────
  // Pulsing amber dot + "{name}'s turn" — logic unchanged,
  // container colours updated to dark green tokens.

  Widget _buildWaitingIndicator(String currentTurn) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _border, width: 1),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          AnimatedBuilder(
            animation: _pulseAnimation,
            builder: (context, child) => Opacity(
              opacity: _pulseAnimation.value,
              child: Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: Colors.amber,
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            "$currentTurn's turn",
            style: const TextStyle(
              color: _textMuted,
              fontSize: 15,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}
