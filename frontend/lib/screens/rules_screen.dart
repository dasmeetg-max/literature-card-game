// lib/screens/rules_screen.dart
import 'package:flutter/material.dart';

// ── Design tokens ──────────────────────────────────────────────────
const _bg = Color(0xFF0C1A10);
const _border = Color(0xFF2A4A30);
const _peach = Color(0xFFF4A76F);
const _textPrimary = Color(0xFFFFFFFF);
const _textSecondary = Color(0xFF8AAF90);

class RulesScreen extends StatelessWidget {
  const RulesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: _textSecondary, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'HOW TO PLAY',
          style: TextStyle(
            color: _textPrimary,
            fontWeight: FontWeight.w800,
            letterSpacing: 2,
            fontSize: 16,
          ),
        ),
        centerTitle: true,
      ),
      body: const SingleChildScrollView(
        padding: EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _RuleSection(
              title: '🃏 Overview',
              content:
                  'Literature is a card game for 4 or 6 players split into 2 teams. '
                  'The goal is to win more sets than the opposing team. There are 8 sets in total.',
            ),
            _RuleSection(
              title: '🂠 The Deck',
              content:
                  'A standard 52-card deck is used with 7s removed, leaving 48 cards. '
                  'Each player is dealt 8 cards.',
            ),
            _RuleSection(
              title: '📦 Sets',
              content: 'Cards are grouped into 8 sets of 6 cards each:\n\n'
                  '• Low Spades: A♠ 2♠ 3♠ 4♠ 5♠ 6♠\n'
                  '• High Spades: 8♠ 9♠ 10♠ J♠ Q♠ K♠\n'
                  '• Low Hearts: A♥ 2♥ 3♥ 4♥ 5♥ 6♥\n'
                  '• High Hearts: 8♥ 9♥ 10♥ J♥ Q♥ K♥\n'
                  '• Low Diamonds: A♦ 2♦ 3♦ 4♦ 5♦ 6♦\n'
                  '• High Diamonds: 8♦ 9♦ 10♦ J♦ Q♦ K♦\n'
                  '• Low Clubs: A♣ 2♣ 3♣ 4♣ 5♣ 6♣\n'
                  '• High Clubs: 8♣ 9♣ 10♣ J♣ Q♣ K♣',
            ),
            _RuleSection(
              title: '🔄 Taking a Turn',
              content:
                  'On your turn, you must ask an opponent for a specific card. '
                  'You can only ask for a card if you already hold at least one card from the same set.\n\n'
                  '• If the opponent has the card → they give it to you and your turn continues.\n'
                  '• If the opponent does not have the card → the turn passes to that opponent.',
            ),
            _RuleSection(
              title: '📣 Declaring a Set',
              content:
                  'On your turn, instead of asking for a card, you can declare a set. '
                  'To declare, you must map each of the 6 cards in the set to the player in your team who holds it.\n\n'
                  '• If your mapping is correct → your team wins the set.\n'
                  '• If your mapping is wrong → the opposing team wins the set.\n'
                  '• If the opposing team holds any card from the set → the opposing team automatically wins the set.',
            ),
            _RuleSection(
              title: '🏆 Winning',
              content: 'The game ends when all 8 sets have been declared. '
                  'The team with more sets wins. If both teams have 4 sets each, the game is a draw.',
            ),
            _RuleSection(
              title: '💡 Tips',
              content:
                  '• Pay attention to which cards teammates and opponents ask for — it reveals what sets they hold.\n'
                  '• Coordinate with teammates before declaring a set.\n'
                  '• You cannot ask for a card you already hold.\n'
                  '• You can only ask opponents, never teammates.',
            ),
          ],
        ),
      ),
    );
  }
}

class _RuleSection extends StatelessWidget {
  final String title;
  final String content;

  const _RuleSection({required this.title, required this.content});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: _peach,
              fontSize: 18,
              fontWeight: FontWeight.w800,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            content,
            style: const TextStyle(
              color: Color(0xD9FFFFFF), // White at 85% opacity for readability
              fontSize: 15,
              height: 1.6,
            ),
          ),
          const SizedBox(height: 16),
          const Divider(color: _border),
        ],
      ),
    );
  }
}
