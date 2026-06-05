// lib/modals/declare_set_modal.dart

import 'dart:math'; // Added for min/max logic
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/socket_service.dart';
import '../widgets/playing_card.dart';

// ── Design tokens ────────────────────────────────────────────────
const _bg = Color(0xFF1A3828);
const _surface = Color(0xFF15281A);
const _elevated = Color(0xFF0C1A10);
const _border = Color(0xFF2A4A30);
const _peach = Color(0xFFF4A76F);
const _textPrimary = Color(0xFFFFFFFF);
const _textSecondary = Color(0xFF8AAF90);
const _textHint = Color(0xFF4A6E50);

const _sectionLabelStyle = TextStyle(
  fontSize: 11,
  fontWeight: FontWeight.w700,
  letterSpacing: 2.0,
  color: _peach,
);

const _suitNames = {
  '♠': 'Spades',
  '♥': 'Hearts',
  '♦': 'Diamonds',
  '♣': 'Clubs',
};

class DeclareSetModal extends StatefulWidget {
  final String? myId;
  final Map<String, dynamic> gameData;

  const DeclareSetModal({
    super.key,
    required this.myId,
    required this.gameData,
  });

  @override
  State<DeclareSetModal> createState() => _DeclareSetModalState();
}

class _DeclareSetModalState extends State<DeclareSetModal> {
  String? selectedSuit;
  String? selectedSet;
  Map<String, String> cardAssignments = {};

  late List<Map<String, dynamic>> teammates;
  late Map<String, List<String>> myHandBySuit;

  final List<String> suits = ['♠', '♥', '♦', '♣'];
  final List<String> lowRanks = ['A', '2', '3', '4', '5', '6'];
  final List<String> highRanks = ['8', '9', '10', 'J', 'Q', 'K'];

  @override
  void initState() {
    super.initState();
    final players = List<Map<String, dynamic>>.from(widget.gameData['players']);
    final myTeamName =
        players.firstWhere((p) => p['id'] == widget.myId)['team'];
    teammates = players.where((p) => p['team'] == myTeamName).toList();

    myHandBySuit = {};
    final myHand = List<Map<String, dynamic>>.from(widget.gameData['myHand']);
    for (final card in myHand) {
      final suit = card['suit'] as String;
      final rank = card['rank'] as String;
      myHandBySuit.putIfAbsent(suit, () => []).add(rank);
    }

    if (_eligibleHalfSuits.isNotEmpty) {
      selectedSuit = _eligibleHalfSuits.first.$1;
      selectedSet = _eligibleHalfSuits.first.$2 ? 'Low' : 'High';
      _updateAssignments();
    }
  }

  List<String> get _eligibleSuits =>
      suits.where((s) => myHandBySuit.containsKey(s)).toList();

  bool _hasCardInSet(String suit, bool isLow) {
    final ranks = isLow ? lowRanks : highRanks;
    return myHandBySuit[suit]?.any((r) => ranks.contains(r)) ?? false;
  }

  List<(String, bool)> get _eligibleHalfSuits {
    final result = <(String, bool)>[];
    for (final s in _eligibleSuits) {
      if (_hasCardInSet(s, true)) result.add((s, true));
      if (_hasCardInSet(s, false)) result.add((s, false));
    }
    return result;
  }

  void _updateAssignments() {
    cardAssignments.clear();
    if (selectedSuit != null && selectedSet != null) {
      final currentRanks = selectedSet == 'Low' ? lowRanks : highRanks;
      for (final rank in currentRanks) {
        if (myHandBySuit[selectedSuit]?.contains(rank) ?? false) {
          cardAssignments[rank] = widget.myId!;
        }
      }
    }
    setState(() {});
  }

  void _cycleAssignment(String rank) {
    if (selectedSuit == null) return;
    final isInMyHand = myHandBySuit[selectedSuit]?.contains(rank) ?? false;
    if (isInMyHand) return;

    HapticFeedback.lightImpact();

    final assignable = teammates
        .where((p) =>
            p['id'] != widget.myId && (p['cardCount'] as num?)?.toInt() != 0)
        .map((p) => p['id'] as String)
        .toList();

    if (assignable.isEmpty) return;

    final current = cardAssignments[rank];
    final idx = current != null ? assignable.indexOf(current) : -1;
    final next = assignable[(idx + 1) % assignable.length];

    setState(() => cardAssignments[rank] = next);
  }

  Widget _buildHalfSuitChip(String suit, bool isLow) {
    final isSelected = selectedSuit == suit &&
        ((isLow && selectedSet == 'Low') || (!isLow && selectedSet == 'High'));
    final suitColor = (suit == '♥' || suit == '♦') ? Colors.red : Colors.black;

    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        setState(() {
          selectedSuit = suit;
          selectedSet = isLow ? 'Low' : 'High';
          _updateAssignments();
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        margin: const EdgeInsets.only(right: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? _peach : _surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? _peach : _border,
            width: 1.5,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              suit,
              style: TextStyle(
                fontSize: 15,
                color: isSelected ? const Color(0xFF3A1A00) : suitColor,
                shadows: (!isSelected && (suit == '♠' || suit == '♣'))
                    ? [
                        Shadow(
                          color: Colors.white.withValues(alpha: 0.3),
                          blurRadius: 3.0,
                        )
                      ]
                    : null,
              ),
            ),
            const SizedBox(width: 5),
            Text(
              '${_suitNames[suit] ?? suit} ${isLow ? "Low" : "High"}',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: isSelected ? const Color(0xFF3A1A00) : _textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCardRow(String rank, String suit) {
    final isInMyHand = myHandBySuit[suit]?.contains(rank) ?? false;
    final assignedId = cardAssignments[rank];
    final suitColor = (suit == '♥' || suit == '♦') ? Colors.red : Colors.black;
    final isAssigned = assignedId != null;

    String assignedName = '';
    if (isAssigned) {
      final match = teammates.firstWhere(
        (p) => p['id'] == assignedId,
        orElse: () => {'name': 'You'},
      );
      assignedName =
          assignedId == widget.myId ? 'You' : (match['name'] as String? ?? '');
    }

    return GestureDetector(
      onTap: isInMyHand ? null : () => _cycleAssignment(rank),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: _surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isInMyHand
                ? const Color(0xFF2A6A38)
                : (isAssigned ? _border.withValues(alpha: 0.8) : _border),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            PlayingCard(
              rank: rank,
              suit: suit,
              color: suitColor,
              size: 0.48,
              rightMargin: 0,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: isInMyHand
                  ? const Text(
                      'You hold this',
                      style: TextStyle(
                        color: _textSecondary,
                        fontSize: 13,
                        fontStyle: FontStyle.italic,
                      ),
                    )
                  : Text(
                      isAssigned ? assignedName : 'Tap to assign →',
                      style: TextStyle(
                        color: isAssigned ? _textPrimary : _textHint,
                        fontSize: 13,
                        fontWeight:
                            isAssigned ? FontWeight.w700 : FontWeight.w400,
                        fontStyle:
                            isAssigned ? FontStyle.normal : FontStyle.italic,
                      ),
                    ),
            ),
            const SizedBox(width: 8),
            isInMyHand
                ? Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2A6A38).withValues(alpha: 0.35),
                      borderRadius: BorderRadius.circular(20),
                      border:
                          Border.all(color: const Color(0xFF2A6A38), width: 1),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.person_rounded,
                            color: Color(0xFF6ECF8A), size: 14),
                        SizedBox(width: 4),
                        Text(
                          'YOU',
                          style: TextStyle(
                            color: Color(0xFF6ECF8A),
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  )
                : GestureDetector(
                    onTap: () => _cycleAssignment(rank),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: isAssigned
                            ? _peach.withValues(alpha: 0.15)
                            : _elevated,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isAssigned
                              ? _peach.withValues(alpha: 0.5)
                              : _border,
                          width: 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.person_rounded,
                              color: _textSecondary, size: 13),
                          const SizedBox(width: 4),
                          Text(
                            isAssigned ? assignedName : '—',
                            style: TextStyle(
                              color: isAssigned ? _peach : _textHint,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Icon(Icons.swap_horiz_rounded,
                              color: _textSecondary, size: 13),
                        ],
                      ),
                    ),
                  ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // ── Letterbox Constraint Logic ──
    final Size screenSize = MediaQuery.of(context).size;
    final double idealWidth = screenSize.height * 0.5625;
    final double maxAppWidth = idealWidth.clamp(350.0, 600.0);
    final double activeWidth = min(screenSize.width, maxAppWidth);

    final currentRanks = selectedSet == 'Low'
        ? lowRanks
        : (selectedSet == 'High' ? highRanks : <String>[]);

    final isReadyToDeclare = selectedSuit != null &&
        selectedSet != null &&
        currentRanks.every((r) => cardAssignments.containsKey(r));

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 40),
      child: Container(
        constraints: BoxConstraints(
          // Added maxWidth constraint
          maxHeight: MediaQuery.of(context).size.height * 0.80,
          maxWidth: activeWidth,
        ),
        decoration: BoxDecoration(
          color: _bg,
          borderRadius: BorderRadius.circular(24),
        ),
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Declare Set',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: _textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Assign all 6 cards to your team',
                style: TextStyle(fontSize: 13, color: _textSecondary),
              ),
              const SizedBox(height: 20),
              const Text('SELECT HALF-SUIT', style: _sectionLabelStyle),
              const SizedBox(height: 10),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: _eligibleHalfSuits
                      .map((hs) => _buildHalfSuitChip(hs.$1, hs.$2))
                      .toList(),
                ),
              ),
              const SizedBox(height: 20),
              const Text('MAP TEAMMATES AND CARDS', style: _sectionLabelStyle),
              const SizedBox(height: 10),
              Flexible(
                child: currentRanks.isEmpty
                    ? const Padding(
                        padding: EdgeInsets.symmetric(vertical: 24),
                        child: Center(
                          child: Text(
                            'Select a half-suit above',
                            style: TextStyle(color: _textHint, fontSize: 13),
                          ),
                        ),
                      )
                    : ListView.builder(
                        shrinkWrap: true,
                        padding: const EdgeInsets.only(bottom: 8),
                        itemCount: currentRanks.length,
                        itemBuilder: (_, i) =>
                            _buildCardRow(currentRanks[i], selectedSuit!),
                      ),
              ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Row(
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text(
                        'Cancel',
                        style: TextStyle(
                          color: _textSecondary,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: SizedBox(
                        height: 52,
                        child: ElevatedButton(
                          onPressed: isReadyToDeclare
                              ? () {
                                  HapticFeedback.mediumImpact();

                                  final set = currentRanks
                                      .map((rank) => {
                                            'suit': selectedSuit,
                                            'rank': rank,
                                          })
                                      .toList();

                                  final mapping = cardAssignments.entries
                                      .map((e) => {
                                            'card': {
                                              'suit': selectedSuit,
                                              'rank': e.key,
                                            },
                                            'teammateId': e.value,
                                          })
                                      .toList();

                                  SocketService.instance.emit('submitMapping', {
                                    'room': widget.gameData['roomCode'],
                                    'playerId': widget.myId,
                                    'mapping': mapping,
                                    'set': set,
                                  });

                                  Navigator.pop(context);
                                }
                              : null,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _peach,
                            disabledBackgroundColor: _surface,
                            foregroundColor: const Color(0xFF3A1A00),
                            disabledForegroundColor: _textHint,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16)),
                            elevation: 0,
                          ),
                          child: const Text(
                            'SUBMIT DECLARATION',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.8,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
