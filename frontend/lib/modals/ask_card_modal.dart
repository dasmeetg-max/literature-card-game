// lib/modals/ask_card_modal.dart

import 'dart:math'; // Added for min/max logic
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/socket_service.dart';
import '../widgets/playing_card.dart';

// ── Design tokens ────────────────────────────────────────────────
const _bg = Color(0xFF1A3828);
const _surface = Color(0xFF15281A);
const _border = Color(0xFF2A4A30);
const _peach = Color(0xFFF4A76F);
const _teal = Color(0xFF6ECFCF);
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

class AskCardModal extends StatefulWidget {
  final String? myId;
  final Map<String, dynamic> gameData;

  const AskCardModal({super.key, required this.myId, required this.gameData});

  @override
  State<AskCardModal> createState() => _AskCardModalState();
}

class _AskCardModalState extends State<AskCardModal> {
  String? selectedOpponentId;
  String? selectedSuit;
  String? selectedRank;
  String? _rankSuit;

  final ScrollController _scrollController = ScrollController();

  late List<Map<String, dynamic>> opponents;
  late List<Map<String, dynamic>> myHand;

  final List<String> suits = ['♠', '♥', '♦', '♣'];
  final List<String> allLowRanks = ['A', '2', '3', '4', '5', '6'];
  final List<String> allHighRanks = ['8', '9', '10', 'J', 'Q', 'K'];

  @override
  void initState() {
    super.initState();
    final players = List<Map<String, dynamic>>.from(widget.gameData['players']);
    final myTeam = players.firstWhere((p) => p['id'] == widget.myId)['team'];
    opponents = players
        .where((p) =>
            p['team'] != myTeam &&
            p['id'] != widget.myId &&
            (p['cardCount'] ?? 0) > 0)
        .toList();
    myHand = List<Map<String, dynamic>>.from(widget.gameData['myHand']);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  List<String> getMissingRanks(String suit, bool isLow) {
    final ranksInSet = isLow ? allLowRanks : allHighRanks;
    final myRanksInSuit = myHand
        .where((c) => c['suit'] == suit)
        .map((c) => c['rank'] as String)
        .toList();
    final hasSetCard = myRanksInSuit.any((r) => ranksInSet.contains(r));
    if (!hasSetCard) return [];
    return ranksInSet.where((r) => !myRanksInSuit.contains(r)).toList();
  }

  Widget _buildOpponentAvatar(String name, int cardCount, String id) {
    final isSelected = selectedOpponentId == id;
    final hasSelection = selectedOpponentId != null;
    final opacity = (hasSelection && !isSelected) ? 0.4 : 1.0;

    final players = List<Map<String, dynamic>>.from(widget.gameData['players']);
    final teamName =
        players.firstWhere((p) => p['id'] == id, orElse: () => {})['team'] ??
            '';
    final myTeam = players.firstWhere((p) => p['id'] == widget.myId,
            orElse: () => {})['team'] ??
        '';
    final ringColor = (teamName != myTeam) ? _peach : _teal;

    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        setState(() => selectedOpponentId = id);
      },
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 200),
        opacity: opacity,
        child: AnimatedScale(
          duration: const Duration(milliseconds: 200),
          scale: isSelected ? 1.08 : 1.0,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: 68,
                    height: 68,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _surface,
                      border: Border.all(
                        color: isSelected
                            ? _peach
                            : ringColor.withValues(alpha: 0.7),
                        width: isSelected ? 3 : 2,
                      ),
                      boxShadow: isSelected
                          ? [
                              BoxShadow(
                                color: _peach.withValues(alpha: 0.45),
                                blurRadius: 12,
                                spreadRadius: 2,
                              ),
                            ]
                          : null,
                    ),
                    child: const Icon(Icons.person_rounded,
                        color: _textSecondary, size: 36),
                  ),
                  if (isSelected)
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        width: 22,
                        height: 22,
                        decoration: const BoxDecoration(
                          color: _peach,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.check,
                            color: Colors.white, size: 14),
                      ),
                    ),
                  Positioned(
                    top: 0,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 5, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '$cardCount',
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: Colors.black,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                name,
                style: TextStyle(
                  color: isSelected ? _peach : _textPrimary,
                  fontSize: 13,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSuitChip(String? suit) {
    final isSelected =
        suit == null ? selectedSuit == null : selectedSuit == suit;
    final suitColor = suit != null && (suit == '♥' || suit == '♦')
        ? Colors.red
        : Colors.black;

    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        setState(() {
          selectedSuit = suit;
          selectedRank = null;
          _rankSuit = null;
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
        child: suit == null
            ? Text(
                'All',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: isSelected ? const Color(0xFF3A1A00) : _textSecondary,
                ),
              )
            : Row(
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
                    _suitNames[suit] ?? suit,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color:
                          isSelected ? const Color(0xFF3A1A00) : _textSecondary,
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildCardSection() {
    if (selectedSuit != null) {
      final low = getMissingRanks(selectedSuit!, true);
      final high = getMissingRanks(selectedSuit!, false);
      if (low.isEmpty && high.isEmpty) {
        return const Padding(
          padding: EdgeInsets.symmetric(vertical: 20),
          child: Center(
            child: Text(
              'No askable cards in this suit',
              style: TextStyle(color: _textHint, fontSize: 13),
            ),
          ),
        );
      }
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (low.isNotEmpty) ...[
            _cardGroupHeader(selectedSuit!, 'Low Set Missing:'),
            const SizedBox(height: 10),
            Wrap(
              children: low
                  .map((r) => _buildSelectableCard(r, selectedSuit!))
                  .toList(),
            ),
            const SizedBox(height: 8),
          ],
          if (high.isNotEmpty) ...[
            _cardGroupHeader(selectedSuit!, 'High Set Missing:'),
            const SizedBox(height: 10),
            Wrap(
              children: high
                  .map((r) => _buildSelectableCard(r, selectedSuit!))
                  .toList(),
            ),
          ],
        ],
      );
    }

    final groups = <Widget>[];
    bool anyCards = false;

    for (final s in suits) {
      final low = getMissingRanks(s, true);
      final high = getMissingRanks(s, false);
      if (low.isEmpty && high.isEmpty) continue;
      anyCards = true;

      if (low.isNotEmpty) {
        groups.add(_cardGroupHeader(s, '${_suitNames[s]} — Low'));
        groups.add(const SizedBox(height: 10));
        groups.add(Wrap(
          children: low.map((r) => _buildSelectableCard(r, s)).toList(),
        ));
        groups.add(const SizedBox(height: 12));
      }
      if (high.isNotEmpty) {
        groups.add(_cardGroupHeader(s, '${_suitNames[s]} — High'));
        groups.add(const SizedBox(height: 10));
        groups.add(Wrap(
          children: high.map((r) => _buildSelectableCard(r, s)).toList(),
        ));
        groups.add(const SizedBox(height: 12));
      }
    }

    if (!anyCards) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 20),
        child: Center(
          child: Text(
            'No askable cards in your hand',
            style: TextStyle(color: _textHint, fontSize: 13),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: groups,
    );
  }

  Widget _cardGroupHeader(String suit, String text) {
    final suitColor = (suit == '♥' || suit == '♦') ? Colors.red : Colors.black;
    return RichText(
      text: TextSpan(
        style: const TextStyle(
          color: _textPrimary,
          fontSize: 14,
          fontWeight: FontWeight.w700,
        ),
        children: [
          TextSpan(
            text: suit,
            style: TextStyle(
              color: suitColor,
              shadows: (suit == '♠' || suit == '♣')
                  ? [
                      Shadow(
                        color: Colors.white.withValues(alpha: 0.3),
                        blurRadius: 3.0,
                      )
                    ]
                  : null,
            ),
          ),
          TextSpan(text: ' $text'),
        ],
      ),
    );
  }

  Widget _buildSelectableCard(String rank, String suit) {
    final isSelected = selectedRank == rank && _rankSuit == suit;
    final suitColor = (suit == '♥' || suit == '♦') ? Colors.red : Colors.black;

    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        setState(() {
          selectedRank = rank;
          _rankSuit = suit;
        });
      },
      child: Container(
        margin: const EdgeInsets.only(right: 10, bottom: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8 * 0.75),
          border: Border.all(
            color: isSelected ? _peach : Colors.transparent,
            width: 2.5,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: _peach.withValues(alpha: 0.55),
                    blurRadius: 10,
                    spreadRadius: 1,
                  ),
                ]
              : null,
        ),
        child: PlayingCard(
          rank: rank,
          suit: suit,
          color: suitColor,
          size: 0.75,
          rightMargin: 0,
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

    final isReadyToAsk =
        selectedOpponentId != null && selectedRank != null && _rankSuit != null;

    final selectedOpponentName = isReadyToAsk
        ? opponents.firstWhere((o) => o['id'] == selectedOpponentId)['name']
            as String
        : '';

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 40),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: activeWidth),
        child: Container(
          decoration: BoxDecoration(
            color: _bg,
            borderRadius: BorderRadius.circular(24),
          ),
          // Changed padding here: only top padding, removed L/R/B
          padding: const EdgeInsets.only(top: 20),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Wrapped static top content in its own horizontal padding
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Ask for Card',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          color: _textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Ask an opponent for a card you need',
                        style: TextStyle(fontSize: 13, color: _textSecondary),
                      ),
                      const SizedBox(height: 20),
                      const Text('SELECT OPPONENT', style: _sectionLabelStyle),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: opponents
                            .map((opp) => _buildOpponentAvatar(
                                  opp['name'] as String,
                                  (opp['cardCount'] as num?)?.toInt() ?? 0,
                                  opp['id'] as String,
                                ))
                            .toList(),
                      ),
                      const SizedBox(height: 20),
                      const Text('SELECT CARD TO ASK',
                          style: _sectionLabelStyle),
                      const SizedBox(height: 10),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            _buildSuitChip(null),
                            ...suits
                                .where((s) =>
                                    getMissingRanks(s, true).isNotEmpty ||
                                    getMissingRanks(s, false).isNotEmpty)
                                .map(_buildSuitChip),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Flexible(
                  child: Scrollbar(
                    controller: _scrollController,
                    thumbVisibility: false,
                    thickness: 3,
                    radius: const Radius.circular(4),
                    scrollbarOrientation: ScrollbarOrientation.right,
                    child: ScrollConfiguration(
                      behavior: ScrollConfiguration.of(context)
                          .copyWith(overscroll: false),
                      child: SingleChildScrollView(
                        controller: _scrollController,
                        // Re-applied horizontal padding directly inside the scroll view
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: _buildCardSection(),
                      ),
                    ),
                  ),
                ),
                // Re-applied L/R/B padding for the bottom buttons
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
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
                            onPressed: isReadyToAsk
                                ? () {
                                    HapticFeedback.mediumImpact();
                                    SocketService.instance.emit('askForCard', {
                                      'room': widget.gameData['roomCode'],
                                      'fromId': widget.myId,
                                      'toId': selectedOpponentId,
                                      'card': {
                                        'suit': _rankSuit,
                                        'rank': selectedRank,
                                      },
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
                            child: Text(
                              isReadyToAsk
                                  ? 'Ask $selectedOpponentName'
                                  : 'Ask for Card',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
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
      ),
    );
  }
}
