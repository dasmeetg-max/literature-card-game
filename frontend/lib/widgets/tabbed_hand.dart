import 'package:flutter/material.dart';
import 'playing_card.dart';

class TabbedHand extends StatefulWidget {
  final List<Map<String, dynamic>> myHand;
  const TabbedHand({super.key, required this.myHand});

  @override
  State<TabbedHand> createState() => _TabbedHandState();
}

class _TabbedHandState extends State<TabbedHand> {
  String? activeSuit;
  Map<String, List<Map<String, dynamic>>> myCardsBySuit = {};

  @override
  void initState() {
    super.initState();
    _organizeCards();
    if (myCardsBySuit.isNotEmpty) {
      activeSuit = myCardsBySuit.keys.first;
    }
  }

  @override
  void didUpdateWidget(TabbedHand oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.myHand != oldWidget.myHand) {
      _organizeCards();
      if (myCardsBySuit.isNotEmpty && (activeSuit == null || !myCardsBySuit.containsKey(activeSuit))) {
        activeSuit = myCardsBySuit.keys.first;
      } else if (myCardsBySuit.isEmpty) {
        activeSuit = null;
      }
    }
  }

  void _organizeCards() {
    myCardsBySuit.clear();
    for (var card in widget.myHand) {
      final suit = card['suit'];
      final rank = card['rank'];
      final color = (suit == '♥' || suit == '♦') ? Colors.red : Colors.black;
      if (!myCardsBySuit.containsKey(suit)) {
        myCardsBySuit[suit] = [];
      }
      myCardsBySuit[suit]!.add({'rank': rank, 'color': color});
    }
    // Sort cards by rank
    myCardsBySuit.forEach((suit, cards) {
      cards.sort((a, b) => _rankValue(a['rank']).compareTo(_rankValue(b['rank'])));
    });
  }

  int _rankValue(String rank) {
    switch (rank) {
      case 'A': return 1;
      case 'K': return 13;
      case 'Q': return 12;
      case 'J': return 11;
      case '10': return 10;
      default: return int.tryParse(rank) ?? 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    final suitsInHand = myCardsBySuit.keys.toList();
    suitsInHand.sort();

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: suitsInHand.map((suit) {
            bool isActive = activeSuit == suit;
            return GestureDetector(
              onTap: () => setState(() => activeSuit = suit),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                decoration: BoxDecoration(
                  color: isActive ? Colors.grey[700] : Colors.grey[900],
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                  border: Border.all(color: Colors.black54, width: 1),
                ),
                child: Text(suit, style: TextStyle(fontSize: 20, color: isActive ? Colors.white : Colors.white54)),
              ),
            );
          }).toList(),
        ),
        Container(
          height: 140, width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.grey[700],
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.black54, width: 2),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.5), blurRadius: 10)],
          ),
          child: activeSuit == null || myCardsBySuit[activeSuit] == null || myCardsBySuit[activeSuit]!.isEmpty
            ? const Center(child: Text("No cards in this suit", style: TextStyle(color: Colors.white54)))
            : SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: myCardsBySuit[activeSuit]!.map((card) {
                    return PlayingCard(rank: card['rank'], suit: activeSuit!, color: card['color']);
                  }).toList(),
                ),
              ),
        ),
      ],
    );
  }
}